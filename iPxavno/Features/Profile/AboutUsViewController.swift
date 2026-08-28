import FirebaseAuth
import GoogleSignIn
import UIKit

final class AboutUsViewController: BaseViewController {
    private static let supportEmail = "hi@pixnova.ai"

    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private var deleteAccountTask: Task<Void, Never>?

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureView()
    }

    private func configureView() {
        view.backgroundColor = UIColor(hex: 0x050506)
        configureNavigation()
        configureContent()
    }

    private func configureNavigation() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = UIColor(hex: 0xF6F6F8)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold),
            forImageIn: .normal
        )
        backButton.accessibilityLabel = "Back"
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "About us"
        titleLabel.textColor = UIColor(hex: 0xF6F6F8)
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -62)
        ])
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = 0

        let logoContainer = makeLogoContainer()
        let appNameLabel = makeCenteredLabel(
            text: "PixnovaAI",
            color: UIColor(hex: 0xF6F6F8),
            font: UIFont.systemFont(ofSize: 24, weight: .bold)
        )
        let versionContainer = makeVersionContainer()
        let descriptionLabel = makeCenteredLabel(
            text: "Turn a single photo into trending looks and\nvideos. Made by the PixnovaAI team.",
            color: UIColor(hex: 0x9A9AA2),
            font: UIFont.systemFont(ofSize: 12.5, weight: .regular)
        )
        descriptionLabel.numberOfLines = 2

        let legalHeader = makeSectionHeader("LEGAL")
        let termsRow = AboutUsRowView(
            title: "Terms of Service",
            systemImageName: "doc",
            showsChevron: true,
            showsSeparator: true
        )
        let privacyRow = AboutUsRowView(
            title: "Privacy Policy",
            systemImageName: "doc",
            showsChevron: true,
            showsSeparator: true
        )
        let subscriptionTermsRow = AboutUsRowView(
            title: "Subscription Terms",
            systemImageName: "doc",
            showsChevron: true,
            showsSeparator: true
        )
        let contactRow = AboutUsRowView(
            title: "Contact support",
            systemImageName: "square.and.arrow.up",
            detail: Self.supportEmail
        )
        let accountHeader = makeSectionHeader("ACCOUNT")
        let deleteAccountRow = AboutUsRowView(
            title: "Delete account",
            systemImageName: "trash",
            titleColor: UIColor(hex: 0xFF6B6B),
            iconColor: UIColor(hex: 0xFF6B6B),
            subtitle: "Unlinks your account and continues as a guest"
        )
        let footerLabel = makeCenteredLabel(
            text: "© \(Self.currentYear) PixnovaAI\nv\(Self.appVersion) · build \(Self.buildNumber)",
            color: UIColor(hex: 0x56565C),
            font: UIFont.systemFont(ofSize: 10.5, weight: .regular)
        )
        footerLabel.numberOfLines = 2

        termsRow.onTap = { [weak self] in self?.openConfiguredURL(key: "TermsOfServiceURL") }
        privacyRow.onTap = { [weak self] in self?.openConfiguredURL(key: "PrivacyPolicyURL") }
        subscriptionTermsRow.onTap = { [weak self] in self?.openConfiguredURL(key: "SubscriptionTermsURL") }
        contactRow.onTap = { [weak self] in self?.composeSupportEmail() }
        deleteAccountRow.onTap = { [weak self] in self?.confirmAccountDeletion() }

        let arrangedSubviews: [UIView] = [
            makeSpacer(height: 26),
            logoContainer,
            makeSpacer(height: 18),
            appNameLabel,
            makeSpacer(height: 10),
            versionContainer,
            makeSpacer(height: 14),
            descriptionLabel,
            makeSpacer(height: 29),
            legalHeader,
            makeSpacer(height: 4),
            termsRow,
            privacyRow,
            subscriptionTermsRow,
            makeSpacer(height: 16),
            contactRow,
            makeSpacer(height: 24),
            accountHeader,
            makeSpacer(height: 4),
            deleteAccountRow,
            makeSpacer(height: 30),
            footerLabel,
            makeSpacer(height: 24)
        ]
        arrangedSubviews.forEach(contentStackView.addArrangedSubview)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            logoContainer.heightAnchor.constraint(equalToConstant: 74),
            appNameLabel.heightAnchor.constraint(equalToConstant: 29),
            versionContainer.heightAnchor.constraint(equalToConstant: 32),
            descriptionLabel.heightAnchor.constraint(equalToConstant: 42),
            legalHeader.heightAnchor.constraint(equalToConstant: 17),
            termsRow.heightAnchor.constraint(equalToConstant: 54),
            privacyRow.heightAnchor.constraint(equalToConstant: 54),
            subscriptionTermsRow.heightAnchor.constraint(equalToConstant: 54),
            contactRow.heightAnchor.constraint(equalToConstant: 58),
            accountHeader.heightAnchor.constraint(equalToConstant: 17),
            deleteAccountRow.heightAnchor.constraint(equalToConstant: 72),
            footerLabel.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func makeLogoContainer() -> UIView {
        let container = UIView()
        let logo = AboutUsLogoView()
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.layer.shadowColor = UIColor(hex: 0xC8FF35).cgColor
        logo.layer.shadowOpacity = 0.30
        logo.layer.shadowRadius = 20
        logo.layer.shadowOffset = .zero
        container.addSubview(logo)
        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 74),
            logo.heightAnchor.constraint(equalToConstant: 74)
        ])
        return container
    }

    private func makeVersionContainer() -> UIView {
        let container = UIView()
        let pill = UIView()
        let label = UILabel()

        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        pill.layer.cornerRadius = 16
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Version \(Self.appVersion) (\(Self.buildNumber))"
        label.textColor = UIColor(hex: 0x9A9AA2)
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center

        container.addSubview(pill)
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            pill.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
            pill.heightAnchor.constraint(equalToConstant: 32),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])
        return container
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 10.5, weight: .semibold),
                .foregroundColor: UIColor(hex: 0x56565C),
                .kern: 1.26
            ]
        )
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func makeCenteredLabel(text: String, color: UIColor, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = font
        label.textAlignment = .center
        return label
    }

    private func makeSpacer(height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func openConfiguredURL(key: String) {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: rawValue) else { return }
        UIApplication.shared.open(url)
    }

    private func composeSupportEmail(subject: String? = nil) {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.supportEmail
        if let subject {
            components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        }
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private func confirmAccountDeletion() {
        let alert = UIAlertController(
            title: "Delete account?",
            message: "Your account will be unlinked from this device and you will continue as a guest.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteAccount()
        })
        present(alert, animated: true)
    }

    private func deleteAccount() {
        guard deleteAccountTask == nil else { return }
        let container = AppRuntime.shared.container
        deleteAccountTask = Task { [weak self] in
            guard let self else { return }
            self.setLoading(true)
            do {
                let account = try await container.accountRepository.removeThirdPartyBindings(
                    fallbackPlatform: Self.currentFirebasePlatform
                )
                guard !account.hasLinkedAccount else {
                    throw AppError.server(
                        message: "The account could not be deleted. Please try again.",
                        code: -1
                    )
                }

                try? Auth.auth().signOut()
                GIDSignIn.sharedInstance.signOut()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.returnToHomeAsGuest()
            } catch {
                self.setLoading(false)
                self.showError(error.localizedDescription)
            }
            self.deleteAccountTask = nil
        }
    }

    private func returnToHomeAsGuest() {
        if let mainController = navigationController?.parent as? MainTabBarController {
            mainController.showHomeAfterSignOut()
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
    }

    private static var currentFirebasePlatform: String? {
        Auth.auth().currentUser?.providerData.lazy.compactMap { provider in
            switch provider.providerID {
            case "google.com": return "google"
            case "apple.com": return "apple"
            default: return nil
            }
        }.first
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private static var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
}

private final class AboutUsLogoView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let sparkImageView = UIImageView(image: UIImage(named: "login-logo-spark"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor(hex: 0xC8FF35).cgColor,
            UIColor(hex: 0x9DDB1F).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 22
        layer.insertSublayer(gradientLayer, at: 0)

        sparkImageView.translatesAutoresizingMaskIntoConstraints = false
        sparkImageView.contentMode = .scaleAspectFit
        addSubview(sparkImageView)
        NSLayoutConstraint.activate([
            sparkImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sparkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sparkImageView.widthAnchor.constraint(equalToConstant: 38),
            sparkImageView.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private final class AboutUsRowView: UIControl {
    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let separatorView = UIView()

    init(
        title: String,
        systemImageName: String,
        titleColor: UIColor = UIColor(hex: 0xF6F6F8),
        iconColor: UIColor = UIColor(hex: 0x9A9AA2),
        detail: String? = nil,
        subtitle: String? = nil,
        showsChevron: Bool = false,
        showsSeparator: Bool = false
    ) {
        super.init(frame: .zero)
        iconView.image = UIImage(systemName: systemImageName)
        iconView.tintColor = iconColor
        titleLabel.text = title
        titleLabel.textColor = titleColor
        subtitleLabel.text = subtitle
        detailLabel.text = detail
        chevronView.isHidden = !showsChevron
        separatorView.isHidden = !showsSeparator
        configureView(hasSubtitle: subtitle != nil)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        accessibilityLabel = [title, subtitle, detail].compactMap { $0 }.joined(separator: ", ")
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.55 : 1 }
    }

    private func configureView(hasSubtitle: Bool) {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = UIColor(hex: 0x9A9AA2)
        subtitleLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .regular)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.8

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.textColor = UIColor(hex: 0x56565C)
        detailLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        detailLabel.textAlignment = .right

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = UIColor(hex: 0x56565C)
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = UIColor.white.withAlphaComponent(0.09)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(detailLabel)
        addSubview(chevronView)
        addSubview(separatorView)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 51),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: detailLabel.leadingAnchor, constant: -12),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            detailLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 15),
            chevronView.heightAnchor.constraint(equalToConstant: 15),

            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        if hasSubtitle {
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 13),
                subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4)
            ])
        } else {
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
    }

    @objc private func handleTap() {
        onTap?()
    }
}
