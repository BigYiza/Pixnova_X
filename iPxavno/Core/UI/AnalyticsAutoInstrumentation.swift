import ObjectiveC.runtime
import UIKit

/// UIKit 无侵入采集：页面展示 + 真实点击坐标。坐标字段可直接供后续热力图 Destination 使用。
enum AnalyticsAutoInstrumentation {
    private static weak var tracker: AnalyticsTracking?
    private static var started = false

    @MainActor
    static func start(tracker: AnalyticsTracking) {
        self.tracker = tracker
        guard !started else { return }
        started = true
        swizzle(
            UIWindow.self,
            original: #selector(UIWindow.sendEvent(_:)),
            replacement: #selector(UIWindow.analytics_sendEvent(_:))
        )
        swizzle(
            UIViewController.self,
            original: #selector(UIViewController.viewDidAppear(_:)),
            replacement: #selector(UIViewController.analytics_viewDidAppear(_:))
        )
    }

    fileprivate static func recordClick(touch: UITouch, in window: UIWindow) {
        guard let tracker,
            let touchedView = touch.view,
            !touchedView.analyticsTrackingDisabled
        else { return }

        let point = touch.location(in: window)
        let bounds = window.bounds
        let screen = touchedView.containingViewController?.analyticsResolvedScreenName ?? "unknown"
        tracker.trackClick(
            element: touchedView.analyticsResolvedElementName,
            screen: screen,
            properties: [
                "element_type": String(describing: type(of: touchedView)),
                "element_path": touchedView.analyticsHierarchyPath,
                "x": Self.decimal(point.x),
                "y": Self.decimal(point.y),
                "x_ratio": Self.decimal(bounds.width > 0 ? point.x / bounds.width : 0),
                "y_ratio": Self.decimal(bounds.height > 0 ? point.y / bounds.height : 0),
                "screen_width": Self.decimal(bounds.width),
                "screen_height": Self.decimal(bounds.height),
            ]
        )
    }

    fileprivate static func recordScreen(_ viewController: UIViewController) {
        guard let tracker,
            Bundle(for: type(of: viewController)) == .main,
            !viewController.analyticsTrackingDisabled,
            viewController.viewIfLoaded?.window != nil
        else { return }

        tracker.trackScreen(
            name: viewController.analyticsResolvedScreenName,
            viewController: String(describing: type(of: viewController)),
            properties: [
                "presentation_style": String(viewController.modalPresentationStyle.rawValue),
                "is_modal": String(viewController.presentingViewController != nil),
            ]
        )
    }

    private static func swizzle(_ type: AnyClass, original: Selector, replacement: Selector) {
        guard let originalMethod = class_getInstanceMethod(type, original),
            let replacementMethod = class_getInstanceMethod(type, replacement)
        else { return }
        method_exchangeImplementations(originalMethod, replacementMethod)
    }

    private static func decimal(_ value: CGFloat) -> String {
        String(format: "%.4f", Double(value))
    }
}

private enum AnalyticsAssociatedKey {
    static var screenName: UInt8 = 0
    static var elementID: UInt8 = 0
    static var trackingDisabled: UInt8 = 0
}

extension UIViewController {
    var analyticsScreenName: String? {
        get { objc_getAssociatedObject(self, &AnalyticsAssociatedKey.screenName) as? String }
        set {
            objc_setAssociatedObject(
                self, &AnalyticsAssociatedKey.screenName, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC
            )
        }
    }

    var analyticsTrackingDisabled: Bool {
        get {
            (objc_getAssociatedObject(self, &AnalyticsAssociatedKey.trackingDisabled) as? Bool)
                ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &AnalyticsAssociatedKey.trackingDisabled, newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    fileprivate var analyticsResolvedScreenName: String {
        analyticsScreenName
            ?? String(describing: type(of: self)).replacingOccurrences(
                of: "ViewController", with: "")
    }

    @objc fileprivate func analytics_viewDidAppear(_ animated: Bool) {
        analytics_viewDidAppear(animated)
        AnalyticsAutoInstrumentation.recordScreen(self)
    }
}

extension UIView {
    var analyticsElementID: String? {
        get { objc_getAssociatedObject(self, &AnalyticsAssociatedKey.elementID) as? String }
        set {
            objc_setAssociatedObject(
                self, &AnalyticsAssociatedKey.elementID, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    var analyticsTrackingDisabled: Bool {
        get {
            (objc_getAssociatedObject(self, &AnalyticsAssociatedKey.trackingDisabled) as? Bool)
                ?? false
        }
        set {
            objc_setAssociatedObject(
                self, &AnalyticsAssociatedKey.trackingDisabled, newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    fileprivate var containingViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController { return viewController }
            responder = current.next
        }
        return nil
    }

    fileprivate var analyticsResolvedElementName: String {
        var candidate: UIView? = self
        while let view = candidate {
            if let explicit = view.analyticsElementID ?? view.accessibilityIdentifier,
                !explicit.isEmpty
            {
                return explicit
            }
            if let button = view as? UIButton,
                let title = button.title(for: button.state), !title.isEmpty
            {
                return String(title.prefix(80))
            }
            if let cell = view as? UICollectionViewCell, let reuseIdentifier = cell.reuseIdentifier
            {
                return reuseIdentifier
            }
            if let cell = view as? UITableViewCell, let reuseIdentifier = cell.reuseIdentifier {
                return reuseIdentifier
            }
            candidate = view.superview
        }
        return String(describing: type(of: self))
    }

    fileprivate var analyticsHierarchyPath: String {
        var components: [String] = []
        var candidate: UIView? = self
        while let view = candidate, components.count < 8 {
            let typeName = String(describing: type(of: view))
            let siblingIndex = view.superview?.subviews.firstIndex(where: { $0 === view }) ?? 0
            components.append("\(typeName)[\(siblingIndex)]")
            candidate = view.superview
        }
        return components.reversed().joined(separator: "/")
    }
}

extension UIWindow {
    @objc fileprivate func analytics_sendEvent(_ event: UIEvent) {
        if let touches = event.allTouches {
            for touch in touches where touch.phase == .ended {
                let start = AnalyticsTouchStore.shared.start(for: touch)
                let end = touch.location(in: self)
                if let start,
                    hypot(end.x - start.point.x, end.y - start.point.y) <= 14,
                    touch.timestamp - start.timestamp <= 1.2
                {
                    AnalyticsAutoInstrumentation.recordClick(touch: touch, in: self)
                }
                AnalyticsTouchStore.shared.remove(touch)
            }
            for touch in touches where touch.phase == .began {
                AnalyticsTouchStore.shared.store(touch, point: touch.location(in: self))
            }
            for touch in touches where touch.phase == .cancelled {
                AnalyticsTouchStore.shared.remove(touch)
            }
        }
        analytics_sendEvent(event)
    }
}

private final class AnalyticsTouchStore {
    struct Start {
        let point: CGPoint
        let timestamp: TimeInterval
    }

    static let shared = AnalyticsTouchStore()
    private var starts: [ObjectIdentifier: Start] = [:]

    func store(_ touch: UITouch, point: CGPoint) {
        starts[ObjectIdentifier(touch)] = Start(point: point, timestamp: touch.timestamp)
    }

    func start(for touch: UITouch) -> Start? {
        starts[ObjectIdentifier(touch)]
    }

    func remove(_ touch: UITouch) {
        starts.removeValue(forKey: ObjectIdentifier(touch))
    }
}
