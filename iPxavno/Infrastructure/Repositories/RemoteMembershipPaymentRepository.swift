import Foundation

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
