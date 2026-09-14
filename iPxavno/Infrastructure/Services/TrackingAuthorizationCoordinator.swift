import AppTrackingTransparency
import UIKit

/// 串行协调 ATT 与首启期间的其他系统权限弹窗，避免并发请求被 iOS 丢弃。
final class TrackingAuthorizationCoordinator {
    weak var analytics: AnalyticsTracking?

    private let stableActiveDelay: TimeInterval
    private let authorizationWaitTimeout: TimeInterval
    private var pendingRequest: DispatchWorkItem?
    private var waitTimeoutRequest: DispatchWorkItem?
    private var isRequestInFlight = false
    private var hasResolved = false
    private var hasWaitTimedOut = false
    private var resolutionHandlers: [() -> Void] = []

    init(
        stableActiveDelay: TimeInterval = 1,
        authorizationWaitTimeout: TimeInterval = 60
    ) {
        self.stableActiveDelay = stableActiveDelay
        self.authorizationWaitTimeout = authorizationWaitTimeout
    }

    /// 每次 Scene 进入 Active 都调用。只有持续 Active 一小段时间后才发起 ATT。
    func requestIfNeeded() {
        releaseTimedOutHandlersIfPossible()
        guard !hasResolved,
            ATTrackingManager.trackingAuthorizationStatus == .notDetermined,
            !isRequestInFlight
        else {
            resolveIfDetermined()
            return
        }

        pendingRequest?.cancel()
        let request = DispatchWorkItem { [weak self] in
            self?.performRequestIfPossible()
        }
        pendingRequest = request
        DispatchQueue.main.asyncAfter(
            deadline: .now() + stableActiveDelay,
            execute: request
        )
    }

    /// 网络权限等系统弹窗出现时 Scene 会失活，取消尚未发出的 ATT 请求。
    func sceneWillResignActive() {
        pendingRequest?.cancel()
        pendingRequest = nil
    }

    /// 归因 SDK 优先在 ATT 已确定后启动；等待超时后放行，避免 SKAN 和首个会话被无限阻塞。
    func whenResolved(_ handler: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            handler()
            return
        }
        resolutionHandlers.append(handler)
        guard !hasWaitTimedOut else {
            releaseTimedOutHandlersIfPossible()
            return
        }
        scheduleWaitTimeoutIfNeeded()
    }

    private func scheduleWaitTimeoutIfNeeded() {
        guard waitTimeoutRequest == nil else { return }
        let request = DispatchWorkItem { [weak self] in
            self?.handleWaitTimeout()
        }
        waitTimeoutRequest = request
        DispatchQueue.main.asyncAfter(
            deadline: .now() + authorizationWaitTimeout,
            execute: request
        )
    }

    private func handleWaitTimeout() {
        waitTimeoutRequest = nil
        guard !hasResolved, !hasWaitTimedOut else { return }
        hasWaitTimedOut = true
        analytics?.record(
            AnalyticsEvent(
                name: "tracking_authorization_wait_timeout",
                properties: ["timeout_seconds": String(authorizationWaitTimeout)],
                category: .lifecycle
            )
        )
        releaseTimedOutHandlersIfPossible()
    }

    private func releaseTimedOutHandlersIfPossible() {
        guard hasWaitTimedOut, UIApplication.shared.applicationState == .active else { return }
        releaseResolutionHandlers()
    }

    private func performRequestIfPossible() {
        pendingRequest = nil
        guard UIApplication.shared.applicationState == .active else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            resolveIfDetermined()
            return
        }
        guard !isRequestInFlight else { return }

        isRequestInFlight = true
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRequestInFlight = false

                // iOS 在另一个系统权限弹窗待处理时可能直接返回 notDetermined。
                // 保留本次会话的重试，而不是错误地等待下次启动。
                guard status != .notDetermined,
                    ATTrackingManager.trackingAuthorizationStatus != .notDetermined
                else {
                    self.requestIfNeeded()
                    return
                }
                self.finish(with: status)
            }
        }
    }

    private func resolveIfDetermined() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status != .notDetermined else { return }
        finish(with: status)
    }

    private func finish(with status: ATTrackingManager.AuthorizationStatus) {
        guard !hasResolved else { return }
        hasResolved = true
        pendingRequest?.cancel()
        pendingRequest = nil
        waitTimeoutRequest?.cancel()
        waitTimeoutRequest = nil
        analytics?.record(
            AnalyticsEvent(
                name: "tracking_authorization",
                properties: ["status": Self.authorizationName(status)],
                category: .lifecycle
            )
        )

        releaseResolutionHandlers()
    }

    private func releaseResolutionHandlers() {
        let handlers = resolutionHandlers
        resolutionHandlers.removeAll()
        handlers.forEach { $0() }
    }

    private static func authorizationName(
        _ status: ATTrackingManager.AuthorizationStatus
    ) -> String {
        switch status {
        case .notDetermined: return "not_determined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "system_error"
        }
    }
}
