import Foundation
import UIKit

final class RemoteMembershipPaymentRepository: MembershipPaymentRepository {
    private let apiClient: APIClient
    private let encoder = JSONEncoder()

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func createOrder(
        name: String,
        description: String,
        productID: String,
        purchasePrice: String
    ) async throws -> MembershipPaymentOrder {
        let request = CreatePaymentOrderRequest(
            name: name,
            description: description,
            productID: productID,
            purchasePrice: purchasePrice
        )
        let endpoint = APIEndpoint<PaymentEnvelope<CreatePaymentOrderResponse>>(
            host: .payment,
            method: .post,
            path: "/api/v1/order/create",
            body: try encoder.encode(request)
        )
        do {
            let envelope = try await apiClient.send(endpoint)
            #if DEBUG
            Self.log("createOrder envelope \(envelope.debugSummary) productID=\(productID) price=\(purchasePrice)")
            #endif
            let response = try envelope.requirePayload()
            #if DEBUG
            Self.log("createOrder payload orderID=\(response.orderID) orderUUID=\(response.orderUUID) productID=\(productID)")
            #endif
            return MembershipPaymentOrder(
                id: response.orderID,
                appAccountToken: UUID(uuidString: response.orderUUID) ?? UUID()
            )
        } catch {
            #if DEBUG
            Self.logError(error, stage: "createOrder failed productID=\(productID) price=\(purchasePrice)")
            #endif
            throw error
        }
    }

    func notifyPurchaseSuccess(orderID: String, transactionID: String, receiptData: String) async throws {
        let request = PurchaseSuccessRequest(
            orderID: orderID,
            transactionID: transactionID,
            receiptData: receiptData
        )
        let endpoint = APIEndpoint<PaymentEnvelope<PaymentEmptyPayload>>(
            host: .payment,
            method: .post,
            path: "/api/v1/pay/apple/success_notify",
            body: try encoder.encode(request)
        )
        do {
            let envelope = try await apiClient.send(endpoint)
            #if DEBUG
            Self.log(
                "notifyPurchaseSuccess envelope \(envelope.debugSummary) orderID=\(orderID) transactionID=\(transactionID) receiptBase64Length=\(receiptData.count)"
            )
            #endif
        } catch {
            #if DEBUG
            Self.logError(
                error,
                stage: "notifyPurchaseSuccess failed orderID=\(orderID) transactionID=\(transactionID) receiptBase64Length=\(receiptData.count)"
            )
            #endif
            throw error
        }
    }

    func orderState(orderID: String) async throws -> Int {
        let endpoint = APIEndpoint<PaymentEnvelope<OrderStateResponse>>(
            host: .payment,
            method: .get,
            path: "/api/v1/order/status",
            queryItems: [URLQueryItem(name: "order_id", value: orderID)]
        )
        do {
            let envelope = try await apiClient.send(endpoint)
            #if DEBUG
            Self.log("orderState envelope \(envelope.debugSummary) orderID=\(orderID)")
            #endif
            return try envelope.requirePayload().state
        } catch {
            #if DEBUG
            Self.logError(error, stage: "orderState failed orderID=\(orderID)")
            #endif
            throw error
        }
    }

    func restorePurchase(originalTransactionID: String, transactionID: String, receiptData: String) async throws {
        let request = RestorePurchaseRequest(
            originalTransactionID: originalTransactionID,
            transactionID: transactionID,
            receiptData: receiptData
        )
        let endpoint = APIEndpoint<RestorePaymentEnvelope>(
            host: .payment,
            method: .post,
            path: "/api/v1/pay/apple/restore",
            body: try encoder.encode(request)
        )
        do {
            let response = try await apiClient.send(endpoint)
            #if DEBUG
            Self.log(
                "restorePurchase envelope \(response.debugSummary) originalTransactionID=\(originalTransactionID) transactionID=\(transactionID) receiptBase64Length=\(receiptData.count)"
            )
            #endif
            guard response.isSuccessful else {
                throw MembershipPurchaseError.restoreUnavailable
            }
        } catch {
            #if DEBUG
            Self.logError(
                error,
                stage: "restorePurchase failed originalTransactionID=\(originalTransactionID) transactionID=\(transactionID) receiptBase64Length=\(receiptData.count)"
            )
            #endif
            throw error
        }
    }

    func reportAttribution(
        iosDistinctID: String?,
        iosAppsFlyerID: String?,
        iosGAClientID: String?
    ) async throws -> Bool {
        let request = AttributionReportRequest(
            iosDistinctID: iosDistinctID,
            iosAppsFlyerID: iosAppsFlyerID,
            iosGAClientID: iosGAClientID
        )
        let endpoint = APIEndpoint<PaymentEnvelope<AttributionReportResponse>>(
            host: .payment,
            method: .post,
            path: "/api/v1/user/report_attribution",
            body: try encoder.encode(request)
        )
        let envelope = try await apiClient.send(endpoint)
        return try envelope.requireSuccessfulPayload().updated
    }
}

/// 在各归因 SDK 的设备 ID 与登录凭证均可用后尽早补齐支付服务的归因标识。
final class PaymentAttributionReporter {
    private let paymentRepository: RemoteMembershipPaymentRepository
    private let sessionProvider: SessionProviding
    private let analytics: AnalyticsTracking
    private let distinctIDProvider: () -> String?
    private let appsFlyerIDProvider: () -> String?
    private let gaClientIDProvider: () -> String?
    private let notificationCenter: NotificationCenter

    private var notificationTokens: [NSObjectProtocol] = []
    private var pendingDistinctID: String?
    private var pendingAppsFlyerID: String?
    private var pendingGAClientID: String?
    private var inFlightKey: String?
    private var lastReportedKey: String?

    init(
        paymentRepository: RemoteMembershipPaymentRepository,
        sessionProvider: SessionProviding,
        analytics: AnalyticsTracking,
        distinctIDProvider: @escaping () -> String?,
        appsFlyerIDProvider: @escaping () -> String?,
        gaClientIDProvider: @escaping () -> String?,
        notificationCenter: NotificationCenter = .default
    ) {
        self.paymentRepository = paymentRepository
        self.sessionProvider = sessionProvider
        self.analytics = analytics
        self.distinctIDProvider = distinctIDProvider
        self.appsFlyerIDProvider = appsFlyerIDProvider
        self.gaClientIDProvider = gaClientIDProvider
        self.notificationCenter = notificationCenter
    }

    deinit {
        notificationTokens.forEach(notificationCenter.removeObserver)
    }

    func start() {
        performOnMain { [weak self] in
            guard let self, self.notificationTokens.isEmpty else { return }
            self.notificationTokens = [
                self.notificationCenter.addObserver(
                    forName: AccountNotifications.accountDidChange,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.refresh()
                },
                self.notificationCenter.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.refresh()
                },
            ]
            self.refresh()
        }
    }

    func receiveIOSDistinctID(_ value: String) {
        performOnMain { [weak self] in
            guard let self else { return }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            self.pendingDistinctID = normalized
            self.reportIfPossible()
        }
    }

    func receiveIOSAppsFlyerID(_ value: String) {
        update(value, keyPath: \PaymentAttributionReporter.pendingAppsFlyerID)
    }

    func receiveIOSGAClientID(_ value: String) {
        update(value, keyPath: \PaymentAttributionReporter.pendingGAClientID)
    }

    func refresh() {
        performOnMain { [weak self] in
            guard let self else { return }
            if let distinctID = self.distinctIDProvider() {
                self.pendingDistinctID = distinctID
            }
            if let appsFlyerID = self.appsFlyerIDProvider() {
                self.pendingAppsFlyerID = appsFlyerID
            }
            if let gaClientID = self.gaClientIDProvider() {
                self.pendingGAClientID = gaClientID
            }
            self.reportIfPossible()
        }
    }

    private func update(
        _ value: String,
        keyPath: ReferenceWritableKeyPath<PaymentAttributionReporter, String?>
    ) {
        performOnMain { [weak self] in
            guard let self else { return }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            self[keyPath: keyPath] = normalized
            self.reportIfPossible()
        }
    }

    private func reportIfPossible() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let credential = sessionProvider.currentCredential,
            credential.isValid
        else { return }

        guard pendingDistinctID != nil || pendingAppsFlyerID != nil || pendingGAClientID != nil
        else { return }

        let requestKey = currentRequestKey(userID: credential.userID)
        guard inFlightKey == nil, requestKey != lastReportedKey else { return }
        inFlightKey = requestKey

        let distinctID = pendingDistinctID
        let appsFlyerID = pendingAppsFlyerID
        let gaClientID = pendingGAClientID

        Task { [weak self] in
            guard let self else { return }
            do {
                let updated = try await self.paymentRepository.reportAttribution(
                    iosDistinctID: distinctID,
                    iosAppsFlyerID: appsFlyerID,
                    iosGAClientID: gaClientID
                )
                DispatchQueue.main.async { [weak self] in
                    self?.finish(requestKey: requestKey, updated: updated, error: nil)
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.finish(requestKey: requestKey, updated: nil, error: error)
                }
            }
        }
    }

    private func finish(requestKey: String, updated: Bool?, error: Error?) {
        dispatchPrecondition(condition: .onQueue(.main))
        let currentRequestKey = sessionProvider.currentCredential.flatMap { credential in
            credential.isValid ? self.currentRequestKey(userID: credential.userID) : nil
        }
        if inFlightKey == requestKey {
            inFlightKey = nil
        }

        if let updated {
            lastReportedKey = requestKey
            analytics.record(
                AnalyticsEvent(
                    name: "attribution_id_reported",
                    properties: [
                        "fields": availableFieldNames,
                        "updated": String(updated),
                    ],
                    category: .business
                )
            )
            #if DEBUG
                print("[Attribution] iOS attribution IDs reported; fields=\(availableFieldNames) updated=\(updated)")
            #endif
        } else if let error {
            analytics.record(
                AnalyticsEvent(
                    name: "attribution_id_report_failed",
                    properties: [
                        "fields": availableFieldNames,
                        "reason": error.localizedDescription,
                    ],
                    category: .business
                )
            )
            #if DEBUG
                print("[Attribution][Error] iOS attribution IDs report failed: \(error.localizedDescription)")
            #endif
        }

        if updated != nil || currentRequestKey != requestKey {
            reportIfPossible()
        }
    }

    private func performOnMain(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            DispatchQueue.main.async(execute: operation)
        }
    }

    private func currentRequestKey(userID: String) -> String {
        [userID, pendingDistinctID ?? "", pendingAppsFlyerID ?? "", pendingGAClientID ?? ""]
            .joined(separator: "|")
    }

    private var availableFieldNames: String {
        var fields: [String] = []
        if pendingDistinctID != nil { fields.append("ios_distinct_id") }
        if pendingAppsFlyerID != nil { fields.append("ios_appsflyer_id") }
        if pendingGAClientID != nil { fields.append("ios_ga_client_id") }
        return fields.joined(separator: ",")
    }
}

private struct CreatePaymentOrderRequest: Encodable {
    let name: String
    let description: String
    let productID: String
    let purchasePrice: String

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case productID = "product_id"
        case purchasePrice = "purchase_price"
    }
}

private struct CreatePaymentOrderResponse: Decodable {
    let orderID: String
    let orderUUID: String

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case orderUUID = "order_uuid"
    }
}

private struct PurchaseSuccessRequest: Encodable {
    let orderID: String
    let transactionID: String
    let receiptData: String

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case transactionID = "transaction_id"
        case receiptData = "receipt_data"
    }
}

private struct OrderStateResponse: Decodable {
    let state: Int
}

private struct RestorePurchaseRequest: Encodable {
    let originalTransactionID: String
    let transactionID: String
    let receiptData: String

    enum CodingKeys: String, CodingKey {
        case originalTransactionID = "original_transaction_id"
        case transactionID = "transaction_id"
        case receiptData = "receipt_data"
    }
}

private struct AttributionReportRequest: Encodable {
    let iosDistinctID: String?
    let iosAppsFlyerID: String?
    let iosGAClientID: String?

    enum CodingKeys: String, CodingKey {
        case iosDistinctID = "ios_distinct_id"
        case iosAppsFlyerID = "ios_appsflyer_id"
        case iosGAClientID = "ios_ga_client_id"
    }
}

private struct AttributionReportResponse: Decodable {
    let updated: Bool
}

private struct PaymentEmptyPayload: Decodable {}

private struct PaymentEnvelope<Payload: Decodable>: Decodable {
    let code: Int?
    let state: Int?
    let data: Payload?
    let message: String?
    let descriptionText: String?

    enum CodingKeys: String, CodingKey {
        case code
        case state
        case data
        case message = "msg"
        case descriptionText = "description"
    }

    func requirePayload() throws -> Payload {
        guard code == nil || code == 0 else {
            throw AppError.server(message: descriptionText ?? message ?? "Payment request failed.", code: code ?? -1)
        }
        guard let data else {
            throw AppError.invalidResponse
        }
        return data
    }

    func requireSuccessfulPayload() throws -> Payload {
        guard state == nil || state == 0 else {
            throw AppError.server(
                message: descriptionText ?? message ?? "Payment request failed.",
                code: state ?? -1
            )
        }
        return try requirePayload()
    }

    #if DEBUG
    var debugSummary: String {
        "code=\(String(describing: code)) state=\(String(describing: state)) hasData=\(data != nil) msg=\(message ?? "<nil>") description=\(descriptionText ?? "<nil>")"
    }
    #endif
}

private struct RestorePaymentEnvelope: Decodable {
    let state: Int?
    let data: RestorePaymentState?

    var isSuccessful: Bool {
        state == 0 || data?.state == 0
    }

    #if DEBUG
    var debugSummary: String {
        "state=\(String(describing: state)) dataState=\(String(describing: data?.state)) hasData=\(data != nil)"
    }
    #endif
}

private struct RestorePaymentState: Decodable {
    let state: Int?
}

#if DEBUG
private extension RemoteMembershipPaymentRepository {
    static func log(_ message: String) {
        print("[PaymentAPI][Membership] \(message)")
    }

    static func logError(_ error: Error, stage: String) {
        print("[PaymentAPI][Membership][Error] \(stage) \(errorDiagnostic(error))")
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
