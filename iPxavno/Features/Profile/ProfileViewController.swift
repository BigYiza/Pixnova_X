import UIKit

final class ProfileViewController: BaseViewController {
    private let viewModel: ProfileViewModel
    private let titleLabel = UILabel()
    private let settingsButton = UIButton(type: .system)
    private let diamondButton = UIControl()
    private let diamondIcon = UILabel()
    private let diamondLabel = UILabel()
    private let refreshControl = UIRefreshControl()
    private var displayedErrorMessage: String?
    private var state = ProfileViewState.initial
    private lazy var collectionView = UICollectionView(
        frame: .zero,
        collectionViewLayout: UICollectionViewFlowLayout()
    )

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = nil
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureView()
        bindViewModel()
        viewModel.load()
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background
        configureHeader()
        configureCollectionView()

        view.addSubview(titleLabel)
        view.addSubview(settingsButton)
        view.addSubview(diamondButton)
        diamondButton.addSubview(diamondIcon)
        diamondButton.addSubview(diamondLabel)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            titleLabel.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),

            settingsButton.trailingAnchor.constraint(equalTo: diamondButton.leadingAnchor, constant: -11),
            settingsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            settingsButton.widthAnchor.constraint(equalToConstant: 42),
            settingsButton.heightAnchor.constraint(equalToConstant: 42),

            diamondButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            diamondButton.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            diamondButton.widthAnchor.constraint(equalToConstant: 91),
            diamondButton.heightAnchor.constraint(equalToConstant: 45),

            diamondIcon.leadingAnchor.constraint(equalTo: diamondButton.leadingAnchor, constant: 14),
            diamondIcon.centerYAnchor.constraint(equalTo: diamondButton.centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 22),
            diamondIcon.heightAnchor.constraint(equalToConstant: 22),

            diamondLabel.leadingAnchor.constraint(equalTo: diamondIcon.trailingAnchor, constant: 3),
            diamondLabel.trailingAnchor.constraint(equalTo: diamondButton.trailingAnchor, constant: -11),
            diamondLabel.centerYAnchor.constraint(equalTo: diamondButton.centerYAnchor),

            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: settingsButton.bottomAnchor, constant: 19),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureHeader() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Me"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.tintColor = UIColor(hex: 0x9A9AA2)
        settingsButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        settingsButton.layer.cornerRadius = 21
        settingsButton.layer.borderWidth = 1
        settingsButton.layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        settingsButton.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settingsButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .medium),
            forImageIn: .normal
        )
        settingsButton.addTarget(self, action: #selector(handleSettingsTap), for: .touchUpInside)

        diamondButton.translatesAutoresizingMaskIntoConstraints = false
        diamondButton.backgroundColor = HomeDesignColor.accent
        diamondButton.layer.cornerRadius = 22.5
        diamondButton.clipsToBounds = true
        diamondButton.accessibilityTraits = [.button]
        diamondButton.addTarget(self, action: #selector(handleDiamondTap), for: .touchUpInside)

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.text = "💎"
        diamondIcon.font = UIFont.systemFont(ofSize: 15)
        diamondIcon.textAlignment = .center

        diamondLabel.translatesAutoresizingMaskIntoConstraints = false
        diamondLabel.textColor = HomeDesignColor.blackText
        diamondLabel.font = UIFont.systemFont(ofSize: 17.5, weight: .bold)
        diamondLabel.adjustsFontSizeToFitWidth = true
        diamondLabel.minimumScaleFactor = 0.75
    }

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = HomeDesignColor.background
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInset.bottom = 18
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        collectionView.register(
            ProfileMembershipCardCell.self,
            forCellWithReuseIdentifier: ProfileMembershipCardCell.reuseIdentifier
        )
        collectionView.register(
            ProfileHistoryTaskCell.self,
            forCellWithReuseIdentifier: ProfileHistoryTaskCell.reuseIdentifier
        )
        collectionView.register(
            ProfileHistoryEmptyCell.self,
            forCellWithReuseIdentifier: ProfileHistoryEmptyCell.reuseIdentifier
        )
        collectionView.register(
            ProfileHistoryHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: ProfileHistoryHeaderView.reuseIdentifier
        )

        refreshControl.tintColor = HomeDesignColor.accent
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.state = state
            self.diamondLabel.text = "\(state.membership.diamonds)"
            self.diamondButton.accessibilityLabel = "Diamonds, \(state.membership.diamonds)"
            self.setLoading(state.isInitialLoading && state.tasks.isEmpty)
            if !state.isRefreshing {
                self.refreshControl.endRefreshing()
            }
            self.collectionView.reloadData()
            self.presentErrorIfNeeded(state.errorMessage)
        }
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    @objc private func handleRefresh() {
        viewModel.refresh()
    }

    @objc private func handleDiamondTap() {
        let container = AppRuntime.shared.container
        let controller = DiamondPurchaseViewController(
            viewModel: DiamondPurchaseViewModel(
                catalog: .configured,
                membershipHandler: container.membershipHandler,
                purchaseHandler: container.diamondPurchaseHandler,
                analytics: container.analytics
            )
        )
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    @objc private func handleSettingsTap() {
        let controller = SettingsViewController(
            purchaseHandler: AppRuntime.shared.container.membershipPurchaseHandler
        )
        navigationController?.pushViewController(controller, animated: true)
    }

    private func presentMembershipPaywall() {
        let container = AppRuntime.shared.container
        let controller = MembershipPaywallViewController(
            viewModel: MembershipPaywallViewModel(
                membershipHandler: container.membershipHandler,
                purchaseHandler: container.membershipPurchaseHandler,
                analytics: container.analytics
            )
        )
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private func presentResult(for task: HistoryTask) {
        guard let resultURL = task.resultURL else { return }
        let controller = GenerationResultViewController(
            template: task.template ?? Self.fallbackTemplate,
            resultURL: resultURL,
            contentType: task.result?.contentType
        )
        controller.onUseTemplateAgain = { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.openTemplateAgain(filterID: task.template?.id ?? 0, from: controller)
        }
        navigationController?.pushViewController(controller, animated: true)
    }

    private func openTemplateAgain(filterID: Int, from resultController: GenerationResultViewController) {
        guard filterID > 0 else {
            resultController.showToast(
                "This template is no longer available.",
                iconName: "exclamationmark.circle.fill",
                iconColor: UIColor(hex: 0xFF5A5F)
            )
            return
        }

        resultController.setTemplateActionLoading(true)
        Task { [weak self, weak resultController] in
            guard let self else { return }
            do {
                let cards = try await AppRuntime.shared.container.contentRepository.refreshAllCards()
                await MainActor.run {
                    guard let resultController else { return }
                    resultController.setTemplateActionLoading(false)
                    self.openCurrentTemplate(filterID: filterID, in: cards, from: resultController)
                }
            } catch {
                await MainActor.run {
                    resultController?.setTemplateActionLoading(false)
                    resultController?.showToast(
                        "Unable to check template availability. Please try again.",
                        iconName: "exclamationmark.circle.fill",
                        iconColor: UIColor(hex: 0xFF5A5F)
                    )
                }
            }
        }
    }

    private func openCurrentTemplate(
        filterID: Int,
        in cards: [ContentSection],
        from resultController: GenerationResultViewController
    ) {
        guard navigationController?.topViewController === resultController,
              let matched = cards.lazy.compactMap({ section -> (ContentSection, CreativeTemplate)? in
                  guard let template = section.templates.first(where: { $0.id == filterID }) else { return nil }
                  return (section, template)
              }).first else {
            resultController.showToast(
                "This template is no longer available.",
                iconName: "exclamationmark.circle.fill",
                iconColor: UIColor(hex: 0xFF5A5F)
            )
            return
        }

        let container = AppRuntime.shared.container
        let template = matched.1
        if template.kind.isFilterGenerationWorkflow {
            let controller = FilterGenerationViewController(
                initialTemplate: template,
                sourceSection: matched.0,
                contentRepository: container.contentRepository,
                membershipHandler: container.membershipHandler,
                generationRepository: container.generationRepository,
                generationWorkflowRunner: container.generationWorkflowRunner,
                analytics: container.analytics
            )
            navigationController?.pushViewController(controller, animated: true)
        } else if template.isTemplateVideoGenerationWorkflow {
            let controller = TemplateVideoGenerationViewController(
                template: template,
                membershipHandler: container.membershipHandler,
                generationRepository: container.generationRepository,
                generationWorkflowRunner: container.generationWorkflowRunner,
                analytics: container.analytics
            )
            navigationController?.pushViewController(controller, animated: true)
        } else {
            resultController.showToast(
                "This template is no longer available.",
                iconName: "exclamationmark.circle.fill",
                iconColor: UIColor(hex: 0xFF5A5F)
            )
        }
    }

    private static let fallbackTemplate = CreativeTemplate(
        id: 0,
        kind: .unknown,
        title: "Creation",
        summary: nil,
        coverURL: nil,
        alternateCoverURL: nil,
        operationCoverURLs: [],
        requiresMembership: false,
        storageChannel: nil,
        inputRequirement: nil,
        waitSeconds: 20,
        processingMessages: [],
        prompt: nil,
        usageCount: 0,
        diamondCost: 0,
        tint: nil,
        cardID: nil,
        maxInputImageCount: nil
    )
}

private extension CreativeTemplate {
    var isTemplateVideoGenerationWorkflow: Bool {
        switch kind {
        case .imageToVideo, .multiImageToVideo, .video:
            return true
        case .textToVideo, .videoEnhance, .filter, .hair, .cutout, .photo, .avatar, .outfit, .baby, .collection, .makeup, .textToImage, .imageToImage, .unknown:
            return false
        }
    }
}

private extension CreativeKind {
    var isFilterGenerationWorkflow: Bool {
        switch self {
        case .filter, .hair, .cutout, .photo, .outfit, .baby, .makeup, .avatar, .textToImage, .imageToImage:
            return true
        case .video, .textToVideo, .imageToVideo, .multiImageToVideo, .videoEnhance, .collection, .unknown:
            return false
        }
    }
}

extension ProfileViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return max(state.tasks.count, 1)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ProfileMembershipCardCell.reuseIdentifier,
                for: indexPath
            ) as! ProfileMembershipCardCell
            cell.configure(membership: state.membership)
            return cell
        }

        guard state.tasks.indices.contains(indexPath.item) else {
            return collectionView.dequeueReusableCell(
                withReuseIdentifier: ProfileHistoryEmptyCell.reuseIdentifier,
                for: indexPath
            )
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ProfileHistoryTaskCell.reuseIdentifier,
            for: indexPath
        ) as! ProfileHistoryTaskCell
        cell.configure(task: state.tasks[indexPath.item])
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ProfileHistoryHeaderView.reuseIdentifier,
            for: indexPath
        ) as! ProfileHistoryHeaderView
        return header
    }
}

extension ProfileViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = collectionView.bounds.width
        let horizontalInset: CGFloat = 28
        let itemSpacing: CGFloat = 16
        if indexPath.section == 0 {
            return CGSize(width: width - horizontalInset * 2, height: state.membership.isVIP ? 101 : 125)
        }
        if state.tasks.isEmpty {
            return CGSize(width: width - horizontalInset * 2, height: 390)
        }
        let itemWidth = floor((width - horizontalInset * 2 - itemSpacing) / 2)
        return CGSize(width: itemWidth, height: floor(itemWidth * (211 / 158)))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 28, bottom: section == 0 ? 0 : 28, right: 28)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        section == 0 ? 0 : 17
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        16
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        section == 1 ? CGSize(width: collectionView.bounds.width - 56, height: 58) : .zero
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if !state.membership.isVIP {
                presentMembershipPaywall()
            }
            return
        }

        guard state.tasks.indices.contains(indexPath.item) else { return }
        presentResult(for: state.tasks[indexPath.item])
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let remainingHeight = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height
        if remainingHeight < 180 {
            viewModel.loadMore()
        }
    }
}
