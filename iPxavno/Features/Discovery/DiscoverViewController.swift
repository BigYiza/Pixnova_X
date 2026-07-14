import UIKit

final class DiscoverViewController: BaseViewController {
    private let viewModel: DiscoverViewModel
    private var sections: [HomeContentSection] = []
    private var displayedErrorMessage: String?
    private let topBarView = HomeTopBarView()
    private let refreshControl = UIRefreshControl()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())

    init(viewModel: DiscoverViewModel) {
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
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = HomeDesignColor.background
        collectionView.showsVerticalScrollIndicator = false
        collectionView.refreshControl = refreshControl
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(HomeMosaicCell.self, forCellWithReuseIdentifier: HomeMosaicCell.reuseIdentifier)
        collectionView.register(HomeTemplateCardCell.self, forCellWithReuseIdentifier: HomeTemplateCardCell.reuseIdentifier)
        collectionView.register(
            HomeSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: HomeSectionHeaderView.reuseIdentifier
        )

        refreshControl.tintColor = HomeDesignColor.accent
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        topBarView.onMembershipTap = { [weak self] in
            self?.presentMembershipPaywall()
        }

        view.addSubview(topBarView)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.topAnchor.constraint(equalTo: view.topAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 120),

            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.setLoading(state.isLoading)
            if !state.isLoading {
                self.refreshControl.endRefreshing()
            }
            self.topBarView.configure(membership: self.viewModel.currentMembershipState)
            self.sections = state.sections
            self.collectionView.reloadData()
            self.presentErrorIfNeeded(state.errorMessage)
        }
    }

    @objc private func handleRefresh() {
        viewModel.load()
    }

    private func presentMembershipPaywall() {
        let viewController = viewModel.makeMembershipPaywallViewController()
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self, self.sections.indices.contains(sectionIndex) else { return nil }
            let sectionModel = self.sections[sectionIndex]

            switch sectionModel.kind {
            case .mosaic:
                return self.makeMosaicSection()
            case let .horizontal(style):
                return self.makeHorizontalSection(style: style)
            case let .doubleLine(style):
                return self.makeDoubleLineSection(style: style)
            }
        }
    }

    private func makeMosaicSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(201))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 28, bottom: 26, trailing: 28)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    private func makeHorizontalSection(style: HomeCardStyle) -> NSCollectionLayoutSection {
        let size = style.itemSize
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(size.height))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(size.height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 20, bottom: 28, trailing: 20)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    private func makeDoubleLineSection(style: HomeCardStyle) -> NSCollectionLayoutSection {
        let size = style.itemSize
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(size.height))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 9, trailing: 0)

        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(size.width), heightDimension: .absolute(style.sectionHeight))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, repeatingSubitem: item, count: 2)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 9
        section.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 20, bottom: 28, trailing: 20)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    private func makeHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(52))
        return NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}

extension DiscoverViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].kind.isMosaic ? 1 : sections[section].templates.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let section = sections[indexPath.section]

        switch section.kind {
        case .mosaic:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeMosaicCell.reuseIdentifier,
                for: indexPath
            ) as? HomeMosaicCell
            cell?.configure(templates: section.templates)
            return cell ?? UICollectionViewCell()
        case .horizontal, .doubleLine:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeTemplateCardCell.reuseIdentifier,
                for: indexPath
            ) as? HomeTemplateCardCell
            cell?.configure(template: section.templates[indexPath.item], showsHotBadge: indexPath.item == 0)
            return cell ?? UICollectionViewCell()
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: HomeSectionHeaderView.reuseIdentifier,
            for: indexPath
        ) as? HomeSectionHeaderView
        header?.configure(title: sections[indexPath.section].title)
        header?.onAllTap = { [weak self] in
            guard let self, self.sections.indices.contains(indexPath.section) else { return }
            let listViewModel = self.viewModel.makeCategoryTemplateListViewModel(
                for: self.sections[indexPath.section].source
            )
            let listViewController = CategoryTemplateListViewController(viewModel: listViewModel)
            self.navigationController?.pushViewController(listViewController, animated: true)
        }
        return header ?? UICollectionReusableView()
    }
}

extension DiscoverViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section = sections[indexPath.section]

        switch section.kind {
        case .mosaic:
            if let template = section.templates.first {
                openTemplate(template, sourceSection: section.source)
            }
        case .horizontal, .doubleLine:
            openTemplate(section.templates[indexPath.item], sourceSection: section.source)
        }
    }

    private func openTemplate(_ template: CreativeTemplate, sourceSection: ContentSection) {
        viewModel.didSelectTemplate(template)
        if template.kind.isFilterGenerationWorkflow {
            let viewController = viewModel.makeFilterGenerationViewController(
                for: template,
                sourceSection: sourceSection
            )
            navigationController?.pushViewController(viewController, animated: true)
        } else if template.isTemplateVideoGenerationWorkflow {
            let viewController = viewModel.makeTemplateVideoGenerationViewController(for: template)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
}

private extension HomeSectionKind {
    var isMosaic: Bool {
        if case .mosaic = self {
            return true
        }
        return false
    }
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
