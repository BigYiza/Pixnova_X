import Foundation
import StoreKit

final class StoreKitMembershipPurchaseHandler: MembershipPurchaseHandling {
    private let catalogProvider: () -> MembershipProductCatalog
    private let paymentRepository: MembershipPaymentRepository
    private let accountRepository: AccountRepository
    private let membershipHandler: MembershipHandling
    private let analytics: AnalyticsTracking

    private var productsByID: [String: Product] = [:]

    init(
        catalogProvider: @escaping () -> MembershipProductCatalog,
        paymentRepository: MembershipPaymentRepository,
        accountRepository: AccountRepository,
        membershipHandler: MembershipHandling,
        analytics: AnalyticsTracking
    ) {
        self.catalogProvider = catalogProvider
        self.paymentRepository = paymentRepository
        self.accountRepository = accountRepository
        self.membershipHandler = membershipHandler
        self.analytics = analytics
    }

    func loadPlans(catalog: MembershipProductCatalog) async throws -> [MembershipPurchasePlan] {
        let productIDs = catalog.allProductIDs
        guard !productIDs.isEmpty else { throw MembershipPurchaseError.productUnavailable }

        let products = try await Product.products(for: productIDs)
        #if DEBUG
        let returnedProductIDs = Set(products.map(\.id))
        let missingProductIDs = productIDs.filter { !returnedProductIDs.contains($0) }
        print(
            "[StoreKit][Membership] requested:",
            productIDs,
            "returned:",
            products.map(\.id),
            "missing:",
            missingProductIDs
        )
        #endif
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let plans = products
            .map(Self.plan(from:))
            .sorted { lhs, rhs in
                if lhs.kind == .yearly, rhs.kind != .yearly { return false }
                if lhs.kind != .yearly, rhs.kind == .yearly { return true }
                return lhs.title < rhs.title
            }

        guard !plans.isEmpty else { throw MembershipPurchaseError.productUnavailable }
        return plans
    }

    func purchase(planID: String) async throws {
        #if DEBUG
        Self.log("purchase begin planID=\(planID)")
        #endif

        do {
            let product = try await product(for: planID)
            #if DEBUG
            Self.logProduct(product, stage: "selected product")
            #endif

            let order = try await paymentRepository.createOrder(
                name: product.displayName,
                description: product.description,
                productID: product.id,
                purchasePrice: product.displayPrice
            )
            #if DEBUG
            Self.log("create order success productID=\(product.id) orderID=\(order.id) appAccountToken=\(order.appAccountToken.uuidString)")
            #endif

            analytics.record(
                AnalyticsEvent(
                    name: "membership_purchase_started",
                    properties: ["product_id": product.id, "order_id": order.id]
                )
            )

            #if DEBUG
            Self.log("StoreKit purchase prompt begin productID=\(product.id) orderID=\(order.id)")
            #endif
            let result = try await product.purchase(options: [.appAccountToken(order.appAccountToken)])

            switch result {
            case let .success(verificationResult):
                #if DEBUG
                Self.log("StoreKit purchase success returned, verifying transaction productID=\(product.id) orderID=\(order.id)")
                #endif

                let transaction = try Self.verifiedTransaction(from: verificationResult)
                #if DEBUG
                Self.logTransaction(transaction, stage: "verified transaction")
                #endif

                let receipt = try Self.currentReceiptBase64()
                #if DEBUG
                Self.log("receipt loaded productID=\(product.id) orderID=\(order.id) receiptBase64Length=\(receipt.count)")
                #endif

                try await paymentRepository.notifyPurchaseSuccess(
                    orderID: order.id,
                    transactionID: "\(transaction.id)",
                    receiptData: receipt
                )
                #if DEBUG
                Self.log("notify purchase success completed productID=\(product.id) orderID=\(order.id) transactionID=\(transaction.id)")
                #endif

                await transaction.finish()
                #if DEBUG
                Self.log("transaction finish completed productID=\(product.id) orderID=\(order.id) transactionID=\(transaction.id)")
                #endif

                try await waitForCompletedOrder(order.id)
                #if DEBUG
                Self.log("order state completed orderID=\(order.id)")
                #endif

                _ = try await membershipHandler.membershipStatus(forceRefresh: true)
                #if DEBUG
                Self.log("membership full refresh completed productID=\(product.id) orderID=\(order.id)")
                #endif

                analytics.record(
                    AnalyticsEvent(
                        name: "membership_purchase_finished",
                        properties: ["product_id": product.id, "order_id": order.id]
                    )
                )
            case .userCancelled:
                #if DEBUG
                Self.log("StoreKit purchase cancelled productID=\(product.id) orderID=\(order.id)")
                #endif
                throw MembershipPurchaseError.purchaseCancelled
            case .pending:
                #if DEBUG
                Self.log("StoreKit purchase pending productID=\(product.id) orderID=\(order.id)")
                #endif
                throw MembershipPurchaseError.purchasePending
            @unknown default:
                #if DEBUG
                Self.log("StoreKit purchase unknown result productID=\(product.id) orderID=\(order.id)")
                #endif
                throw MembershipPurchaseError.verificationFailed
            }
        } catch {
            #if DEBUG
            Self.logError(error, stage: "purchase failed planID=\(planID)")
            #endif
            throw error
        }
    }

    func restorePurchases() async throws {
        #if DEBUG
        Self.log("restore begin")
        #endif

        do {
            try await AppStore.sync()
            #if DEBUG
            Self.log("AppStore sync completed")
            #endif

            var restoredTransaction: Transaction?
            for await result in Transaction.currentEntitlements {
                guard case let .verified(transaction) = result,
                      transaction.productType == .autoRenewable else {
                    #if DEBUG
                    Self.log("restore skipped entitlement result=\(result)")
                    #endif
                    continue
                }
                restoredTransaction = transaction
                break
            }

            guard let transaction = restoredTransaction else {
                throw MembershipPurchaseError.restoreUnavailable
            }
            #if DEBUG
            Self.logTransaction(transaction, stage: "restore selected transaction")
            #endif

            let receipt = (try? Self.currentReceiptBase64()) ?? ""
            #if DEBUG
            Self.log("restore receipt loaded receiptBase64Length=\(receipt.count)")
            #endif

            try await paymentRepository.restorePurchase(
                originalTransactionID: "\(transaction.originalID)",
                transactionID: "\(transaction.id)",
                receiptData: receipt
            )
            #if DEBUG
            Self.log("restore payment API completed transactionID=\(transaction.id)")
            #endif

            _ = try await accountRepository.restoreAccount(using: ["\(transaction.id)"])
            #if DEBUG
            Self.log("restore account completed transactionID=\(transaction.id)")
            #endif

            _ = try await membershipHandler.membershipStatus(forceRefresh: true)
            #if DEBUG
            Self.log("restore membership full refresh completed transactionID=\(transaction.id)")
            #endif

            analytics.record(
                AnalyticsEvent(
                    name: "membership_restore_finished",
                    properties: ["product_id": transaction.productID]
                )
            )
        } catch {
            #if DEBUG
            Self.logError(error, stage: "restore failed")
            #endif
            throw error
        }
    }

    private func product(for productID: String) async throws -> Product {
        if let product = productsByID[productID] {
            #if DEBUG
            Self.log("product cache hit productID=\(productID)")
            #endif
            return product
        }

        #if DEBUG
        Self.log("product cache miss, loading from StoreKit productID=\(productID)")
        #endif
        let products = try await Product.products(for: [productID])
        #if DEBUG
        Self.log("product lookup returned requested=\(productID) returned=\(products.map(\.id))")
        #endif
        guard let product = products.first else {
            throw MembershipPurchaseError.productUnavailable
        }
        productsByID[product.id] = product
        return product
    }

    private func waitForCompletedOrder(_ orderID: String) async throws {
        var attempts = 0
        while attempts < 5 {
            attempts += 1
            let state = try await paymentRepository.orderState(orderID: orderID)
            #if DEBUG
            Self.log("order state poll orderID=\(orderID) attempt=\(attempts) state=\(state)")
            #endif
            if state == 1 {
                return
            }
            try await Task.sleep(nanoseconds: 700_000_000)
        }
    }

    private static func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            return transaction
        case let .unverified(transaction, error):
            #if DEBUG
            logError(error, stage: "transaction unverified productID=\(transaction.productID) transactionID=\(transaction.id)")
            #endif
            throw MembershipPurchaseError.verificationFailed
        }
    }

    private static func currentReceiptBase64() throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            throw MembershipPurchaseError.receiptUnavailable
        }

        do {
            return try Data(contentsOf: receiptURL).base64EncodedString()
        } catch {
            throw AppError.underlying(error)
        }
    }

    private static func plan(from product: Product) -> MembershipPurchasePlan {
        let kind = MembershipPlanKind(productID: product.id)
        let isYearly = kind == .yearly
        let hasIntroOffer = product.subscription?.introductoryOffer != nil

        return MembershipPurchasePlan(
            id: product.id,
            kind: kind,
            title: isYearly ? "Yearly" : kind == .weekly ? "Weekly" : product.displayName,
            price: product.displayPrice,
            subtitle: isYearly ? "up to 1840 diamonds/year" : "+30 diamonds / week",
            callToAction: hasIntroOffer ? "Start 3-Day Free Trial" : "Continue",
            renewalText: hasIntroOffer ? "then \(product.displayPrice)/year" : "auto-renews",
            hasIntroOffer: hasIntroOffer,
            isBestValue: isYearly
        )
    }
}

#if DEBUG
private extension StoreKitMembershipPurchaseHandler {
    static func log(_ message: String) {
        print("[StoreKit][Membership][Purchase] \(message)")
    }

    static func logProduct(_ product: Product, stage: String) {
        let period = product.subscription?.subscriptionPeriod
        let periodText = period.map { "\($0.value) \($0.unit)" } ?? "<none>"
        print(
            "[StoreKit][Membership][Purchase] \(stage)",
            "id=\(product.id)",
            "displayName=\(product.displayName)",
            "displayPrice=\(product.displayPrice)",
            "type=\(product.type)",
            "subscriptionPeriod=\(periodText)",
            "hasIntroOffer=\(product.subscription?.introductoryOffer != nil)"
        )
    }

    static func logTransaction(_ transaction: Transaction, stage: String) {
        print(
            "[StoreKit][Membership][Purchase] \(stage)",
            "id=\(transaction.id)",
            "originalID=\(transaction.originalID)",
            "productID=\(transaction.productID)",
            "productType=\(transaction.productType)",
            "purchaseDate=\(transaction.purchaseDate)",
            "expirationDate=\(String(describing: transaction.expirationDate))",
            "revocationDate=\(String(describing: transaction.revocationDate))"
        )
    }

    static func logError(_ error: Error, stage: String) {
        print("[StoreKit][Membership][Purchase][Error] \(stage) \(errorDiagnostic(error))")
    }

    static func errorDiagnostic(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [
            "type=\(type(of: error))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            "description=\(error.localizedDescription)"
        ]
        if let appError = error as? AppError {
            parts.append("appError=\(appError)")
        }
        if let membershipError = error as? MembershipPurchaseError {
            parts.append("membershipError=\(membershipError)")
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let underlyingError = underlying as NSError
            parts.append(
                "underlying={type=\(type(of: underlying)) domain=\(underlyingError.domain) code=\(underlyingError.code) description=\(underlying.localizedDescription)}"
            )
        }
        return parts.joined(separator: " ")
    }
}
#endif

final class StoreKitDiamondPurchaseHandler: DiamondPurchaseHandling {
    private let catalogProvider: () -> DiamondProductCatalog
    private let paymentRepository: MembershipPaymentRepository
    private let membershipHandler: MembershipHandling
    private let analytics: AnalyticsTracking

    private var productsByID: [String: Product] = [:]

    init(
        catalogProvider: @escaping () -> DiamondProductCatalog,
        paymentRepository: MembershipPaymentRepository,
        membershipHandler: MembershipHandling,
        analytics: AnalyticsTracking
    ) {
        self.catalogProvider = catalogProvider
        self.paymentRepository = paymentRepository
        self.membershipHandler = membershipHandler
        self.analytics = analytics
    }

    func loadPacks(catalog: DiamondProductCatalog) async throws -> [DiamondPurchasePack] {
        let productIDs = catalog.allProductIDs
        guard !productIDs.isEmpty else { throw DiamondPurchaseError.productUnavailable }

        let products = try await loadProducts(productIDs: productIDs)
        #if DEBUG
        let returnedProductIDs = Set(products.map(\.id))
        let missingProductIDs = productIDs.filter { !returnedProductIDs.contains($0) }
        print(
            "[StoreKit][Diamonds] requested:",
            productIDs,
            "returned:",
            products.map(\.id),
            "missing:",
            missingProductIDs
        )
        #endif
        productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let packs = products
            .map(Self.pack(from:))
            .sorted { lhs, rhs in
                switch (lhs.diamondAmount, rhs.diamondAmount) {
                case let (lhsAmount?, rhsAmount?):
                    return lhsAmount < rhsAmount
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.title < rhs.title
                }
            }

        guard !packs.isEmpty else { throw DiamondPurchaseError.productUnavailable }
        return packs
    }

    private func loadProducts(productIDs: [String]) async throws -> [Product] {
        let activityIDs = productIDs.filter { $0.lowercased().hasSuffix(".activity") }
        let regularIDs = productIDs.filter { !activityIDs.contains($0) }
        var products: [Product] = []

        // Activity products are requested separately so a partial catalog response
        // cannot silently remove the limited offer from one of the two tabs.
        if !regularIDs.isEmpty {
            products.append(contentsOf: try await Product.products(for: regularIDs))
        }
        if !activityIDs.isEmpty {
            products.append(contentsOf: try await Product.products(for: activityIDs))
        }

        var productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let missingIDs = productIDs.filter { productsByID[$0] == nil }
        for productID in missingIDs {
            let retryProducts = try await Product.products(for: [productID])
            for product in retryProducts {
                productsByID[product.id] = product
            }
        }

        return productIDs.compactMap { productsByID[$0] }
    }

    func purchase(packID: String) async throws {
        let product = try await product(for: packID)
        let order = try await paymentRepository.createOrder(
            name: product.displayName,
            description: product.description,
            productID: product.id,
            purchasePrice: product.displayPrice
        )

        analytics.record(
            AnalyticsEvent(
                name: "diamond_purchase_started",
                properties: ["product_id": product.id, "order_id": order.id]
            )
        )

        let result = try await product.purchase(options: [.appAccountToken(order.appAccountToken)])

        switch result {
        case let .success(verificationResult):
            let transaction = try Self.verifiedTransaction(from: verificationResult)
            let receipt = try Self.currentReceiptBase64()
            try await paymentRepository.notifyPurchaseSuccess(
                orderID: order.id,
                transactionID: "\(transaction.id)",
                receiptData: receipt
            )
            await transaction.finish()
            try await waitForCompletedOrder(order.id)
            _ = try await membershipHandler.membershipStatus(forceRefresh: true)
            #if DEBUG
            print("[StoreKit][Diamonds][Purchase] membership full refresh completed productID=\(product.id) orderID=\(order.id)")
            #endif
            analytics.record(
                AnalyticsEvent(
                    name: "diamond_purchase_finished",
                    properties: ["product_id": product.id, "order_id": order.id]
                )
            )
        case .userCancelled:
            throw DiamondPurchaseError.purchaseCancelled
        case .pending:
            throw DiamondPurchaseError.purchasePending
        @unknown default:
            throw DiamondPurchaseError.verificationFailed
        }
    }

    private func product(for productID: String) async throws -> Product {
        if let product = productsByID[productID] {
            return product
        }

        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw DiamondPurchaseError.productUnavailable
        }
        productsByID[product.id] = product
        return product
    }

    private func waitForCompletedOrder(_ orderID: String) async throws {
        var attempts = 0
        while attempts < 5 {
            attempts += 1
            let state = try await paymentRepository.orderState(orderID: orderID)
            if state == 1 {
                return
            }
            try await Task.sleep(nanoseconds: 700_000_000)
        }
    }

    private static func verifiedTransaction(
        from result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case let .verified(transaction):
            return transaction
        case .unverified:
            throw DiamondPurchaseError.verificationFailed
        }
    }

    private static func currentReceiptBase64() throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            throw DiamondPurchaseError.receiptUnavailable
        }

        do {
            return try Data(contentsOf: receiptURL).base64EncodedString()
        } catch {
            throw AppError.underlying(error)
        }
    }

    private static func pack(from product: Product) -> DiamondPurchasePack {
        let amount = diamondAmount(from: "\(product.displayName) \(product.id)")
        return DiamondPurchasePack(
            id: product.id,
            title: amount.map { "\($0) Diamonds" } ?? product.displayName,
            price: product.displayPrice,
            subtitle: product.description.isEmpty ? "Consumable diamond pack" : product.description,
            diamondAmount: amount,
            isPurchasable: true
        )
    }

    private static func diamondAmount(from text: String) -> Int? {
        text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .first
    }
}

private extension MembershipPlanKind {
    init(productID: String) {
        let lowercased = productID.lowercased()
        if lowercased.contains("year") || lowercased.contains("annual") {
            self = .yearly
        } else if lowercased.contains("week") {
            self = .weekly
        } else {
            self = .other
        }
    }
}

protocol MembershipPaymentRepository {
    func createOrder(
        name: String,
        description: String,
        productID: String,
        purchasePrice: String
    ) async throws -> MembershipPaymentOrder

    func notifyPurchaseSuccess(orderID: String, transactionID: String, receiptData: String) async throws
    func orderState(orderID: String) async throws -> Int
    func restorePurchase(originalTransactionID: String, transactionID: String, receiptData: String) async throws
}

struct MembershipPaymentOrder {
    let id: String
    let appAccountToken: UUID
}
