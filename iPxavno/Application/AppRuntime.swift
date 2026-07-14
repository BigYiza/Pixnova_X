import UIKit
import FirebaseCore

final class AppRuntime {
    static let shared = AppRuntime()

    let container: DependencyContainer

    private init(container: DependencyContainer = .live()) {
        self.container = container
    }

    func configureForLaunch(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        container.analytics.record(
            AnalyticsEvent(
                name: "app_launch",
                properties: ["state": application.applicationState.analyticsValue]
            )
        )
        
        FirebaseApp.configure()
    }
}

private extension UIApplication.State {
    var analyticsValue: String {
        switch self {
        case .active:
            return "active"
        case .inactive:
            return "inactive"
        case .background:
            return "background"
        @unknown default:
            return "unknown"
        }
    }
}
