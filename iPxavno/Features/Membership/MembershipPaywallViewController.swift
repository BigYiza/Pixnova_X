import UIKit

final class MembershipPaywallViewController: BaseViewController {
    private let viewModel: MembershipPaywallViewModel

    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let crownContainer = UIView()
    private let crownIcon = UIImageView(image: UIImage(systemName: "crown"))
    private let headlineLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let featuresStack = UIStackView()
    private let planStack = UIStackView()
    private let ctaButton = UIButton(type: .system)
    private let renewalLabel = UILabel()
    private let legalStack = UIStackView()

    private var planCards: [MembershipPlanCardView] = []
    private var displayedErrorMessage: String?
    private var displayedCompletedMessage: String?

    init(viewModel: MembershipPaywallViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
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

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background
        configureNavigation()
        configureScrollView()
        configureHero()
        configureFeatures()
        configurePlans()
        configureCTA()
        configureLegal()
    }

    private func configureNavigation() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = HomeDesignColor.text
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 21, weight: .medium),
            forImageIn: .normal
        )
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = AppDisplay.proName
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 21.9, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72

        view.addSubview(closeButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -72)
        ])
    }

    private func configureScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = HomeDesignColor.background
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func configureHero() {
        crownContainer.translatesAutoresizingMaskIntoConstraints = false
        crownContainer.backgroundColor = HomeDesignColor.accent
        crownContainer.layer.cornerRadius = 28
        crownContainer.clipsToBounds = true

        crownIcon.translatesAutoresizingMaskIntoConstraints = false
        crownIcon.tintColor = HomeDesignColor.blackText
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 31, weight: .medium)

        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.text = "Unlock PRO"
        headlineLabel.textColor = HomeDesignColor.text
        headlineLabel.font = UIFont.systemFont(ofSize: 33, weight: .bold)
        headlineLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Unlimited photos · faster videos · no ads"
        subtitleLabel.textColor = HomeDesignColor.mutedText
        subtitleLabel.font = UIFont.systemFont(ofSize: 17.2, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75

        contentView.addSubview(crownContainer)
        crownContainer.addSubview(crownIcon)
        contentView.addSubview(headlineLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            crownContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            crownContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            crownContainer.widthAnchor.constraint(equalToConstant: 87),
            crownContainer.heightAnchor.constraint(equalToConstant: 87),

            crownIcon.centerXAnchor.constraint(equalTo: crownContainer.centerXAnchor),
            crownIcon.centerYAnchor.constraint(equalTo: crownContainer.centerYAnchor),
            crownIcon.widthAnchor.constraint(equalToConstant: 42),
            crownIcon.heightAnchor.constraint(equalToConstant: 42),

            headlineLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            headlineLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            headlineLabel.topAnchor.constraint(equalTo: crownContainer.bottomAnchor, constant: 28),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            subtitleLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 14)
        ])
    }

    private func configureFeatures() {
        featuresStack.translatesAutoresizingMaskIntoConstraints = false
        featuresStack.axis = .vertical
        featuresStack.spacing = 10
        featuresStack.distribution = .fill

        [
            "Unlimited photo filters",
            "Skip the video wait",
            "Weekly diamonds, no ads",
            "Early access to new looks"
        ].forEach { title in
            featuresStack.addArrangedSubview(MembershipFeatureRow(title: title))
        }

        contentView.addSubview(featuresStack)

        NSLayoutConstraint.activate([
            featuresStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            featuresStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            featuresStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24)
        ])
    }

    private func configurePlans() {
        planStack.translatesAutoresizingMaskIntoConstraints = false
        planStack.axis = .horizontal
        planStack.spacing = 14
        planStack.distribution = .fillEqually
        contentView.addSubview(planStack)

        NSLayoutConstraint.activate([
            planStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            planStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            planStack.topAnchor.constraint(equalTo: featuresStack.bottomAnchor, constant: 24),
            planStack.heightAnchor.constraint(equalToConstant: 141)
        ])
    }

    private func configureCTA() {
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = HomeDesignColor.accent
        ctaButton.layer.cornerRadius = 21
        ctaButton.clipsToBounds = true
        ctaButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        ctaButton.titleLabel?.numberOfLines = 2
        ctaButton.titleLabel?.textAlignment = .center
        ctaButton.addTarget(self, action: #selector(handlePurchase), for: .touchUpInside)

        renewalLabel.translatesAutoresizingMaskIntoConstraints = false
        renewalLabel.text = "Cancel anytime · auto-renews"
        renewalLabel.textColor = UIColor(hex: 0x56565C)
        renewalLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .regular)
        renewalLabel.textAlignment = .center

        contentView.addSubview(ctaButton)
        contentView.addSubview(renewalLabel)

        NSLayoutConstraint.activate([
            ctaButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            ctaButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            ctaButton.topAnchor.constraint(equalTo: planStack.bottomAnchor, constant: 31),
            ctaButton.heightAnchor.constraint(equalToConstant: 94),

            renewalLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            renewalLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            renewalLabel.topAnchor.constraint(equalTo: ctaButton.bottomAnchor, constant: 17)
        ])
    }

    private func configureLegal() {
        legalStack.translatesAutoresizingMaskIntoConstraints = false
        legalStack.axis = .vertical
        legalStack.alignment = .fill
        legalStack.distribution = .fill
        legalStack.spacing = 4

        legalStack.addArrangedSubview(makeLegalRow(
            leadingTitle: "Privacy Policy",
            leadingAction: #selector(handlePrivacy),
            trailingTitle: "Terms of Service",
            trailingAction: #selector(handleTerms)
        ))
        legalStack.addArrangedSubview(makeLegalRow(
            leadingTitle: "Subscription Terms",
            leadingAction: #selector(handleSubscriptionTerms),
            trailingTitle: "Restore Purchases",
            trailingAction: #selector(handleRestore)
        ))

        contentView.addSubview(legalStack)

        NSLayoutConstraint.activate([
            legalStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 29),
            legalStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -29),
            legalStack.topAnchor.constraint(equalTo: renewalLabel.bottomAnchor, constant: 20),
            legalStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -42)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.setLoading(state.isLoading)
            self.ctaButton.isEnabled = !state.isLoading
            self.rebuildPlans(state.plans, selectedID: state.selectedPlanID)
            self.updateCTA()
            self.presentErrorIfNeeded(state.errorMessage)
            self.presentCompletionIfNeeded(state.completedMessage)
        }
    }

    private func rebuildPlans(_ plans: [MembershipPurchasePlan], selectedID: String?) {
        guard planCards.map(\.planID) != plans.map(\.id) || planCards.contains(where: { $0.isSelectedCard != ($0.planID == selectedID) }) else {
            return
        }

        planStack.arrangedSubviews.forEach { view in
            planStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        planCards = []

        for plan in Array(plans.prefix(2)) {
            let card = MembershipPlanCardView()
            card.configure(plan: plan, isSelected: plan.id == selectedID)
            card.addTarget(self, action: #selector(handlePlanTap(_:)), for: .touchUpInside)
            planStack.addArrangedSubview(card)
            planCards.append(card)
        }
    }

    private func updateCTA() {
        let plan = viewModel.selectedPlan
        let title = plan?.callToAction ?? "Continue"
        let subtitle = plan.map(Self.purchasePriceText(for:)) ?? "Select a plan"
        let attributed = NSMutableAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20.5, weight: .bold),
                .foregroundColor: HomeDesignColor.blackText
            ]
        )
        attributed.append(NSAttributedString(
            string: "\n\(subtitle)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.5, weight: .semibold),
                .foregroundColor: HomeDesignColor.blackText.withAlphaComponent(0.75)
            ]
        ))
        ctaButton.setAttributedTitle(attributed, for: .normal)
        renewalLabel.text = plan?.kind == .yearly
            ? "Cancel anytime · auto-renews yearly"
            : "Cancel anytime · auto-renews"
    }

    private static func purchasePriceText(for plan: MembershipPurchasePlan) -> String {
        let priceWithPeriod: String
        switch plan.kind {
        case .weekly:
            priceWithPeriod = "\(plan.price)/week"
        case .yearly:
            priceWithPeriod = "\(plan.price)/year"
        case .other:
            priceWithPeriod = plan.price
        }

        return plan.hasIntroOffer
            ? "then \(priceWithPeriod)"
            : "\(priceWithPeriod) · auto-renews"
    }

    private func makeLegalButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(HomeDesignColor.mutedText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15.3, weight: .regular)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeLegalRow(
        leadingTitle: String,
        leadingAction: Selector,
        trailingTitle: String,
        trailingAction: Selector
    ) -> UIStackView {
        let row = UIStackView(arrangedSubviews: [
            makeLegalButton(title: leadingTitle, action: leadingAction),
            makeDotLabel(),
            makeLegalButton(title: trailingTitle, action: trailingAction)
        ])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.spacing = 10
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        return row
    }

    private func makeDotLabel() -> UILabel {
        let label = UILabel()
        label.text = "·"
        label.textColor = UIColor(hex: 0x56565C)
        label.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        return label
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    private func presentCompletionIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedCompletedMessage != message else { return }
        displayedCompletedMessage = message
        let alert = UIAlertController(title: "PRO Active", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.dismissOrPop()
        })
        present(alert, animated: true)
    }

    private func openConfiguredURL(key: String) {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: rawValue) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func dismissOrPop() {
        if navigationController?.viewControllers.first === self {
            dismiss(animated: true)
        } else if navigationController != nil {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func handleClose() {
        dismissOrPop()
    }

    @objc private func handlePlanTap(_ sender: MembershipPlanCardView) {
        viewModel.select(planID: sender.planID)
    }

    @objc private func handlePurchase() {
        viewModel.purchaseSelectedPlan()
    }

    @objc private func handleRestore() {
        viewModel.restorePurchases()
    }

    @objc private func handlePrivacy() {
        openConfiguredURL(key: "PrivacyPolicyURL")
    }

    @objc private func handleTerms() {
        openConfiguredURL(key: "TermsOfServiceURL")
    }

    @objc private func handleSubscriptionTerms() {
        openConfiguredURL(key: "SubscriptionTermsURL")
    }
}

private final class MembershipFeatureRow: UIView {
    private let iconContainer = UIView()
    private let iconView = UIImageView(image: UIImage(systemName: "checkmark"))
    private let titleLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        configureView()
        titleLabel.text = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 32).isActive = true

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = HomeDesignColor.accent.withAlphaComponent(0.18)
        iconContainer.layer.cornerRadius = 15.5
        iconContainer.clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = HomeDesignColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 31),
            iconContainer.heightAnchor.constraint(equalToConstant: 31),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class MembershipPlanCardView: UIControl {
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let badgeLabel = UILabel()
    private let borderLayer = CAShapeLayer()

    private(set) var planID = ""
    private(set) var isSelectedCard = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: 22
        ).cgPath
    }

    func configure(plan: MembershipPurchasePlan, isSelected: Bool) {
        planID = plan.id
        isSelectedCard = isSelected
        titleLabel.text = plan.title
        priceLabel.text = plan.price
        subtitleLabel.text = plan.subtitle
        badgeLabel.isHidden = !plan.isBestValue

        backgroundColor = isSelected ? HomeDesignColor.accent.withAlphaComponent(0.06) : .clear
        borderLayer.strokeColor = (isSelected ? HomeDesignColor.accent : HomeDesignColor.border).cgColor
    }

    private func configureView() {
        layer.cornerRadius = 22
        clipsToBounds = false
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        [titleLabel, priceLabel, subtitleLabel, badgeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.textAlignment = .center
            addSubview($0)
        }

        titleLabel.textColor = HomeDesignColor.mutedText
        titleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)

        priceLabel.textColor = HomeDesignColor.text
        priceLabel.font = UIFont.systemFont(ofSize: 25.4, weight: .bold)
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.72

        subtitleLabel.textColor = HomeDesignColor.mutedText
        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byClipping
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.5

        badgeLabel.backgroundColor = HomeDesignColor.accent
        badgeLabel.text = "BEST VALUE"
        badgeLabel.textColor = HomeDesignColor.blackText
        badgeLabel.font = UIFont.systemFont(ofSize: 9.9, weight: .heavy)
        badgeLabel.layer.cornerRadius = 7
        badgeLabel.clipsToBounds = true

        NSLayoutConstraint.activate([
            badgeLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: -10),
            badgeLabel.widthAnchor.constraint(equalToConstant: 80),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),

            priceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            subtitleLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 9),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
}
