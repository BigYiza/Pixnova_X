import Foundation
import UIKit

/// 采集 App 生命周期、会话时长、内存/温度告警及主线程响应延迟。
final class AnalyticsAppMonitor {
    private let tracker: AnalyticsTracking
    private let launchUptime = ProcessInfo.processInfo.systemUptime
    private let heartbeatQueue = DispatchQueue(
        label: "com.pixnova.analytics.heartbeat", qos: .utility)
    private var heartbeat: DispatchSourceTimer?
    private var notificationTokens: [NSObjectProtocol] = []
    private var activeSince: TimeInterval?
    private var hasBecomeActive = false
    private var lastStallReportUptime: TimeInterval = 0

    init(tracker: AnalyticsTracking) {
        self.tracker = tracker
    }

    @MainActor
    func start(applicationState: UIApplication.State) {
        guard notificationTokens.isEmpty else { return }
        recordState("launched", properties: ["initial_state": applicationState.analyticsValue])
        observeLifecycle()
        startHeartbeat()
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        heartbeat?.cancel()
    }

    @MainActor
    private func observeLifecycle() {
        let center = NotificationCenter.default
        notificationTokens = [
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                if self.activeSince == nil {
                    self.activeSince = now
                }
                let properties =
                    self.hasBecomeActive
                    ? [:]
                    : ["launch_to_active_ms": Self.milliseconds(now - self.launchUptime)]
                self.hasBecomeActive = true
                self.recordState("active", properties: properties)
            },
            center.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.finishActiveSession(state: "inactive")
            },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.recordState("background")
                self?.tracker.flush()
            },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.recordState("foreground")
            },
            center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.tracker.record(
                    AnalyticsEvent(name: "memory_warning", category: .performance)
                )
            },
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.tracker.record(
                    AnalyticsEvent(
                        name: "thermal_state_changed",
                        properties: ["state": ProcessInfo.processInfo.thermalState.analyticsValue],
                        category: .performance
                    )
                )
            },
            center.addObserver(
                forName: UIApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.finishActiveSession(state: "terminated")
                self?.tracker.flush()
            },
            center.addObserver(
                forName: AccountNotifications.accountDidChange, object: nil, queue: .main
            ) { [weak self] notification in
                let account =
                    notification.userInfo?[AccountNotificationUserInfoKey.account]
                    as? AccountSnapshot
                let userID = account?.userID.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.tracker.setUserID(userID?.isEmpty == false ? userID : nil)
            },
        ]
    }

    private func startHeartbeat() {
        let timer = DispatchSource.makeTimerSource(queue: heartbeatQueue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let sentAt = ProcessInfo.processInfo.systemUptime
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let now = ProcessInfo.processInfo.systemUptime
                let lag = now - sentAt
                guard let activeSince = self.activeSince,
                    sentAt >= activeSince,
                    lag >= 0.25,
                    now - self.lastStallReportUptime >= 10
                else { return }
                self.lastStallReportUptime = now
                self.tracker.record(
                    AnalyticsEvent(
                        name: "app_response",
                        properties: [
                            "main_thread_lag_ms": Self.milliseconds(lag),
                            "severity": lag >= 1 ? "blocked" : "slow",
                        ],
                        category: .performance
                    )
                )
            }
        }
        heartbeat = timer
        timer.resume()
    }

    private func finishActiveSession(state: String) {
        let now = ProcessInfo.processInfo.systemUptime
        var properties: [String: String] = [:]
        if let activeSince {
            properties["active_duration_ms"] = Self.milliseconds(now - activeSince)
        }
        activeSince = nil
        recordState(state, properties: properties)
    }

    private func recordState(_ state: String, properties: [String: String] = [:]) {
        tracker.record(
            AnalyticsEvent(
                name: "app_state",
                properties: properties.merging(["state": state]) { current, _ in current },
                category: .lifecycle
            )
        )
    }

    private static func milliseconds(_ interval: TimeInterval) -> String {
        String(Int(max(0, interval) * 1_000))
    }
}

extension UIApplication.State {
    fileprivate var analyticsValue: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

extension ProcessInfo.ThermalState {
    fileprivate var analyticsValue: String {
        switch self {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
