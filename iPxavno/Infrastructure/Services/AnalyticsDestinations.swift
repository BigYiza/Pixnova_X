import FirebaseAnalytics
import Foundation

final class FirebaseAnalyticsDestination: AnalyticsDestination {
    let identifier = "firebase"

    var appInstanceID: String? {
        guard
            let value = FirebaseAnalytics.Analytics.appInstanceID()?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else { return nil }
        return value
    }

    func send(_ event: AnalyticsEvent) {
        FirebaseAnalytics.Analytics.logEvent(event.name, parameters: event.properties)
    }

    func setUserID(_ userID: String?) {
        FirebaseAnalytics.Analytics.setUserID(userID)
    }
}

/// 用于接入闭源或尚未引入编译依赖的分析 SDK，也方便测试时捕获事件。
final class ClosureAnalyticsDestination: AnalyticsDestination {
    let identifier: String
    private let handler: (AnalyticsEvent) -> Void
    private let userHandler: (String?) -> Void
    private let flushHandler: () -> Void

    init(
        identifier: String,
        handler: @escaping (AnalyticsEvent) -> Void,
        userHandler: @escaping (String?) -> Void = { _ in },
        flushHandler: @escaping () -> Void = {}
    ) {
        self.identifier = identifier
        self.handler = handler
        self.userHandler = userHandler
        self.flushHandler = flushHandler
    }

    func send(_ event: AnalyticsEvent) {
        handler(event)
    }

    func setUserID(_ userID: String?) {
        userHandler(userID)
    }

    func flush() {
        flushHandler()
    }
}
