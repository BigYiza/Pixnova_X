import Foundation

final class ConsoleAnalyticsDestination: AnalyticsDestination {
    let identifier = "console"

    func send(_ event: AnalyticsEvent) {
        #if DEBUG
            print("[Analytics][\(event.category.rawValue)]", event.name, event.properties)
        #endif
    }
}
