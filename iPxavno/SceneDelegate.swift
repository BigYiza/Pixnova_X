import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var coordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let coordinator = AppCoordinator(container: AppRuntime.shared.container)
        self.coordinator = coordinator
        coordinator.start(in: windowScene)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        Task {
            do {
                try await AppRuntime.shared.container.membershipHandler
                    .maintainStatusAfterSessionPrepared()
            } catch {
                AppRuntime.shared.container.analytics.record(
                    AnalyticsEvent(
                        name: "membership_foreground_refresh_failed",
                        properties: ["reason": error.localizedDescription])
                )
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppRuntime.shared.container.solarEngine.requestTrackingAuthorizationIfNeeded()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        URLContexts.forEach { context in
            AppRuntime.shared.container.solarEngine.handleOpenURL(context.url)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        AppRuntime.shared.container.solarEngine.handleOpenURL(url)
    }
}
