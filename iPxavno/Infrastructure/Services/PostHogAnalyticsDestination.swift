import Foundation
import PostHog

struct PostHogAnalyticsConfiguration {
    let projectToken: String
    let host: String
    let appID: String

    static let live = PostHogAnalyticsConfiguration(
        projectToken: "phc_Bw5T9UbUG9TatM2nZwDNHNfaytN9X6Q5kydvjy3dTQZn",
        host: "https://us.i.posthog.com",
        appID: "pixvidai"
    )

    var isUsable: Bool {
        projectToken.hasPrefix("phc_") && URL(string: host)?.scheme == "https" && !appID.isEmpty
    }
}

/// PostHog 的初始化、统一事件转发和用户身份切换集中在此处。
final class PostHogAnalyticsDestination: AnalyticsDestination {
    let identifier = "posthog"

    private let configuration: PostHogAnalyticsConfiguration
    private let sdk: PostHogSDK
    private let stateLock = NSLock()
    private var started = false

    init(
        configuration: PostHogAnalyticsConfiguration = .live,
        sdk: PostHogSDK = .shared
    ) {
        self.configuration = configuration
        self.sdk = sdk
    }

    func start() {
        guard configuration.isUsable else {
            #if DEBUG
                print("[PostHog] Project token, host, or app ID is invalid; SDK remains disabled.")
            #endif
            return
        }

        stateLock.lock()
        guard !started else {
            stateLock.unlock()
            return
        }
        started = true
        stateLock.unlock()

        let appID = configuration.appID
        let config = PostHogConfig(
            projectToken: configuration.projectToken,
            host: configuration.host
        )
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.captureElementInteractions = false
        config.sessionReplay = false
        config.surveys = false
        config.capturePushNotificationSubscriptions = false
        config.capturePushNotificationOpened = false
        config.errorTrackingConfig.autoCapture = false
        #if DEBUG
            config.debug = true
        #endif
        config.setBeforeSend { event in
            event.properties["app_id"] = appID
            return event
        }

        sdk.setup(config)
        registerAppID()
    }

    func send(_ event: AnalyticsEvent) {
        guard isStarted else { return }
        sdk.capture(
            event.name,
            properties: event.properties,
            timestamp: event.timestamp
        )
    }

    func setUserID(_ userID: String?) {
        guard isStarted else { return }

        let normalizedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalizedUserID, !normalizedUserID.isEmpty else {
            resetIdentityIfIdentified()
            return
        }

        let currentDistinctID = sdk.getDistinctId()
        let isIdentified = !currentDistinctID.isEmpty && currentDistinctID != sdk.getAnonymousId()
        if isIdentified && currentDistinctID != normalizedUserID {
            resetIdentity()
        }
        sdk.identify(normalizedUserID)
    }

    func flush() {
        guard isStarted else { return }
        sdk.flush()
    }

    private var isStarted: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return started
    }

    private func resetIdentityIfIdentified() {
        let currentDistinctID = sdk.getDistinctId()
        guard !currentDistinctID.isEmpty, currentDistinctID != sdk.getAnonymousId() else { return }
        resetIdentity()
    }

    private func resetIdentity() {
        sdk.reset()
        registerAppID()
    }

    private func registerAppID() {
        sdk.register(["app_id": configuration.appID])
    }
}
