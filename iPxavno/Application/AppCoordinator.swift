import UIKit

@MainActor
final class AppCoordinator {
    private let container: DependencyContainer
    private var window: UIWindow?

    init(container: DependencyContainer) {
        self.container = container
    }

    func start(in windowScene: UIWindowScene) {
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        window.rootViewController = LaunchViewController()
        window.makeKeyAndVisible()

        Task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        async let minimumLaunchDelay: Void = waitForLaunchRhythm()

        do {
            let membership = try await container.membershipHandler
                .maintainStatusAfterSessionPrepared()
            container.analytics.record(
                AnalyticsEvent(
                    name: "launch_membership_maintained",
                    properties: [
                        "member": "\(membership.isVIP)", "diamonds": "\(membership.diamonds)",
                    ]
                )
            )
            refreshContentCatalog()
        } catch {
            container.analytics.record(
                AnalyticsEvent(
                    name: "launch_membership_maintain_failed",
                    properties: ["reason": error.localizedDescription])
            )
            refreshContentCatalog()
        }

        _ = await minimumLaunchDelay
        showInitialExperience()
    }

    private func waitForLaunchRhythm() async {
        try? await Task.sleep(nanoseconds: 900_000_000)
    }

    private func refreshContentCatalog() {
        Task {
            do {
                let cards = try await container.contentRepository.refreshAllCards()
                container.analytics.record(
                    AnalyticsEvent(
                        name: "content_catalog_refreshed", properties: ["cards": "\(cards.count)"])
                )
            } catch {
                container.analytics.record(
                    AnalyticsEvent(
                        name: "content_catalog_refresh_failed",
                        properties: ["reason": error.localizedDescription])
                )
            }
        }
    }

    private func showInitialExperience() {
        let completed = container.keyValueStore.bool(forKey: AppStorageKey.onboardingCompleted)

        if completed {
            showMainInterface()
        } else {
            let onboarding = OnboardingViewController()
            onboarding.onFinish = { [weak self] in
                self?.container.keyValueStore.set(true, forKey: AppStorageKey.onboardingCompleted)
                self?.showMainInterface()
            }
            setRoot(onboarding)
        }
    }

    private func showMainInterface() {
        setRoot(MainTabBarController(container: container))
    }

    private func setRoot(_ viewController: UIViewController) {
        guard let window else { return }

        UIView.transition(
            with: window,
            duration: 0.28,
            options: [.transitionCrossDissolve, .allowAnimatedContent],
            animations: {
                window.rootViewController = viewController
            }
        )
    }
}
