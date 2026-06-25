import UIKit

enum CreationHubMode {
    case video
    case filters
    case photo

    var title: String {
        switch self {
        case .video:
            return "Video"
        case .filters:
            return "Filters"
        case .photo:
            return "Photo"
        }
    }
}

final class CreationHubViewController: BaseViewController {
    private let mode: CreationHubMode
    private let viewModel: CreationHubViewModel
    private var sections: [ContentSection] = []
    private var displayedErrorMessage: String?
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())

    init(mode: CreationHubMode, viewModel: CreationHubViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = mode.title
        navigationController?.navigationBar.prefersLargeTitles = false
        configureView()
        bindViewModel()
        viewModel.load()
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = HomeDesignColor.background
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CreationTemplateCell.self, forCellWithReuseIdentifier: CreationTemplateCell.reuseIdentifier)
        collectionView.register(
            CreationSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: CreationSectionHeaderView.reuseIdentifier
        )
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            self?.setLoading(state.isLoading)
            self?.sections = state.sections
            self?.collectionView.reloadData()
            self?.presentErrorIfNeeded(state.errorMessage)
        }
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .absolute(184))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(184))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 2)

            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 22, bottom: 24, trailing: 22)
            section.interGroupSpacing = 12

            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(48))
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            return section
        }
    }
}

extension CreationHubViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].templates.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CreationTemplateCell.reuseIdentifier,
            for: indexPath
        ) as? CreationTemplateCell
        cell?.configure(template: sections[indexPath.section].templates[indexPath.item])
        return cell ?? UICollectionViewCell()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: CreationSectionHeaderView.reuseIdentifier,
            for: indexPath
        ) as? CreationSectionHeaderView
        header?.configure(title: sections[indexPath.section].title)
        return header ?? UICollectionReusableView()
    }
}

extension CreationHubViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.didSelectTemplate(sections[indexPath.section].templates[indexPath.item])
    }
}

private final class CreationTemplateCell: UICollectionViewCell {
    static let reuseIdentifier = "CreationTemplateCell"

    private let imageView = RemoteImageView()
    private let gradientView = CreationGradientView()
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()

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
    }

    func configure(template: CreativeTemplate) {
        titleLabel.text = template.title
        badgeLabel.text = template.requiresMembership ? "VIP" : label(for: template.kind)
        imageView.setImage(url: template.preferredImageURL, placeholder: nil)
    }

    private func configureView() {
        contentView.backgroundColor = HomeDesignColor.card
        contentView.layer.cornerRadius = 20
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = HomeDesignColor.border.cgColor
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.textColor = HomeDesignColor.blackText
        badgeLabel.backgroundColor = HomeDesignColor.accent
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.clipsToBounds = true

        contentView.addSubview(imageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(badgeLabel)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badgeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            badgeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            badgeLabel.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14)
        ])
    }

    private func label(for kind: CreativeKind) -> String {
        switch kind {
        case .textToVideo, .imageToVideo, .multiImageToVideo, .video, .videoEnhance:
            return "VIDEO"
        case .textToImage, .imageToImage, .photo:
            return "PHOTO"
        default:
            return "AI"
        }
    }
}

private final class CreationSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "CreationSectionHeaderView"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = HomeDesignColor.text
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }
}

private final class CreationGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.68).cgColor
        ]
        gradientLayer.locations = [0.45, 1]
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
