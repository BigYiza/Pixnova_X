import AppTrackingTransparency
import UIKit

/// 串行协调 ATT 与首启期间的其他系统权限弹窗，避免并发请求被 iOS 丢弃。
final class TrackingAuthorizationCoordinator {
    weak var analytics: AnalyticsTracking?

    private let stableActiveDelay: TimeInterval
    private var pendingRequest: DispatchWorkItem?
    private var isRequestInFlight = false
    private var hasResolved = false
    private var resolutionHandlers: [() -> Void] = []

    init(stableActiveDelay: TimeInterval = 1) {
        self.stableActiveDelay = stableActiveDelay
    }

    /// 每次 Scene 进入 Active 都调用。只有持续 Active 一小段时间后才发起 ATT。
    func requestIfNeeded() {
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

    /// 归因 SDK 可在 ATT 已确定后启动，避免首个会话早于用户选择发送。
    func whenResolved(_ handler: @escaping () -> Void) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            handler()
            return
        }
        resolutionHandlers.append(handler)
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
        analytics?.record(
            AnalyticsEvent(
                name: "tracking_authorization",
                properties: ["status": Self.authorizationName(status)],
                category: .lifecycle
            )
        )

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
