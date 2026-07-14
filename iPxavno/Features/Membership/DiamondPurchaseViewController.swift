import UIKit

struct DiamondPurchaseState {
    var packs: [DiamondPurchasePack]
    var selectedPackID: String?
    var currentDiamonds: Int
    var isLoading: Bool
    var errorMessage: String?
    var completedMessage: String?

    static let empty = DiamondPurchaseState(
        packs: [],
        selectedPackID: nil,
        currentDiamonds: 0,
        isLoading: false,
        errorMessage: nil,
        completedMessage: nil
    )
}

@MainActor
final class DiamondPurchaseViewModel {
    let state = Observable(DiamondPurchaseState.empty)

    private let catalog: DiamondProductCatalog
    private let membershipHandler: MembershipHandling
    private let purchaseHandler: DiamondPurchaseHandling
    private let analytics: AnalyticsTracking

    init(
        catalog: DiamondProductCatalog,
        membershipHandler: MembershipHandling,
        purchaseHandler: DiamondPurchaseHandling,
        analytics: AnalyticsTracking
    ) {
        self.catalog = catalog
        self.membershipHandler = membershipHandler
        self.purchaseHandler = purchaseHandler
        self.analytics = analytics
        state.value.currentDiamonds = membershipHandler.cachedMembership.diamonds
    }

    var selectedPack: DiamondPurchasePack? {
        state.value.packs.first { $0.id == state.value.selectedPackID }
    }

    func load() {
        state.value = DiamondPurchaseState(
            packs: state.value.packs,
            selectedPackID: state.value.selectedPackID,
            currentDiamonds: membershipHandler.cachedMembership.diamonds,
            isLoading: true,
            errorMessage: nil,
            completedMessage: nil
        )

        Task {
            do {
                let packs = try await purchaseHandler.loadPacks(catalog: catalog)
                state.value = DiamondPurchaseState(
                    packs: packs,
                    selectedPackID: preferredSelectedPackID(from: packs),
                    currentDiamonds: membershipHandler.cachedMembership.diamonds,
                    isLoading: false,
                    errorMessage: nil,
                    completedMessage: nil
                )
            } catch {
                let fallbackPacks = fallbackPacks()
                state.value = DiamondPurchaseState(
                    packs: fallbackPacks,
                    selectedPackID: fallbackPacks.first?.id,
                    currentDiamonds: membershipHandler.cachedMembership.diamonds,
                    isLoading: false,
                    errorMessage: error.localizedDescription,
                    completedMessage: nil
                )
            }
        }
    }

    func select(packID: String) {
        guard state.value.packs.contains(where: { $0.id == packID }) else { return }
        state.value.selectedPackID = packID
    }

    func purchaseSelectedPack() {
        guard let selectedPack else {
            state.value.errorMessage = DiamondPurchaseError.productUnavailable.localizedDescription
            return
        }

        guard selectedPack.isPurchasable else {
            state.value.errorMessage = "Diamond products are not available from App Store right now."
            return
        }

        state.value.isLoading = true
        state.value.errorMessage = nil
        state.value.completedMessage = nil

        Task {
            do {
                try await purchaseHandler.purchase(packID: selectedPack.id)
                let membership = try await membershipHandler.membershipStatus(forceRefresh: true)
                analytics.record(
                    AnalyticsEvent(
                        name: "diamond_pack_purchase_completed",
                        properties: ["product_id": selectedPack.id]
                    )
                )
                state.value = DiamondPurchaseState(
                    packs: state.value.packs,
                    selectedPackID: state.value.selectedPackID,
                    currentDiamonds: membership.diamonds,
                    isLoading: false,
                    errorMessage: nil,
                    completedMessage: "Diamonds added."
                )
            } catch DiamondPurchaseError.purchaseCancelled {
                state.value.isLoading = false
            } catch {
                state.value.isLoading = false
                state.value.errorMessage = error.localizedDescription
            }
        }
    }

    private func preferredSelectedPackID(from packs: [DiamondPurchasePack]) -> String? {
        packs.first(where: { $0.diamondAmount.map { $0 >= 100 } == true })?.id ?? packs.first?.id
    }

    private func fallbackPacks() -> [DiamondPurchasePack] {
        catalog.allProductIDs.map { productID in
            let amount = Self.diamondAmount(from: productID)
            return DiamondPurchasePack(
                id: productID,
                title: amount.map { "\($0) Diamonds" } ?? "Diamond Pack",
                price: "Unavailable",
                subtitle: productID,
                diamondAmount: amount,
                isPurchasable: false
            )
        }
    }

    private static func diamondAmount(from text: String) -> Int? {
        text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .first
    }
}

final class DiamondPurchaseViewController: BaseViewController {
    private let viewModel: DiamondPurchaseViewModel

    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let balancePill = UIView()
    private let balanceIcon = UIImageView(image: UIImage(systemName: "suit.diamond.fill"))
    private let balanceLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headlineLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let packStack = UIStackView()
    private let ctaButton = UIButton(type: .system)
    private let footnoteLabel = UILabel()

    private var packCards: [DiamondPackCardView] = []
    private var displayedErrorMessage: String?
    private var displayedCompletedMessage: String?

    init(viewModel: DiamondPurchaseViewModel) {
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
        configureContent()
        configureCTA()
    }

    private func configureNavigation() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = HomeDesignColor.text
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold),
            forImageIn: .normal
        )
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Get diamonds"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 21.5, weight: .bold)
        titleLabel.textAlignment = .center

        balancePill.translatesAutoresizingMaskIntoConstraints = false
        balancePill.backgroundColor = HomeDesignColor.accent
        balancePill.layer.cornerRadius = 21
        balancePill.clipsToBounds = true

        balanceIcon.translatesAutoresizingMaskIntoConstraints = false
        balanceIcon.tintColor = HomeDesignColor.blackText
        balanceIcon.contentMode = .scaleAspectFit
        balanceIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)

        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        balanceLabel.textColor = HomeDesignColor.blackText
        balanceLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)

        view.addSubview(closeButton)
        view.addSubview(titleLabel)
        view.addSubview(balancePill)
        balancePill.addSubview(balanceIcon)
        balancePill.addSubview(balanceLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: balancePill.leadingAnchor, constant: -16),

            balancePill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            balancePill.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            balancePill.heightAnchor.constraint(equalToConstant: 42),
            balancePill.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            balanceIcon.leadingAnchor.constraint(equalTo: balancePill.leadingAnchor, constant: 15),
            balanceIcon.centerYAnchor.constraint(equalTo: balancePill.centerYAnchor),
            balanceIcon.widthAnchor.constraint(equalToConstant: 15),
            balanceIcon.heightAnchor.constraint(equalToConstant: 15),

            balanceLabel.leadingAnchor.constraint(equalTo: balanceIcon.trailingAnchor, constant: 8),
            balanceLabel.trailingAnchor.constraint(equalTo: balancePill.trailingAnchor, constant: -15),
            balanceLabel.centerYAnchor.constraint(equalTo: balancePill.centerYAnchor)
        ])
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = HomeDesignColor.background
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        headlineLabel.text = "Top up diamonds"
        headlineLabel.textColor = HomeDesignColor.text
        headlineLabel.font = UIFont.systemFont(ofSize: 31, weight: .bold)
        headlineLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Use diamonds to generate videos, images, and premium effects."
        subtitleLabel.textColor = HomeDesignColor.mutedText
        subtitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        subtitleLabel.numberOfLines = 0

        packStack.translatesAutoresizingMaskIntoConstraints = false
        packStack.axis = .vertical
        packStack.spacing = 12

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(headlineLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(packStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 18),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            headlineLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            headlineLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            headlineLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            subtitleLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 13),

            packStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            packStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            packStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32)
        ])
    }

    private func configureCTA() {
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.backgroundColor = HomeDesignColor.accent
        ctaButton.layer.cornerRadius = 21
        ctaButton.clipsToBounds = true
        ctaButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        ctaButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        ctaButton.addTarget(self, action: #selector(handlePurchase), for: .touchUpInside)

        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.text = "Consumable items are credited after Apple confirms the purchase."
        footnoteLabel.textColor = UIColor(hex: 0x56565C)
        footnoteLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        footnoteLabel.textAlignment = .center
        footnoteLabel.numberOfLines = 0

        contentView.addSubview(ctaButton)
        contentView.addSubview(footnoteLabel)

        NSLayoutConstraint.activate([
            ctaButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            ctaButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            ctaButton.topAnchor.constraint(equalTo: packStack.bottomAnchor, constant: 26),
            ctaButton.heightAnchor.constraint(equalToConstant: 70),

            footnoteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            footnoteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            footnoteLabel.topAnchor.constraint(equalTo: ctaButton.bottomAnchor, constant: 15),
            footnoteLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.setLoading(state.isLoading)
            self.balanceLabel.text = "\(state.currentDiamonds)"
            self.rebuildPacks(state.packs, selectedID: state.selectedPackID)
            self.updateCTA()
            self.presentErrorIfNeeded(state.errorMessage)
            self.presentCompletionIfNeeded(state.completedMessage)
        }
    }

    private func rebuildPacks(_ packs: [DiamondPurchasePack], selectedID: String?) {
        guard packCards.map(\.packID) != packs.map(\.id) || packCards.contains(where: { $0.isSelectedPack != ($0.packID == selectedID) }) else {
            return
        }

        packStack.arrangedSubviews.forEach { view in
            packStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        packCards = []

        for pack in packs {
            let card = DiamondPackCardView()
            card.configure(pack: pack, isSelected: pack.id == selectedID)
            card.addTarget(self, action: #selector(handlePackTap(_:)), for: .touchUpInside)
            packStack.addArrangedSubview(card)
            card.heightAnchor.constraint(equalToConstant: 92).isActive = true
            packCards.append(card)
        }
    }

    private func updateCTA() {
        guard let selectedPack = viewModel.selectedPack else {
            ctaButton.setTitle("Choose a pack", for: .normal)
            ctaButton.isEnabled = false
            ctaButton.alpha = 0.55
            return
        }

        ctaButton.setTitle("Continue · \(selectedPack.price)", for: .normal)
        ctaButton.isEnabled = true
        ctaButton.alpha = selectedPack.isPurchasable ? 1 : 0.68
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    private func presentCompletionIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedCompletedMessage != message else { return }
        displayedCompletedMessage = message
        let alert = UIAlertController(title: "Diamonds ready", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
            self?.dismissOrPop()
        })
        present(alert, animated: true)
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

    @objc private func handlePackTap(_ sender: DiamondPackCardView) {
        viewModel.select(packID: sender.packID)
    }

    @objc private func handlePurchase() {
        viewModel.purchaseSelectedPack()
    }
}

private final class DiamondPackCardView: UIControl {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let priceLabel = UILabel()
    private let diamondIcon = UIImageView(image: UIImage(systemName: "suit.diamond.fill"))
    private let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    private(set) var packID = ""
    private(set) var isSelectedPack = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(pack: DiamondPurchasePack, isSelected: Bool) {
        packID = pack.id
        isSelectedPack = isSelected
        titleLabel.text = pack.title
        subtitleLabel.text = pack.subtitle
        priceLabel.text = pack.price
        backgroundColor = isSelected ? HomeDesignColor.accent.withAlphaComponent(0.08) : UIColor.white.withAlphaComponent(0.06)
        layer.borderColor = (isSelected ? HomeDesignColor.accent : HomeDesignColor.border).cgColor
        diamondIcon.tintColor = isSelected ? HomeDesignColor.accent : HomeDesignColor.mutedText
        checkmarkView.isHidden = !isSelected
    }

    private func configureView() {
        layer.cornerRadius = 21
        layer.borderWidth = 1
        clipsToBounds = true

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.contentMode = .scaleAspectFit
        diamondIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = HomeDesignColor.mutedText
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.72

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.textColor = HomeDesignColor.text
        priceLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        priceLabel.textAlignment = .right
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkView.tintColor = HomeDesignColor.accent
        checkmarkView.contentMode = .scaleAspectFit
        checkmarkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)

        addSubview(diamondIcon)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(priceLabel)
        addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            diamondIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            diamondIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 24),
            diamondIcon.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: diamondIcon.trailingAnchor, constant: 15),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -14),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 21),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -14),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),

            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48),
            priceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 78),

            checkmarkView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
}

final class InsufficientDiamondsSheetViewController: UIViewController {
    var onGetDiamonds: (() -> Void)?
    var onGoPro: (() -> Void)?

    private let required: Int
    private let available: Int
    private let dimmingView = UIControl()
    private let panelView = UIView()
    private let grabberView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let getDiamondsButton = UIButton(type: .system)
    private let proButton = UIButton(type: .system)
    private let crownIcon = UIImageView(image: UIImage(systemName: "crown"))
    private let proLabel = UILabel()
    private var panelBottomConstraint: NSLayoutConstraint?

    init(required: Int, available: Int) {
        self.required = required
        self.available = available
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPanel()
    }

    private func configureView() {
        view.backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dimmingView.alpha = 0
        dimmingView.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = UIColor(hex: 0x141416)
        panelView.layer.cornerRadius = 34
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.layer.borderWidth = 1
        panelView.layer.borderColor = HomeDesignColor.border.cgColor
        panelView.clipsToBounds = true

        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.backgroundColor = UIColor(hex: 0x3A3A40)
        grabberView.layer.cornerRadius = 3

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Not enough diamonds"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 25.4, weight: .bold)
        titleLabel.numberOfLines = 0

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.attributedText = makeMessage()
        messageLabel.numberOfLines = 0

        getDiamondsButton.translatesAutoresizingMaskIntoConstraints = false
        getDiamondsButton.backgroundColor = HomeDesignColor.accent
        getDiamondsButton.layer.cornerRadius = 21
        getDiamondsButton.clipsToBounds = true
        getDiamondsButton.setTitle("Get diamonds", for: .normal)
        getDiamondsButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        getDiamondsButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)
        getDiamondsButton.addTarget(self, action: #selector(handleGetDiamonds), for: .touchUpInside)

        proButton.translatesAutoresizingMaskIntoConstraints = false
        proButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        proButton.layer.cornerRadius = 21
        proButton.layer.borderWidth = 1
        proButton.layer.borderColor = HomeDesignColor.border.cgColor
        proButton.clipsToBounds = true
        proButton.addTarget(self, action: #selector(handleGoPro), for: .touchUpInside)

        crownIcon.translatesAutoresizingMaskIntoConstraints = false
        crownIcon.tintColor = HomeDesignColor.text
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)

        proLabel.translatesAutoresizingMaskIntoConstraints = false
        proLabel.text = "Go PRO · weekly diamonds"
        proLabel.textColor = HomeDesignColor.text
        proLabel.font = UIFont.systemFont(ofSize: 18.4, weight: .semibold)
        proLabel.textAlignment = .center
        proLabel.adjustsFontSizeToFitWidth = true
        proLabel.minimumScaleFactor = 0.74

        view.addSubview(dimmingView)
        view.addSubview(panelView)
        panelView.addSubview(grabberView)
        panelView.addSubview(titleLabel)
        panelView.addSubview(messageLabel)
        panelView.addSubview(getDiamondsButton)
        panelView.addSubview(proButton)
        proButton.addSubview(crownIcon)
        proButton.addSubview(proLabel)

        panelBottomConstraint = panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 410)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottomConstraint!,

            grabberView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 22),
            grabberView.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 54),
            grabberView.heightAnchor.constraint(equalToConstant: 6),

            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -28),
            titleLabel.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 56),

            messageLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 28),
            messageLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -28),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 13),

            getDiamondsButton.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 28),
            getDiamondsButton.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -28),
            getDiamondsButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 25),
            getDiamondsButton.heightAnchor.constraint(equalToConstant: 72),

            proButton.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 28),
            proButton.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -28),
            proButton.topAnchor.constraint(equalTo: getDiamondsButton.bottomAnchor, constant: 13),
            proButton.heightAnchor.constraint(equalToConstant: 71),
            proButton.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -58),

            crownIcon.leadingAnchor.constraint(greaterThanOrEqualTo: proButton.leadingAnchor, constant: 30),
            crownIcon.trailingAnchor.constraint(equalTo: proLabel.leadingAnchor, constant: -12),
            crownIcon.centerYAnchor.constraint(equalTo: proButton.centerYAnchor),
            crownIcon.widthAnchor.constraint(equalToConstant: 18),
            crownIcon.heightAnchor.constraint(equalToConstant: 18),

            proLabel.centerXAnchor.constraint(equalTo: proButton.centerXAnchor, constant: 14),
            proLabel.centerYAnchor.constraint(equalTo: proButton.centerYAnchor),
            proLabel.widthAnchor.constraint(lessThanOrEqualTo: proButton.widthAnchor, constant: -80)
        ])
    }

    private func makeMessage() -> NSAttributedString {
        let fullText = "You need \(required) diamonds to generate this video. You have \(available)."
        let attributed = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17.7, weight: .regular),
                .foregroundColor: HomeDesignColor.mutedText
            ]
        )
        let requiredRange = (fullText as NSString).range(of: "\(required)")
        attributed.addAttributes(
            [
                .font: UIFont.systemFont(ofSize: 17.7, weight: .bold),
                .foregroundColor: HomeDesignColor.accent
            ],
            range: requiredRange
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributed.length))
        return attributed
    }

    private func presentPanel() {
        view.layoutIfNeeded()
        panelBottomConstraint?.constant = 0
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.88,
            initialSpringVelocity: 0.45,
            options: [.curveEaseOut]
        ) {
            self.dimmingView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }

    private func dismissPanel(completion: (() -> Void)? = nil) {
        panelBottomConstraint?.constant = panelView.bounds.height + 20
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseInOut]) {
            self.dimmingView.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.dismiss(animated: false, completion: completion)
        }
    }

    @objc private func handleDismiss() {
        dismissPanel()
    }

    @objc private func handleGetDiamonds() {
        let action = onGetDiamonds
        dismissPanel {
            action?()
        }
    }

    @objc private func handleGoPro() {
        let action = onGoPro
        dismissPanel {
            action?()
        }
    }
}
