import AppsFlyerLib
import Foundation
import UIKit

struct AppsFlyerConfiguration {
    let devKey: String
    let appleAppID: String

    static func current(bundle: Bundle = .main) -> AppsFlyerConfiguration {
        let devKey = bundle.object(forInfoDictionaryKey: "AppsFlyerDevKey") as? String ?? ""
        let appleAppID = bundle.object(forInfoDictionaryKey: "AppsFlyerAppleAppID") as? String ?? ""
        return AppsFlyerConfiguration(
            devKey: devKey.trimmingCharacters(in: .whitespacesAndNewlines),
            appleAppID: appleAppID.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    var isUsable: Bool {
        !devKey.isEmpty && !devKey.contains("$(") && !appleAppID.isEmpty
            && !appleAppID.contains("$(")
            && appleAppID.allSatisfy(\.isNumber)
    }
}

/// AppsFlyer 只接收归因相关业务事件与 IAP，避免上传页面、点击、性能和网络噪声。
final class AppsFlyerAnalyticsDestination: AnalyticsDestination {
    let identifier = "appsflyer"

    private let configuration: AppsFlyerConfiguration
    private let sdk: AppsFlyerLib
    private let stateLock = NSLock()
    private var initialized = false
    private var currentUserID: String?

    init(
        configuration: AppsFlyerConfiguration = .current(),
        sdk: AppsFlyerLib = .shared()
    ) {
        self.configuration = configuration
        self.sdk = sdk
    }

    func initialize(
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?,
        initialUserID: String?,
        trackingAuthorization: TrackingAuthorizationCoordinator
    ) {
        guard configuration.isUsable else {
            #if DEBUG
                print("[AppsFlyer] Dev Key or Apple App ID is not configured; SDK remains disabled.")
            #endif
            return
        }

        stateLock.lock()
        guard !initialized else {
            stateLock.unlock()
            return
        }
        initialized = true
        currentUserID = Self.normalizedUserID(initialUserID)
        stateLock.unlock()

        #if DEBUG
            sdk.isDebug = true
        #endif
        sdk.initialize(devKey: configuration.devKey, appId: configuration.appleAppID)
        sdk.handleLaunchOptions(launchOptions)
        sdk.registerSessionReadyListener { [weak self] in
            guard let self else { return }
            self.sdk.customerUserID = self.userID
            trackingAuthorization.whenResolved { [weak self] in
                self?.sdk.start()
            }
        }
    }

    func send(_ event: AnalyticsEvent) {
        guard isInitialized, event.category == .business || event.category == .iap else { return }

        sdk.logEvent(event.name, withValues: Self.eventValues(event.properties))
        if event.name == "iap_status",
            event.properties["status"] == IAPAnalyticsStatus.finished.rawValue
        {
            trackCompletedPurchase(event)
        }
    }

    func setUserID(_ userID: String?) {
        let normalized = Self.normalizedUserID(userID)
        stateLock.lock()
        currentUserID = normalized
        let shouldUpdateSDK = initialized
        stateLock.unlock()

        if shouldUpdateSDK {
            sdk.customerUserID = normalized
        }
    }

    func handleOpenURL(_ url: URL) {
        guard isInitialized else { return }
        sdk.handleOpen(url, options: [:])
    }

    func handleUserActivity(_ userActivity: NSUserActivity) {
        guard isInitialized else { return }
        sdk.continue(userActivity, restorationHandler: nil)
    }

    private var isInitialized: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return initialized
    }

    private var userID: String? {
        stateLock.lock()
        defer { stateLock.unlock() }
        return currentUserID
    }

    private func trackCompletedPurchase(_ event: AnalyticsEvent) {
        guard let amountText = event.properties["pay_amount"],
            let amount = Double(amountText),
            let currency = event.properties["currency"],
            !currency.isEmpty
        else { return }

        var values: [AnyHashable: Any] = [
            AFEventParamRevenue: amount,
            AFEventParamCurrency: currency,
            AFEventParamQuantity: 1,
        ]
        if let productID = event.properties["product_id"] {
            values[AFEventParamContentId] = productID
        }
        if let productType = event.properties["product_type"] {
            values[AFEventParamContentType] = productType
        }
        if let orderID = event.properties["order_id"] ?? event.properties["transaction_id"] {
            values[AFEventParamOrderId] = orderID
        }
        sdk.logEvent(AFEventPurchase, withValues: values)
    }

    private static func eventValues(_ properties: [String: String]) -> [AnyHashable: Any] {
        properties.reduce(into: [:]) { values, property in
            values[property.key] = property.value
        }
    }

    private static func normalizedUserID(_ userID: String?) -> String? {
        let normalized = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized?.isEmpty == false ? normalized : nil
    }
}
