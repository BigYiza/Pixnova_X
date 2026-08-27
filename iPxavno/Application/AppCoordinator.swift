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
        var shouldPromptLogin = false

        do {
            _ = try await container.accountRepository.prepareSession()
            let account = try await container.accountRepository.refreshUserProfile()
            shouldPromptLogin = !account.hasLinkedAccount

            if account.hasLinkedAccount {
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
            } else {
                container.analytics.record(
                    AnalyticsEvent(name: "launch_guest_session", properties: [:])
                )
            }
            refreshContentCatalog()
        } catch {
            shouldPromptLogin = container.accountRepository.cachedAccount?.bindList?.isEmpty == true
            container.analytics.record(
                AnalyticsEvent(
                    name: "launch_account_prepare_failed",
                    properties: ["reason": error.localizedDescription])
            )
            refreshContentCatalog()
        }

        _ = await minimumLaunchDelay
        showInitialExperience(shouldPromptLogin: shouldPromptLogin)
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

    private func showInitialExperience(shouldPromptLogin: Bool) {
        let completed = container.keyValueStore.bool(forKey: AppStorageKey.onboardingCompleted)
        let onboardingEnabled = Bundle.main.object(forInfoDictionaryKey: "OnboardingEnabled") as? Bool
            ?? false

        if completed || !onboardingEnabled {
            showMainInterface(shouldPromptLogin: shouldPromptLogin)
        } else {
            let onboarding = OnboardingViewController()
            onboarding.onFinish = { [weak self] in
                self?.container.keyValueStore.set(true, forKey: AppStorageKey.onboardingCompleted)
                self?.showMainInterface(shouldPromptLogin: shouldPromptLogin)
            }
            setRoot(onboarding)
        }
    }

    private func showMainInterface(shouldPromptLogin: Bool) {
        let main = MainTabBarController(container: container)
        setRoot(main)

        guard shouldPromptLogin else { return }
        DispatchQueue.main.async { [weak self, weak main] in
            guard let self, let main else { return }
            self.container.loginCoordinator.present(from: main, reason: .launch)
        }
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
