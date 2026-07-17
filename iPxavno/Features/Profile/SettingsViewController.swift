import UIKit

final class SettingsViewController: BaseViewController {
    private let purchaseHandler: MembershipPurchaseHandling
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let toastView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let toastLabel = UILabel()
    private var restoreTask: Task<Void, Never>?

    init(purchaseHandler: MembershipPurchaseHandling) {
        self.purchaseHandler = purchaseHandler
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
        view.backgroundColor = HomeDesignColor.background
        configureNavigation()
        configureContent()
        configureToast()
    }

    private func configureNavigation() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = HomeDesignColor.text
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold),
            forImageIn: .normal
        )
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Settings"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center

        view.addSubview(backButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -76)
        ])
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = 0

        let subscriptionHeader = makeSectionHeader("SUBSCRIPTION")
        let manageSubscriptionRow = SettingsRowView(
            title: "Manage subscription",
            iconName: "crown"
        )
        let restorePurchasesRow = SettingsRowView(
            title: "Restore purchases",
            iconName: "arrow.counterclockwise"
        )
        let legalHeader = makeSectionHeader("LEGAL")
        let privacyRow = SettingsRowView(title: "Privacy Policy", iconName: "doc")
        let agreementRow = SettingsRowView(title: "User Agreement", iconName: "doc")
        let subscriptionTermsRow = SettingsRowView(title: "Subscription Terms", iconName: "doc")
        let contactRow = SettingsRowView(title: "Contact us", iconName: "square.and.arrow.up")
        let versionLabel = UILabel()

        manageSubscriptionRow.onTap = { [weak self] in self?.openSubscriptionManagement() }
        restorePurchasesRow.onTap = { [weak self] in self?.restorePurchases() }
        privacyRow.onTap = { [weak self] in self?.openConfiguredURL(key: "PrivacyPolicyURL") }
        agreementRow.onTap = { [weak self] in self?.openConfiguredURL(key: "UserAgreementURL") }
        subscriptionTermsRow.onTap = { [weak self] in self?.openConfiguredURL(key: "SubscriptionTermsURL") }
        contactRow.onTap = { [weak self] in self?.openConfiguredURL(key: "ContactURL") }

        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.text = "PixnovaAI · v\(Self.appVersion)"
        versionLabel.textColor = UIColor(hex: 0x56565C)
        versionLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        versionLabel.textAlignment = .center

        let arrangedSubviews: [UIView] = [
            makeSpacer(height: 25),
            subscriptionHeader,
            makeSpacer(height: 11),
            manageSubscriptionRow,
            restorePurchasesRow,
            makeSpacer(height: 25),
            legalHeader,
            makeSpacer(height: 11),
            privacyRow,
            agreementRow,
            subscriptionTermsRow,
            contactRow,
            makeSpacer(height: 28),
            versionLabel,
            makeSpacer(height: 31)
        ]
        arrangedSubviews.forEach(contentStackView.addArrangedSubview)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            subscriptionHeader.heightAnchor.constraint(equalToConstant: 18),
            manageSubscriptionRow.heightAnchor.constraint(equalToConstant: 71),
            restorePurchasesRow.heightAnchor.constraint(equalToConstant: 71),
            legalHeader.heightAnchor.constraint(equalToConstant: 18),
            privacyRow.heightAnchor.constraint(equalToConstant: 71),
            agreementRow.heightAnchor.constraint(equalToConstant: 71),
            subscriptionTermsRow.heightAnchor.constraint(equalToConstant: 71),
            contactRow.heightAnchor.constraint(equalToConstant: 71),
            versionLabel.heightAnchor.constraint(equalToConstant: 19)
        ])
    }

    private func configureToast() {
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.alpha = 0
        toastView.layer.cornerRadius = 14
        toastView.clipsToBounds = true
        toastView.layer.borderWidth = 1
        toastView.layer.borderColor = HomeDesignColor.border.cgColor

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.textColor = HomeDesignColor.text
        toastLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 2

        view.addSubview(toastView)
        toastView.contentView.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            toastView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
            toastView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            toastLabel.leadingAnchor.constraint(equalTo: toastView.contentView.leadingAnchor, constant: 16),
            toastLabel.trailingAnchor.constraint(equalTo: toastView.contentView.trailingAnchor, constant: -16),
            toastLabel.topAnchor.constraint(equalTo: toastView.contentView.topAnchor, constant: 11),
            toastLabel.bottomAnchor.constraint(equalTo: toastView.contentView.bottomAnchor, constant: -11)
        ])
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor(hex: 0x56565C)
        label.font = UIFont.systemFont(ofSize: 14.8, weight: .semibold)
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: label.font as Any,
                .foregroundColor: label.textColor as Any,
                .kern: 1.78
            ]
        )
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -28),
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func makeSpacer(height: CGFloat) -> UIView {
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: height).isActive = true
        return spacer
    }

    private func openSubscriptionManagement() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }

    private func restorePurchases() {
        guard restoreTask == nil else { return }
        restoreTask = Task { [weak self] in
            guard let self else { return }
            self.setLoading(true)
            do {
                try await purchaseHandler.restorePurchases()
                self.showToast("Restore successful. PRO is active.")
            } catch {
                self.showToast(error.localizedDescription)
            }
            self.setLoading(false)
            self.restoreTask = nil
        }
    }

    private func openConfiguredURL(key: String) {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: rawValue) else {
            showToast("This page is not available yet.")
            return
        }
        UIApplication.shared.open(url)
    }

    private func showToast(_ message: String) {
        toastLabel.text = message
        view.bringSubviewToFront(toastView)
        UIView.animate(withDuration: 0.18) {
            self.toastView.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.22, delay: 2.2, options: [.curveEaseInOut]) {
                self.toastView.alpha = 0
            }
        }
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}

private final class SettingsRowView: UIControl {
    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    init(title: String, iconName: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        iconView.image = UIImage(systemName: iconName)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = UIColor(hex: 0x909098)
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 19.8, weight: .semibold)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = UIColor(hex: 0x909098)
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(chevronView)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 19),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 18),
            chevronView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    @objc private func handleTap() {
        onTap?()
    }
}
