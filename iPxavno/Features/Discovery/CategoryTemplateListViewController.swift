import UIKit

final class CategoryTemplateListViewController: BaseViewController {
    private let viewModel: CategoryTemplateListViewModel
    private var cards: [ContentSection] = []
    private var selectedIndex = 0
    private var displayedErrorMessage: String?
    private var pendingSegmentScrollIndex: Int?

    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private lazy var segmentCollectionView = UICollectionView(frame: .zero, collectionViewLayout: makeSegmentLayout())
    private lazy var templateCollectionView = UICollectionView(frame: .zero, collectionViewLayout: makeTemplateLayout())

    init(viewModel: CategoryTemplateListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureView()
        bindViewModel()
        viewModel.load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollSelectedSegmentIntoView(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard pendingSegmentScrollIndex != nil else { return }
        scrollSelectedSegmentIntoView(animated: false)
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = HomeDesignColor.text
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold),
            forImageIn: .normal
        )
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.textAlignment = .center

        segmentCollectionView.translatesAutoresizingMaskIntoConstraints = false
        segmentCollectionView.backgroundColor = HomeDesignColor.background
        segmentCollectionView.showsHorizontalScrollIndicator = false
        segmentCollectionView.dataSource = self
        segmentCollectionView.delegate = self
        segmentCollectionView.register(CategorySegmentCell.self, forCellWithReuseIdentifier: CategorySegmentCell.reuseIdentifier)

        templateCollectionView.translatesAutoresizingMaskIntoConstraints = false
        templateCollectionView.backgroundColor = HomeDesignColor.background
        templateCollectionView.showsVerticalScrollIndicator = false
        templateCollectionView.dataSource = self
        templateCollectionView.delegate = self
        templateCollectionView.register(CategoryTemplateCell.self, forCellWithReuseIdentifier: CategoryTemplateCell.reuseIdentifier)

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(segmentCollectionView)
        view.addSubview(templateCollectionView)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 42),
            backButton.heightAnchor.constraint(equalToConstant: 42),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -80),

            segmentCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentCollectionView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            segmentCollectionView.heightAnchor.constraint(equalToConstant: 58),

            templateCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            templateCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            templateCollectionView.topAnchor.constraint(equalTo: segmentCollectionView.bottomAnchor, constant: 10),
            templateCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.setLoading(state.isLoading)
            self.titleLabel.text = state.title
            self.cards = state.cards
            self.selectedIndex = state.selectedIndex
            self.pendingSegmentScrollIndex = state.selectedIndex
            self.segmentCollectionView.reloadData()
            self.templateCollectionView.reloadData()
            self.scheduleSelectedSegmentScroll()
            self.presentErrorIfNeeded(state.errorMessage)
        }
    }

    private func makeSegmentLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        return layout
    }

    private func makeTemplateLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let horizontalInset: CGFloat = 28
            let spacing: CGFloat = 16
            let availableWidth = environment.container.effectiveContentSize.width - horizontalInset * 2 - spacing
            let itemWidth = floor(availableWidth / 2)
            let itemHeight = itemWidth * 211 / 158

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 17
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: horizontalInset, bottom: 40, trailing: horizontalInset)
            return section
        }
    }

    private func scheduleSelectedSegmentScroll() {
        DispatchQueue.main.async { [weak self] in
            self?.scrollSelectedSegmentIntoView(animated: false)
        }
    }

    private func scrollSelectedSegmentIntoView(animated: Bool) {
        let targetIndex = pendingSegmentScrollIndex ?? selectedIndex
        guard cards.indices.contains(targetIndex),
              segmentCollectionView.numberOfItems(inSection: 0) > targetIndex else {
            return
        }

        segmentCollectionView.layoutIfNeeded()
        segmentCollectionView.scrollToItem(
            at: IndexPath(item: targetIndex, section: 0),
            at: .centeredHorizontally,
            animated: animated
        )
        pendingSegmentScrollIndex = nil
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }
}

extension CategoryTemplateListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === segmentCollectionView {
            return cards.count
        }
        return cards.indices.contains(selectedIndex) ? cards[selectedIndex].templates.count : 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView === segmentCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CategorySegmentCell.reuseIdentifier,
                for: indexPath
            ) as? CategorySegmentCell
            cell?.configure(title: cards[indexPath.item].title, isSelected: indexPath.item == selectedIndex)
            return cell ?? UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryTemplateCell.reuseIdentifier,
            for: indexPath
        ) as? CategoryTemplateCell
        cell?.configure(template: cards[selectedIndex].templates[indexPath.item])
        return cell ?? UICollectionViewCell()
    }
}

extension CategoryTemplateListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === segmentCollectionView {
            viewModel.selectCard(at: indexPath.item)
            pendingSegmentScrollIndex = indexPath.item
            scrollSelectedSegmentIntoView(animated: true)
            templateCollectionView.setContentOffset(.zero, animated: false)
            return
        }

        guard cards.indices.contains(selectedIndex),
              cards[selectedIndex].templates.indices.contains(indexPath.item) else {
            return
        }
        viewModel.didSelectTemplate(cards[selectedIndex].templates[indexPath.item])
    }
}

extension CategoryTemplateListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard collectionView === segmentCollectionView else { return .zero }
        let title = cards[indexPath.item].title as NSString
        let font = UIFont.systemFont(ofSize: 19.8, weight: indexPath.item == selectedIndex ? .bold : .semibold)
        let width = ceil(title.size(withAttributes: [.font: font]).width) + 26
        return CGSize(width: max(58, width), height: 58)
    }
}

private final class CategorySegmentCell: UICollectionViewCell {
    static let reuseIdentifier = "CategorySegmentCell"

    private let titleLabel = UILabel()
    private let indicatorView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 19.8, weight: isSelected ? .bold : .semibold)
        titleLabel.textColor = isSelected ? HomeDesignColor.text : UIColor(hex: 0x56565C)
        indicatorView.isHidden = !isSelected
    }

    private func configureView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.backgroundColor = HomeDesignColor.accent
        indicatorView.layer.cornerRadius = 1.5
        indicatorView.isHidden = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            titleLabel.heightAnchor.constraint(equalToConstant: 32),

            indicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            indicatorView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            indicatorView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
}

private final class CategoryTemplateCell: UICollectionViewCell {
    static let reuseIdentifier = "CategoryTemplateCell"

    private let imageView = RemoteImageView()
    private let gradientView = CategoryTemplateGradientView()
    private let titleLabel = UILabel()
    private let badgeView = UIView()
    private let badgeIcon = UIImageView(image: UIImage(systemName: "crown"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
    }

    func configure(template: CreativeTemplate) {
        titleLabel.text = template.title
        badgeView.isHidden = !template.requiresMembership
        imageView.setImage(url: template.preferredImageURL, placeholder: nil)
    }

    private func configureView() {
        contentView.backgroundColor = HomeDesignColor.card
        contentView.layer.cornerRadius = 20
        contentView.layer.borderWidth = 1.4
        contentView.layer.borderColor = HomeDesignColor.border.cgColor
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        badgeView.layer.cornerRadius = 14.1
        badgeView.clipsToBounds = true

        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badgeIcon.tintColor = .white
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)

        contentView.addSubview(imageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(badgeView)
        badgeView.addSubview(badgeIcon)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badgeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            badgeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            badgeView.widthAnchor.constraint(equalToConstant: 28),
            badgeView.heightAnchor.constraint(equalToConstant: 28),

            badgeIcon.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 14),
            badgeIcon.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -13),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -17)
        ])
    }
}

private final class CategoryTemplateGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.66).cgColor
        ]
        gradientLayer.locations = [0, 0.52, 1]
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
