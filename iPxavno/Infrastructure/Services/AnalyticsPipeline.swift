import Foundation
import UIKit

/// 线程安全的埋点总线。事件在串行队列中按发生顺序扇出，任一 SDK 都不会阻塞 UI 或业务流程。
final class AnalyticsPipeline: AnalyticsTracking {
    typealias PropertyProvider = () -> [String: String]

    private let queue = DispatchQueue(label: "com.pixnova.analytics.pipeline", qos: .utility)
    private var destinations: [AnalyticsDestination]
    private let propertyProviders: [PropertyProvider]
    private let sessionID = UUID().uuidString

    init(
        destinations: [AnalyticsDestination],
        propertyProviders: [PropertyProvider] = []
    ) {
        self.destinations = destinations
        self.propertyProviders = propertyProviders
    }

    func record(_ event: AnalyticsEvent) {
        let enriched = enrichedEvent(from: event)
        queue.async { [weak self] in
            self?.destinations.forEach { $0.send(enriched) }
        }
    }

    func setUserID(_ userID: String?) {
        queue.async { [weak self] in
            self?.destinations.forEach { $0.setUserID(userID) }
        }
    }

    func flush() {
        queue.async { [weak self] in
            self?.destinations.forEach { $0.flush() }
        }
    }

    /// 新增 GA、热力图或自研引擎时，在组合根注册 Destination 即可。
    func add(destination: AnalyticsDestination) {
        queue.async { [weak self] in
            guard let self,
                !self.destinations.contains(where: { $0.identifier == destination.identifier })
            else { return }
            self.destinations.append(destination)
        }
    }

    private func enrichedEvent(from event: AnalyticsEvent) -> AnalyticsEvent {
        var common = Self.defaultProperties(sessionID: sessionID)
        propertyProviders.forEach { provider in
            common.merge(provider()) { _, new in new }
        }
        common.merge(event.properties) { _, eventValue in eventValue }
        common["event_id"] = UUID().uuidString
        common["event_category"] = event.category.rawValue

        return AnalyticsEvent(
            name: Self.sanitizedEventName(event.name),
            properties: Self.sanitizedProperties(common),
            category: event.category,
            timestamp: event.timestamp
        )
    }

    private static func defaultProperties(sessionID: String) -> [String: String] {
        let bundle = Bundle.main
        return [
            "session_id": sessionID,
            "app_version": bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String
                ?? "unknown",
            "app_build": bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
                ?? "unknown",
            "os": "iOS",
            "os_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
        ]
    }

    private static func sanitizedEventName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        var result = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" }
        if result.first?.isNumber == true {
            result.insert("e", at: 0)
            result.insert("_", at: 1)
        }
        return String(result.prefix(40))
    }

    private static func sanitizedProperties(_ properties: [String: String]) -> [String: String] {
        let sensitiveFragments = [
            "password", "receipt", "authorization", "access_token", "refresh_token",
        ]
        return properties.reduce(into: [:]) { result, pair in
            let normalizedKey = pair.key.lowercased()
            guard !sensitiveFragments.contains(where: normalizedKey.contains) else { return }
            result[pair.key] = String(pair.value.prefix(500))
        }
    }
}
