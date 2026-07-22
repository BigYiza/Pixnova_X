import AppTrackingTransparency
import Foundation
import SolarEngineSDK
import UIKit

struct SolarEngineConfiguration {
    let appKey: String
    let attWaitingInterval: Int
    let isGDPRArea: Bool
    let enableODMInfo: Bool

    static func current(bundle: Bundle = .main) -> SolarEngineConfiguration {
        let rawAppKey = bundle.object(forInfoDictionaryKey: "SolarEngineAppKey") as? String ?? ""
        return SolarEngineConfiguration(
            appKey: rawAppKey.trimmingCharacters(in: .whitespacesAndNewlines),
            attWaitingInterval: min(
                max(
                    bundle.object(forInfoDictionaryKey: "SolarEngineATTWaitingInterval") as? Int
                        ?? 60, 0),
                120
            ),
            isGDPRArea: bundle.object(forInfoDictionaryKey: "SolarEngineGDPRArea") as? Bool
                ?? false,
            enableODMInfo: bundle.object(forInfoDictionaryKey: "SolarEngineEnableODMInfo") as? Bool
                ?? false
        )
    }

    var isUsable: Bool {
        appKey.count == 16 && !appKey.contains("$(")
    }
}

/// SolarEngine 的生命周期、归因、ATT 与 AnalyticsDestination 适配集中在此处。
final class SolarEngineAnalyticsDestination: AnalyticsDestination {
    let identifier = "solar_engine"

    weak var analytics: AnalyticsTracking?

    private enum Consent: String {
        case granted
        case denied
    }

    private let configuration: SolarEngineConfiguration
    private let keyValueStore: KeyValueStore
    private let sdk = SolarEngineSDK.sharedInstance()
    private let consentKey = "analytics.solar_engine.privacy_consent.v1"
    private var isStarted = false
    private var didRequestTracking = false

    init(
        configuration: SolarEngineConfiguration = .current(),
        keyValueStore: KeyValueStore = UserDefaults.standard
    ) {
        self.configuration = configuration
        self.keyValueStore = keyValueStore
    }

    var hasPrivacyConsentDecision: Bool {
        Consent(rawValue: keyValueStore.string(forKey: consentKey) ?? "") != nil
    }

    var isPrivacyConsentGranted: Bool {
        keyValueStore.string(forKey: consentKey) == Consent.granted.rawValue
    }

    func preInitialize() {
        guard configuration.isUsable else {
            #if DEBUG
                print("[SolarEngine] AppKey is not configured; SDK remains disabled.")
            #endif
            return
        }
        sdk.preInit(withAppKey: configuration.appKey)
    }

    func startIfConsented() {
        guard isPrivacyConsentGranted else { return }
        start()
    }

    func setPrivacyConsent(granted: Bool) {
        keyValueStore.set(
            granted ? Consent.granted.rawValue : Consent.denied.rawValue,
            forKey: consentKey
        )
        if granted {
            start()
            requestTrackingAuthorizationIfNeeded()
        }
    }

    func requestTrackingAuthorizationIfNeeded() {
        guard isStarted,
            !didRequestTracking,
            ATTrackingManager.trackingAuthorizationStatus == .notDetermined
        else { return }
        didRequestTracking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, UIApplication.shared.applicationState == .active else {
                self?.didRequestTracking = false
                return
            }
            self.sdk.requestTrackingAuthorization { [weak self] status in
                self?.analytics?.record(
                    AnalyticsEvent(
                        name: "tracking_authorization",
                        properties: ["status": Self.authorizationName(status)],
                        category: .lifecycle
                    )
                )
            }
        }
    }

    func handleOpenURL(_ url: URL) {
        guard isStarted else { return }
        sdk.appDeeplinkOpen(url)
    }

    func send(_ event: AnalyticsEvent) {
        guard isStarted else { return }
        sdk.track(event.name, withProperties: event.properties)
        if event.name == "iap_status",
            event.properties["status"] == IAPAnalyticsStatus.finished.rawValue
        {
            trackCompletedIAP(event)
        }
    }

    func setUserID(_ userID: String?) {
        guard isStarted else { return }
        if let userID, !userID.isEmpty {
            sdk.login(withAccountID: userID)
        } else {
            sdk.logout()
        }
    }

    func flush() {
        guard isStarted else { return }
        sdk.reportEventImmediately()
    }

    private func start() {
        guard configuration.isUsable, !isStarted else { return }

        sdk.setAttributionCallback { [weak self] code, data in
            var properties = ["code": String(code)]
            if let data {
                for (key, value) in data {
                    guard let key = key as? String else { continue }
                    properties["attribution_\(Self.validPropertyName(key))"] = String(
                        describing: value)
                }
            }
            self?.analytics?.record(
                AnalyticsEvent(
                    name: "solar_attribution",
                    properties: properties,
                    category: .business
                )
            )
        }
        sdk.setInitCompletedCallback { [weak self] code in
            self?.analytics?.record(
                AnalyticsEvent(
                    name: "solar_init",
                    properties: ["code": String(code)],
                    category: .lifecycle
                )
            )
        }

        let config = SEConfig()
        config.enableAttribution = true
        config.enableAnalytics = true
        config.autoTrackEventType = []
        config.attAuthorizationWaitingInterval = Int32(configuration.attWaitingInterval)
        config.isGDPRArea = configuration.isGDPRArea
        // 海外 SDK 将此配置声明在未被模块 umbrella header 暴露的 ObjC 分类中。
        // 分类实现仍会链接进来，通过 KVC 设置可同时兼容当前与后续版本。
        if config.responds(to: NSSelectorFromString("setEnableODMInfo:")) {
            config.setValue(configuration.enableODMInfo, forKey: "enableODMInfo")
        }
        #if DEBUG
            config.logEnabled = true
        #endif

        isStarted = true
        sdk.start(withAppKey: configuration.appKey, config: config)
    }

    private func trackCompletedIAP(_ event: AnalyticsEvent) {
        guard let productID = event.properties["product_id"],
            let amountText = event.properties["pay_amount"],
            let amount = Double(amountText),
            let currency = event.properties["currency"]
        else { return }

        let attribute = SEIAPEventAttribute()
        attribute.productID = productID
        attribute.productName = event.properties["product_name"] ?? productID
        attribute.productCount = 1
        attribute.orderId = event.properties["order_id"] ?? event.properties["transaction_id"] ?? ""
        attribute.payAmount = amount
        attribute.currencyType = currency
        attribute.payType = SEIAPEventPayTypeApplePay
        attribute.payStatus = .success
        attribute.customProperties = event.properties
        sdk.trackIAP(withAttributes: attribute)
    }

    private static func authorizationName(_ status: UInt) -> String {
        switch status {
        case 0: return "not_determined"
        case 1: return "restricted"
        case 2: return "denied"
        case 3: return "authorized"
        default: return "system_error"
        }
    }

    private static func validPropertyName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let cleaned = value.lowercased().unicodeScalars.map {
            allowed.contains($0) ? Character(String($0)) : "_"
        }
        return String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
