import UIKit

final class MainTabBarController: UIViewController {
    private let container: DependencyContainer
    private let contentView = UIView()
    private lazy var designTabBar = DesignTabBarView(items: [
        DesignTabBarItem(title: "Home", normalImageName: "i-home_daf", selectedImageName: "i-home_sel"),
        DesignTabBarItem(title: "Video", normalImageName: "i-video_daf", selectedImageName: "i-video_sel"),
        DesignTabBarItem(title: "Filters", normalImageName: "i-spark_daf", selectedImageName: "i-spark_sel"),
        DesignTabBarItem(title: "Photo", normalImageName: "i-photo_daf", selectedImageName: "i-photo_sel"),
        DesignTabBarItem(title: "Me", normalImageName: "i-me_daf", selectedImageName: "i-me_sel")
    ])
    private var tabBarHeightConstraint: NSLayoutConstraint?
    private var childControllers: [UINavigationController] = []
    private var selectedIndex = 0

    init(container: DependencyContainer) {
        self.container = container
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.Color.background
        configureChildControllers()
        configureHierarchy()
        selectTab(at: 0)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        tabBarHeightConstraint?.constant = DesignTabBarView.contentHeight + view.safeAreaInsets.bottom
    }

    private func configureChildControllers() {
        let discover = DiscoverViewController(
            viewModel: DiscoverViewModel(
                tab: .home,
                contentRepository: container.contentRepository,
                membershipHandler: container.membershipHandler,
                membershipPurchaseHandler: container.membershipPurchaseHandler,
                diamondPurchaseHandler: container.diamondPurchaseHandler,
                generationRepository: container.generationRepository,
                generationWorkflowRunner: container.generationWorkflowRunner,
                analytics: container.analytics
            )
        )
        discover.title = "Home"

        let video = makeDiscoverTab(tab: .video)
        let filters = makeDiscoverTab(tab: .filters)
        let photo = makeDiscoverTab(tab: .photo)

        let profile = ProfileViewController(
            viewModel: ProfileViewModel(
                membershipHandler: container.membershipHandler,
                analytics: container.analytics
            )
        )
        profile.title = "Me"

        childControllers = [discover, video, filters, photo, profile].map { viewController in
            let navigationController = SwipeBackNavigationController(rootViewController: viewController)
            navigationController.additionalSafeAreaInsets.bottom = DesignTabBarView.contentHeight
            navigationController.delegate = self
            navigationController.view.backgroundColor = AppTheme.Color.background
            return navigationController
        }
    }

    private func makeDiscoverTab(tab: HomePageTab) -> DiscoverViewController {
        let viewController = DiscoverViewController(
            viewModel: DiscoverViewModel(
                tab: tab,
                contentRepository: container.contentRepository,
                membershipHandler: container.membershipHandler,
                membershipPurchaseHandler: container.membershipPurchaseHandler,
                diamondPurchaseHandler: container.diamondPurchaseHandler,
                generationRepository: container.generationRepository,
                generationWorkflowRunner: container.generationWorkflowRunner,
                analytics: container.analytics
            )
        )
        viewController.title = tab.title
        return viewController
    }

    private func configureHierarchy() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = AppTheme.Color.background
        view.addSubview(contentView)

        designTabBar.translatesAutoresizingMaskIntoConstraints = false
        designTabBar.delegate = self
        view.addSubview(designTabBar)

        let heightConstraint = designTabBar.heightAnchor.constraint(
            equalToConstant: DesignTabBarView.contentHeight + view.safeAreaInsets.bottom
        )
        tabBarHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            designTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            designTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            designTabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            heightConstraint
        ])
    }

    private func selectTab(at index: Int) {
        guard childControllers.indices.contains(index), index != selectedIndex || children.isEmpty else { return }

        let previousController = children.first
        let nextController = childControllers[index]
        selectedIndex = index
        designTabBar.select(index: index)
        updateTabBarVisibility(for: nextController.topViewController, in: nextController, animated: false)

        UIView.performWithoutAnimation {
            previousController?.willMove(toParent: nil)
            previousController?.view.removeFromSuperview()
            previousController?.removeFromParent()

            addChild(nextController)
            nextController.view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(nextController.view)

            NSLayoutConstraint.activate([
                nextController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                nextController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                nextController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                nextController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            nextController.didMove(toParent: self)
            view.layoutIfNeeded()
        }
    }

    private func updateTabBarVisibility(
        for viewController: UIViewController?,
        in navigationController: UINavigationController,
        animated: Bool
    ) {
        let shouldHide = viewController?.hidesBottomBarWhenPushed == true
        let bottomInset = shouldHide ? 0 : DesignTabBarView.contentHeight

        navigationController.additionalSafeAreaInsets.bottom = bottomInset
        guard designTabBar.isHidden != shouldHide || designTabBar.alpha != (shouldHide ? 0 : 1) else {
            return
        }

        let updates = {
            self.designTabBar.alpha = shouldHide ? 0 : 1
        }

        if animated {
            if !shouldHide {
                designTabBar.isHidden = false
            }
            UIView.animate(withDuration: 0.2, animations: updates) { _ in
                self.designTabBar.isHidden = shouldHide
            }
        } else {
            updates()
            designTabBar.isHidden = shouldHide
        }
    }
}

private final class SwipeBackNavigationController: UINavigationController, UIGestureRecognizerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1 && transitionCoordinator == nil
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === interactivePopGestureRecognizer
    }
}

extension MainTabBarController: DesignTabBarViewDelegate {
    func designTabBarView(_ tabBarView: DesignTabBarView, didSelect index: Int) {
        selectTab(at: index)
    }
}

extension MainTabBarController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        updateTabBarVisibility(for: viewController, in: navigationController, animated: animated)
    }
}
