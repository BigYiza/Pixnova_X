import Foundation

final class ConsoleAnalyticsTracker: AnalyticsTracking {
    func record(_ event: AnalyticsEvent) {
        #if DEBUG
        print("[Analytics]", event.name, event.properties)
        #endif
    }
}
