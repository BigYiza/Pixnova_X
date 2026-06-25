import UIKit

final class HomeMosaicCell: UICollectionViewCell {
    static let reuseIdentifier = "HomeMosaicCell"

    private let featuredCard = HomeTemplatePreviewView()
    private let smallCards = (0..<4).map { _ in HomeTemplatePreviewView() }
    private let rightGrid = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        featuredCard.prepareForReuse()
        smallCards.forEach { $0.prepareForReuse() }
    }

    func configure(templates: [CreativeTemplate]) {
        featuredCard.configure(template: templates.first, style: .featured, showsHotBadge: true)

        for index in smallCards.indices {
            let templateIndex = index + 1
            smallCards[index].configure(
                template: templates.indices.contains(templateIndex) ? templates[templateIndex] : nil,
                style: .compact,
                showsHotBadge: false
            )
        }
    }

    private func configureView() {
        contentView.backgroundColor = .clear

        featuredCard.translatesAutoresizingMaskIntoConstraints = false
        rightGrid.translatesAutoresizingMaskIntoConstraints = false
        rightGrid.axis = .vertical
        rightGrid.distribution = .fillEqually
        rightGrid.spacing = 12

        let topRow = makeSmallRow(cards: Array(smallCards[0...1]))
        let bottomRow = makeSmallRow(cards: Array(smallCards[2...3]))
        rightGrid.addArrangedSubview(topRow)
        rightGrid.addArrangedSubview(bottomRow)

        contentView.addSubview(featuredCard)
        contentView.addSubview(rightGrid)

        NSLayoutConstraint.activate([
            featuredCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            featuredCard.topAnchor.constraint(equalTo: contentView.topAnchor),
            featuredCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            featuredCard.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.49),

            rightGrid.leadingAnchor.constraint(equalTo: featuredCard.trailingAnchor, constant: 12),
            rightGrid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightGrid.topAnchor.constraint(equalTo: contentView.topAnchor),
            rightGrid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func makeSmallRow(cards: [HomeTemplatePreviewView]) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: cards)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        return stackView
    }
}

final class HomeTemplateCardCell: UICollectionViewCell {
    static let reuseIdentifier = "HomeTemplateCardCell"

    private let previewView = HomeTemplatePreviewView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewView.prepareForReuse()
    }

    func configure(template: CreativeTemplate, showsHotBadge: Bool) {
        previewView.configure(template: template, style: .regular, showsHotBadge: showsHotBadge)
    }
}

final class HomeSectionHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "HomeSectionHeaderView"

    var onAllTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let allLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let actionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onAllTap = nil
    }

    func configure(title: String) {
        titleLabel.text = title.uppercased()
    }

    @objc private func handleAllTap() {
        onAllTap?()
    }

    private func configureView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.numberOfLines = 1

        allLabel.translatesAutoresizingMaskIntoConstraints = false
        allLabel.text = "All"
        allLabel.font = UIFont.systemFont(ofSize: 16.3, weight: .semibold)
        allLabel.textColor = HomeDesignColor.accent

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = HomeDesignColor.accent
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.backgroundColor = .clear
        actionButton.addTarget(self, action: #selector(handleAllTap), for: .touchUpInside)

        addSubview(titleLabel)
        addSubview(allLabel)
        addSubview(chevron)
        addSubview(actionButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: allLabel.leadingAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            chevron.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 14),

            allLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            allLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            actionButton.leadingAnchor.constraint(equalTo: allLabel.leadingAnchor, constant: -16),
            actionButton.trailingAnchor.constraint(equalTo: chevron.trailingAnchor, constant: 16),
            actionButton.topAnchor.constraint(equalTo: topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private enum HomePreviewStyle {
    case featured
    case regular
    case compact

    var cornerRadius: CGFloat {
        switch self {
        case .featured:
            return 25
        case .regular:
            return 20
        case .compact:
            return 18
        }
    }

    var titleFont: UIFont {
        switch self {
        case .featured:
            return UIFont.systemFont(ofSize: 17, weight: .semibold)
        case .regular:
            return UIFont.systemFont(ofSize: 14, weight: .medium)
        case .compact:
            return UIFont.systemFont(ofSize: 12, weight: .medium)
        }
    }

    var showsTitle: Bool {
        self != .compact
    }
}

private final class HomeTemplatePreviewView: UIView {
    private let imageView = RemoteImageView()
    private let gradientView = GradientOverlayView()
    private let hotBadge = UILabel()
    private let titleLabel = UILabel()
    private let vipBadgeView = UIView()
    private let vipIcon = UIImageView(image: UIImage(systemName: "crown"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func prepareForReuse() {
        imageView.image = nil
        titleLabel.text = nil
        hotBadge.isHidden = true
        vipBadgeView.isHidden = true
    }

    func configure(template: CreativeTemplate?, style: HomePreviewStyle, showsHotBadge: Bool) {
        layer.cornerRadius = style.cornerRadius
        imageView.layer.cornerRadius = style.cornerRadius
        titleLabel.font = style.titleFont
        titleLabel.isHidden = !style.showsTitle
        titleLabel.text = template?.title
        // hotBadge.isHidden = !showsHotBadge
        vipBadgeView.isHidden = template?.requiresMembership != true

        if let coverURL = template?.preferredImageURL {
            imageView.setImage(url: coverURL, placeholder: nil)
        } else {
            imageView.setImage(url: nil, placeholder: nil)
        }
    }

    private func configureView() {
        backgroundColor = HomeDesignColor.card
        clipsToBounds = true
        layer.borderWidth = 1.2
        layer.borderColor = HomeDesignColor.border.cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        hotBadge.translatesAutoresizingMaskIntoConstraints = false
        hotBadge.text = "HOT"
        hotBadge.font = UIFont.systemFont(ofSize: 12.7, weight: .heavy)
        hotBadge.textColor = HomeDesignColor.blackText
        hotBadge.textAlignment = .center
        hotBadge.backgroundColor = HomeDesignColor.accent
        hotBadge.layer.cornerRadius = 10
        hotBadge.clipsToBounds = true
        hotBadge.isHidden = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        vipBadgeView.translatesAutoresizingMaskIntoConstraints = false
        vipBadgeView.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        vipBadgeView.layer.cornerRadius = 14.1
        vipBadgeView.clipsToBounds = true
        vipBadgeView.isHidden = true

        vipIcon.translatesAutoresizingMaskIntoConstraints = false
        vipIcon.tintColor = .white
        vipIcon.contentMode = .scaleAspectFit
        vipIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)

        addSubview(imageView)
        addSubview(gradientView)
        addSubview(hotBadge)
        addSubview(titleLabel)
        addSubview(vipBadgeView)
        vipBadgeView.addSubview(vipIcon)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: bottomAnchor),

            hotBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            hotBadge.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            hotBadge.widthAnchor.constraint(equalToConstant: 52),
            hotBadge.heightAnchor.constraint(equalToConstant: 29),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -17),

            vipBadgeView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            vipBadgeView.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            vipBadgeView.widthAnchor.constraint(equalToConstant: 28),
            vipBadgeView.heightAnchor.constraint(equalToConstant: 28),

            vipIcon.centerXAnchor.constraint(equalTo: vipBadgeView.centerXAnchor),
            vipIcon.centerYAnchor.constraint(equalTo: vipBadgeView.centerYAnchor),
            vipIcon.widthAnchor.constraint(equalToConstant: 14),
            vipIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
    }
}

private final class GradientOverlayView: UIView {
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
