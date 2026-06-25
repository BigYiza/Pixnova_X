import UIKit

final class HomeTopBarView: UIView {
    private let titleLabel = UILabel()
    private let vipPill = HomeStatusPill()
    private let diamondPill = HomeStatusPill()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(membership: HomeMembershipState) {
        vipPill.configure(
            iconName: "crown",
            text: membership.isVIP ? "VIP" : "VIP",
            foregroundColor: HomeDesignColor.text,
            backgroundColor: UIColor.white.withAlphaComponent(0.07),
            borderColor: UIColor.white.withAlphaComponent(0.09)
        )
        diamondPill.configure(
            iconName: "suit.diamond.fill",
            text: "\(membership.diamonds)",
            foregroundColor: HomeDesignColor.blackText,
            backgroundColor: HomeDesignColor.accent,
            borderColor: .clear
        )
    }

    private func configureView() {
        backgroundColor = HomeDesignColor.background

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "PixnovaAI"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        vipPill.translatesAutoresizingMaskIntoConstraints = false
        diamondPill.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(vipPill)
        addSubview(diamondPill)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 150),

            vipPill.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10),
            vipPill.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            vipPill.widthAnchor.constraint(equalToConstant: 82),
            vipPill.heightAnchor.constraint(equalToConstant: 45),

            diamondPill.leadingAnchor.constraint(equalTo: vipPill.trailingAnchor, constant: 11),
            diamondPill.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            diamondPill.centerYAnchor.constraint(equalTo: vipPill.centerYAnchor),
            diamondPill.widthAnchor.constraint(equalToConstant: 90),
            diamondPill.heightAnchor.constraint(equalToConstant: 45)
        ])
    }
}

private final class HomeStatusPill: UIView {
    private let iconView = UIImageView()
    private let valueLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(iconName: String, text: String, foregroundColor: UIColor, backgroundColor: UIColor, borderColor: UIColor) {
        self.backgroundColor = backgroundColor
        layer.borderColor = borderColor.cgColor
        iconView.image = UIImage(systemName: iconName)?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = foregroundColor
        valueLabel.text = text
        valueLabel.textColor = foregroundColor
    }

    private func configureView() {
        layer.cornerRadius = 22.5
        layer.borderWidth = 1
        clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        addSubview(iconView)
        addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            valueLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
