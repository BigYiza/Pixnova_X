import UIKit

final class OnboardingViewController: BaseViewController {
    var onFinish: (() -> Void)?

    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let stackView = UIStackView()
    private let continueButton = PrimaryButton(title: "Start Creating")

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "A focused workspace for visual ideas"
        titleLabel.font = AppTheme.Font.largeTitle
        titleLabel.textColor = AppTheme.Color.ink
        titleLabel.numberOfLines = 0

        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = "Explore templates, generate images and videos, and keep your creation history in one place."
        bodyLabel.font = AppTheme.Font.body
        bodyLabel.textColor = AppTheme.Color.secondaryInk
        bodyLabel.numberOfLines = 0

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12
        ["Template-driven creation", "Membership and credit-aware flows", "History, rewards, and account recovery ready"].forEach {
            stackView.addArrangedSubview(makePointLabel($0))
        }

        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(didTapContinue), for: .touchUpInside)

        view.addSubview(titleLabel)
        view.addSubview(bodyLabel)
        view.addSubview(stackView)
        view.addSubview(continueButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Metric.screenInset),
            titleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Metric.screenInset),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 72),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 18),

            stackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 36),

            continueButton.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    private func makePointLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = AppTheme.Color.ink
        label.font = AppTheme.Font.headline
        label.numberOfLines = 0
        return label
    }

    @objc private func didTapContinue() {
        onFinish?()
    }
}
