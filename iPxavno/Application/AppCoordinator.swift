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
        guard container.solarEngine.hasPrivacyConsentDecision else {
            presentAnalyticsConsent()
            return
        }

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

    private func presentAnalyticsConsent() {
        guard let presenter = window?.rootViewController else { return }
        let alert = UIAlertController(
            title: "Help improve Pixnova",
            message:
                "Allow analytics and advertising attribution to help us understand app performance and measure promotions. You can decline without losing access to core features. See Privacy Policy in Settings for details.",
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: "Continue without analytics", style: .cancel) { [weak self] _ in
                self?.container.solarEngine.setPrivacyConsent(granted: false)
                self?.showInitialExperience()
            }
        )
        alert.addAction(
            UIAlertAction(title: "Allow analytics", style: .default) { [weak self] _ in
                guard let self else { return }
                self.container.solarEngine.setPrivacyConsent(granted: true)
                // AnalyticsPipeline 可能已在 SDK 启动前广播过一次账号，启动后补齐。
                self.container.analytics.setUserID(self.container.sessionVault.currentCredential?.userID)
                self.showInitialExperience()
            }
        )
        presenter.present(alert, animated: true)
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
