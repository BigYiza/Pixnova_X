import Foundation

enum AnalyticsEventCategory: String {
    case interaction
    case screen
    case iap
    case lifecycle
    case performance
    case network
    case business
}

struct AnalyticsEvent {
    let name: String
    let properties: [String: String]
    let category: AnalyticsEventCategory
    let timestamp: Date

    init(
        name: String,
        properties: [String: String] = [:],
        category: AnalyticsEventCategory = .business,
        timestamp: Date = Date()
    ) {
        self.name = name
        self.properties = properties
        self.category = category
        self.timestamp = timestamp
    }
}

protocol AnalyticsTracking: AnyObject {
    func record(_ event: AnalyticsEvent)
    func setUserID(_ userID: String?)
    func flush()
}

extension AnalyticsTracking {
    func setUserID(_ userID: String?) {}
    func flush() {}

    func trackClick(
        element: String,
        screen: String,
        properties: [String: String] = [:]
    ) {
        record(
            AnalyticsEvent(
                name: "ui_click",
                properties: properties.merging([
                    "element_name": element,
                    "screen_name": screen,
                ]) { current, _ in current },
                category: .interaction
            )
        )
    }

    func trackScreen(
        name: String,
        viewController: String,
        properties: [String: String] = [:]
    ) {
        record(
            AnalyticsEvent(
                name: "page_view",
                properties: properties.merging([
                    "screen_name": name,
                    "view_controller": viewController,
                ]) { current, _ in current },
                category: .screen
            )
        )
    }

    func trackIAP(
        productType: String,
        status: IAPAnalyticsStatus,
        productID: String? = nil,
        productName: String? = nil,
        orderID: String? = nil,
        transactionID: String? = nil,
        payAmount: Decimal? = nil,
        currency: String? = nil,
        error: Error? = nil
    ) {
        var properties = [
            "product_type": productType,
            "status": status.rawValue,
        ]
        properties["product_id"] = productID
        properties["product_name"] = productName
        properties["order_id"] = orderID
        properties["transaction_id"] = transactionID
        properties["pay_amount"] = payAmount.map { NSDecimalNumber(decimal: $0).stringValue }
        properties["currency"] = currency
        if let error {
            let nsError = error as NSError
            properties["error_domain"] = nsError.domain
            properties["error_code"] = String(nsError.code)
            properties["error_message"] = error.localizedDescription
        }
        record(AnalyticsEvent(name: "iap_status", properties: properties, category: .iap))
    }
}

enum IAPAnalyticsStatus: String {
    case productsLoading = "products_loading"
    case productsLoaded = "products_loaded"
    case productsLoadFailed = "products_load_failed"
    case orderCreating = "order_creating"
    case orderCreated = "order_created"
    case storePresented = "store_presented"
    case purchased
    case verified
    case serverValidated = "server_validated"
    case finished
    case cancelled
    case pending
    case failed
    case restoreStarted = "restore_started"
    case restoreFinished = "restore_finished"
    case restoreFailed = "restore_failed"
}

/// 每个分析 SDK 只需实现一个 Destination；业务层永远只依赖 AnalyticsTracking。
protocol AnalyticsDestination: AnyObject {
    var identifier: String { get }
    func send(_ event: AnalyticsEvent)
    func setUserID(_ userID: String?)
    func flush()
}

extension AnalyticsDestination {
    func setUserID(_ userID: String?) {}
    func flush() {}
}
