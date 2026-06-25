import Foundation

struct AnalyticsEvent {
    let name: String
    let properties: [String: String]
}

protocol AnalyticsTracking {
    func record(_ event: AnalyticsEvent)
}
