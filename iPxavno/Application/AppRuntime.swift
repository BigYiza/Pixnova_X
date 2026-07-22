import FirebaseCore
import UIKit

final class AppRuntime {
    static let shared = AppRuntime()

    let container: DependencyContainer
    private lazy var analyticsMonitor = AnalyticsAppMonitor(tracker: container.analytics)

    private init(container: DependencyContainer = .live()) {
        self.container = container
    }

    func configureForLaunch(
        application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        container.solarEngine.preInitialize()
        container.solarEngine.startIfConsented()
        container.analytics.setUserID(container.sessionVault.currentCredential?.userID)
        AnalyticsAutoInstrumentation.start(tracker: container.analytics)
        analyticsMonitor.start(applicationState: application.applicationState)
    }
}
