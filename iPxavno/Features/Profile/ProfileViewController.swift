import UIKit

final class ProfileViewController: BaseViewController {
    private let viewModel: ProfileViewModel
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let userIDValueLabel = UILabel()
    private let creditValueLabel = UILabel()
    private let videoValueLabel = UILabel()
    private let membershipLabel = UILabel()
    private let invitationLabel = UILabel()
    private let stackView = UIStackView()

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Me"
        configureView()
        bindViewModel()
        viewModel.load()
    }

    private func configureView() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = AppTheme.Font.title
        nameLabel.textColor = AppTheme.Color.ink

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = AppTheme.Font.body
        subtitleLabel.textColor = AppTheme.Color.secondaryInk

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12

        view.addSubview(nameLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(stackView)

        stackView.addArrangedSubview(makeMetricRow(title: "User ID", valueLabel: userIDValueLabel))
        stackView.addArrangedSubview(makeMetricRow(title: "Credits", valueLabel: creditValueLabel))
        stackView.addArrangedSubview(makeMetricRow(title: "Video Credits", valueLabel: videoValueLabel))
        stackView.addArrangedSubview(makeMetricRow(title: "Membership", valueLabel: membershipLabel))
        stackView.addArrangedSubview(makeMetricRow(title: "Invite Code", valueLabel: invitationLabel))
        stackView.addArrangedSubview(makeNavigationRow(title: "Creation History"))
        stackView.addArrangedSubview(makeNavigationRow(title: "Rewards"))
        stackView.addArrangedSubview(makeNavigationRow(title: "Restore Purchases"))

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metric.screenInset),
            nameLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metric.screenInset),
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),

            stackView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            self?.setLoading(state.isLoading)
            self?.nameLabel.text = state.displayName
            self?.subtitleLabel.text = state.subtitle
            self?.userIDValueLabel.text = state.userID
            self?.creditValueLabel.text = state.diamonds
            self?.videoValueLabel.text = state.videoCredits
            self?.membershipLabel.text = state.membership
            self?.invitationLabel.text = state.inviteState
        }
    }

    private func makeMetricRow(title: String, valueLabel: UILabel) -> UIView {
        let row = makeRowContainer()
        let titleLabel = makeRowTitle(title)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = AppTheme.Font.headline
        valueLabel.textColor = AppTheme.Color.accentDark
        valueLabel.textAlignment = .right

        row.addSubview(titleLabel)
        row.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeNavigationRow(title: String) -> UIView {
        let row = makeRowContainer()
        let titleLabel = makeRowTitle(title)
        let icon = UIImageView(image: UIImage(systemName: "chevron.right"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = AppTheme.Color.secondaryInk

        row.addSubview(titleLabel)
        row.addSubview(icon)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            icon.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            icon.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeRowContainer() -> UIView {
        let row = UIView()
        row.backgroundColor = AppTheme.Color.surface
        row.layer.cornerRadius = AppTheme.Metric.cornerRadius
        row.layer.borderColor = AppTheme.Color.line.cgColor
        row.layer.borderWidth = 1
        row.heightAnchor.constraint(equalToConstant: 58).isActive = true
        return row
    }

    private func makeRowTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = AppTheme.Font.body
        label.textColor = AppTheme.Color.ink
        label.text = text
        return label
    }
}
