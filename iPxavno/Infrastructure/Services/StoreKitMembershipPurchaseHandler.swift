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
        let product = try await product(for: planID)
        let order = try await paymentRepository.createOrder(
            name: product.displayName,
            description: product.description,
            productID: product.id,
            purchasePrice: product.displayPrice
        )

        analytics.record(
            AnalyticsEvent(
                name: "membership_purchase_started",
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
            _ = try await membershipHandler.refreshStatus()
            analytics.record(
                AnalyticsEvent(
                    name: "membership_purchase_finished",
                    properties: ["product_id": product.id, "order_id": order.id]
                )
            )
        case .userCancelled:
            throw MembershipPurchaseError.purchaseCancelled
        case .pending:
            throw MembershipPurchaseError.purchasePending
        @unknown default:
            throw MembershipPurchaseError.verificationFailed
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()

        var restoredTransaction: Transaction?
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productType == .autoRenewable else {
                continue
            }
            restoredTransaction = transaction
            break
        }

        guard let transaction = restoredTransaction else {
            throw MembershipPurchaseError.restoreUnavailable
        }

        let receipt = (try? Self.currentReceiptBase64()) ?? ""
        try await paymentRepository.restorePurchase(
            originalTransactionID: "\(transaction.originalID)",
            transactionID: "\(transaction.id)",
            receiptData: receipt
        )
        _ = try await accountRepository.restoreAccount(using: ["\(transaction.id)"])
        _ = try await membershipHandler.refreshStatus()

        analytics.record(
            AnalyticsEvent(
                name: "membership_restore_finished",
                properties: ["product_id": transaction.productID]
            )
        )
    }

    private func product(for productID: String) async throws -> Product {
        if let product = productsByID[productID] {
            return product
        }

        let products = try await Product.products(for: [productID])
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
            subtitle: isYearly ? "up to 1840 diamonds / yr" : "+30 diamonds / week",
            callToAction: hasIntroOffer ? "Start 3-Day Free Trial" : "Continue",
            renewalText: hasIntroOffer ? "then \(product.displayPrice)/year" : "auto-renews",
            hasIntroOffer: hasIntroOffer,
            isBestValue: isYearly
        )
    }
}

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

        let products = try await Product.products(for: productIDs)
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
            _ = try await membershipHandler.refreshStatus()
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
