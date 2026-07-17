import UIKit

struct DiamondPackOption: Equatable {
    let pack: DiamondPurchasePack
    let requiresMembership: Bool

    var id: String { pack.id }
    var diamondAmount: Int? { pack.diamondAmount }
    var isPurchasable: Bool { pack.isPurchasable && !requiresMembership }
}

private enum DiamondProductID {
    static let standard10 = "com.lainc.picvidai.diamonds.10"
    static let standard50 = "com.lainc.picvidai.diamonds.50"
    static let standard200 = "com.lainc.picvidai.diamonds.200"
    static let standard500 = "com.lainc.picvidai.diamonds.500"
    static let standard1000Normal = "com.lainc.picvidai.diamonds.1000.normal"
    static let standard1000Activity = "com.lainc.picvidai.diamonds.1000.activity"
    static let member15 = "com.lainc.picvidai.diamonds.15"
    static let member60 = "com.lainc.picvidai.diamonds.60"
    static let member240 = "com.lainc.picvidai.diamonds.240"
    static let member600 = "com.lainc.picvidai.diamonds.600"
    static let member1200Normal = "com.lainc.picvidai.diamonds.1200.normal"
    static let member1200Activity = "com.lainc.picvidai.diamonds.1200.activity"

    static let standardDailyIDs: Set<String> = [
        standard10,
        standard50,
        standard200,
        standard500,
        standard1000Normal
    ]
    static let memberDailyIDs: Set<String> = [
        member15,
        member60,
        member240,
        member600,
        member1200Normal
    ]
    static let activityIDs: Set<String> = [
        standard1000Activity,
        member1200Activity
    ]
}

private enum DiamondPurchaseDisplayMode {
    case general
    case subscriber
}

private final class DiamondActivityOfferState {
    private enum Key {
        static let firstShownAt = "diamond_activity_offer_first_shown_at"
        static let purchased = "diamond_activity_offer_purchased"
    }

    private let defaults: UserDefaults
    private let duration: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func ensureStarted(now: Date = Date()) {
        guard defaults.object(forKey: Key.firstShownAt) == nil else { return }
        defaults.set(now.timeIntervalSince1970, forKey: Key.firstShownAt)
    }

    func markPurchased() {
        defaults.set(true, forKey: Key.purchased)
    }

    func isActive(now: Date = Date()) -> Bool {
        !defaults.bool(forKey: Key.purchased) && remainingTime(now: now) > 0
    }

    func remainingTime(now: Date = Date()) -> TimeInterval {
        guard defaults.object(forKey: Key.firstShownAt) != nil else { return duration }
        let startedAt = defaults.double(forKey: Key.firstShownAt)
        let elapsed = now.timeIntervalSince1970 - startedAt
        return max(0, duration - elapsed)
    }
}

struct DiamondPurchaseState {
    var packs: [DiamondPackOption]
    var selectedPackID: String?
    var currentDiamonds: Int
    var isMember: Bool
    var isLoading: Bool
    var errorMessage: String?
    var completedMessage: String?
    var completedPackID: String?

    static let empty = DiamondPurchaseState(
        packs: [],
        selectedPackID: nil,
        currentDiamonds: 0,
        isMember: false,
        isLoading: false,
        errorMessage: nil,
        completedMessage: nil,
        completedPackID: nil
    )
}

@MainActor
final class DiamondPurchaseViewModel {
    let state = Observable(DiamondPurchaseState.empty)

    private static let standardDiamondAmounts: Set<Int> = [10, 50, 200, 500, 1000]
    private static let memberDiamondAmounts: Set<Int> = [15, 60, 240, 600, 1200]

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

    var selectedOption: DiamondPackOption? {
        state.value.packs.first { $0.id == state.value.selectedPackID }
    }

    var selectedPack: DiamondPurchasePack? {
        selectedOption?.pack
    }

    func load() {
        load(forceRefreshMembership: false)
    }

    func reloadAfterMembershipChange() {
        load(forceRefreshMembership: true)
    }

    private func load(forceRefreshMembership: Bool) {
        let cachedMembership = membershipHandler.cachedMembership
        state.value = DiamondPurchaseState(
            packs: state.value.packs,
            selectedPackID: state.value.selectedPackID,
            currentDiamonds: cachedMembership.diamonds,
            isMember: cachedMembership.isVIP,
            isLoading: true,
            errorMessage: nil,
            completedMessage: nil,
            completedPackID: nil
        )

        Task {
            do {
                let membership = forceRefreshMembership
                    ? try await membershipHandler.membershipStatus(forceRefresh: true)
                    : membershipHandler.cachedMembership
                let packs = visibleOptions(
                    from: try await purchaseHandler.loadPacks(catalog: catalog),
                    isMember: membership.isVIP
                )
                state.value = DiamondPurchaseState(
                    packs: packs,
                    selectedPackID: preferredSelectedPackID(from: packs, isMember: membership.isVIP),
                    currentDiamonds: membership.diamonds,
                    isMember: membership.isVIP,
                    isLoading: false,
                    errorMessage: nil,
                    completedMessage: nil,
                    completedPackID: nil
                )
            } catch {
                let membership = membershipHandler.cachedMembership
                let fallbackPacks = fallbackPacks()
                state.value = DiamondPurchaseState(
                    packs: fallbackPacks,
                    selectedPackID: preferredSelectedPackID(from: fallbackPacks, isMember: membership.isVIP),
                    currentDiamonds: membership.diamonds,
                    isMember: membership.isVIP,
                    isLoading: false,
                    errorMessage: error.localizedDescription,
                    completedMessage: nil,
                    completedPackID: nil
                )
            }
        }
    }

    func select(packID: String) {
        guard state.value.packs.contains(where: { $0.id == packID }) else { return }
        state.value.selectedPackID = packID
    }

    func requiresMembership(packID: String) -> Bool {
        state.value.packs.first { $0.id == packID }?.requiresMembership == true
    }

    func purchaseSelectedPack() {
        guard let selectedOption else {
            state.value.errorMessage = DiamondPurchaseError.productUnavailable.localizedDescription
            return
        }

        guard !selectedOption.requiresMembership else {
            state.value.errorMessage = "Unlock PRO to buy this diamond pack."
            return
        }

        guard selectedOption.pack.isPurchasable else {
            state.value.errorMessage = "Diamond products are not available from App Store right now."
            return
        }

        state.value.isLoading = true
        state.value.errorMessage = nil
        state.value.completedMessage = nil
        state.value.completedPackID = nil

        Task {
            do {
                let completedPackID = selectedOption.id
                try await purchaseHandler.purchase(packID: selectedOption.id)
                let membership = try await membershipHandler.membershipStatus(forceRefresh: true)
                analytics.record(
                    AnalyticsEvent(
                        name: "diamond_pack_purchase_completed",
                        properties: ["product_id": selectedOption.id]
                    )
                )
                state.value = DiamondPurchaseState(
                    packs: state.value.packs,
                    selectedPackID: state.value.selectedPackID,
                    currentDiamonds: membership.diamonds,
                    isMember: membership.isVIP,
                    isLoading: false,
                    errorMessage: nil,
                    completedMessage: "Diamonds added.",
                    completedPackID: completedPackID
                )
            } catch DiamondPurchaseError.purchaseCancelled {
                state.value.isLoading = false
            } catch {
                state.value.isLoading = false
                state.value.errorMessage = error.localizedDescription
            }
        }
    }

    private func preferredSelectedPackID(from packs: [DiamondPackOption], isMember: Bool) -> String? {
        let preferredAmounts = isMember ? Self.memberDiamondAmounts : Self.standardDiamondAmounts
        let minimumAmount = isMember ? 60 : 50
        return packs.first(where: {
            !$0.requiresMembership
                && $0.diamondAmount.map { preferredAmounts.contains($0) && $0 >= minimumAmount } == true
        })?.id
            ?? packs.first(where: { !$0.requiresMembership })?.id
    }

    private func fallbackPacks() -> [DiamondPackOption] {
        let isMember = membershipHandler.cachedMembership.isVIP
        return visibleProductIDs().map { productID in
            let amount = Self.diamondAmount(from: productID)
            let pack = DiamondPurchasePack(
                id: productID,
                title: amount.map { "\($0) Diamonds" } ?? "Diamond Pack",
                price: "Unavailable",
                subtitle: productID,
                diamondAmount: amount,
                isPurchasable: false
            )
            return DiamondPackOption(
                pack: pack,
                requiresMembership: !isMember && Self.memberDiamondAmounts.contains(amount ?? 0)
            )
        }
    }

    private func visibleOptions(from packs: [DiamondPurchasePack], isMember: Bool) -> [DiamondPackOption] {
        let visibleAmounts = Self.standardDiamondAmounts.union(Self.memberDiamondAmounts)
        return packs.filter { pack in
            guard let amount = pack.diamondAmount else { return false }
            return visibleAmounts.contains(amount)
        }.map { pack in
            DiamondPackOption(
                pack: pack,
                requiresMembership: !isMember && Self.memberDiamondAmounts.contains(pack.diamondAmount ?? 0)
            )
        }
    }

    private func visibleProductIDs() -> [String] {
        let visibleAmounts = Self.standardDiamondAmounts.union(Self.memberDiamondAmounts)
        return catalog.allProductIDs.filter { productID in
            guard let amount = Self.diamondAmount(from: productID) else { return false }
            return visibleAmounts.contains(amount)
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
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let modeControl = DiamondModeSegmentedControl()
    private let premiumCard = DiamondPremiumCardView()
    private let limitedOfferCard = DiamondLimitedOfferCardView()
    private let dailyTitleLabel = UILabel()
    private let packStack = UIStackView()
    private let confirmPurchaseButton = DiamondConfirmPurchaseButton()
    private let footnoteLabel = UILabel()

    private var packCards: [DiamondPackCardView] = []
    private var premiumHeightConstraint: NSLayoutConstraint?
    private var limitedTopConstraint: NSLayoutConstraint?
    private var limitedHeightConstraint: NSLayoutConstraint?
    private var dailyTopConstraint: NSLayoutConstraint?
    private var displayedPackIDs: [String] = []
    private var displayedErrorMessage: String?
    private var displayedCompletedMessage: String?
    private var displayedCompletedPackID: String?
    private var displayMode = DiamondPurchaseDisplayMode.general
    private var hasConfiguredInitialDisplayMode = false
    private let activityOfferState = DiamondActivityOfferState()
    private var activityTimer: Timer?
    private var hasAppeared = false
    private var isSyncingSelection = false

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
        activityOfferState.ensureStarted()
        viewModel.load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if hasAppeared {
            viewModel.reloadAfterMembershipChange()
        }
        hasAppeared = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopActivityTimer()
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
        titleLabel.text = "Get Diamonds"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 21.9, weight: .semibold)
        titleLabel.textAlignment = .center

        view.addSubview(closeButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -72)
        ])
    }

    private func configureContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = HomeDesignColor.background
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.onGeneralTap = { [weak self] in
            self?.handleGeneralModeTap()
        }
        modeControl.onSubscriberTap = { [weak self] in
            self?.handleSubscriberModeTap()
        }

        premiumCard.translatesAutoresizingMaskIntoConstraints = false
        premiumCard.addTarget(self, action: #selector(handlePremiumTap), for: .touchUpInside)

        limitedOfferCard.translatesAutoresizingMaskIntoConstraints = false
        limitedOfferCard.addTarget(self, action: #selector(handleLimitedOfferTap(_:)), for: .touchUpInside)

        dailyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        dailyTitleLabel.text = "DAILY PACKAGES"
        dailyTitleLabel.textColor = UIColor(hex: 0x56565C)
        dailyTitleLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .semibold)
        dailyTitleLabel.textAlignment = .center
        dailyTitleLabel.letterSpacing = 2.54

        packStack.translatesAutoresizingMaskIntoConstraints = false
        packStack.axis = .vertical
        packStack.spacing = 12.7

        confirmPurchaseButton.translatesAutoresizingMaskIntoConstraints = false
        confirmPurchaseButton.addTarget(self, action: #selector(handleConfirmPurchase), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(modeControl)
        contentView.addSubview(premiumCard)
        contentView.addSubview(limitedOfferCard)
        contentView.addSubview(dailyTitleLabel)
        contentView.addSubview(packStack)
        contentView.addSubview(confirmPurchaseButton)

        let premiumHeightConstraint = premiumCard.heightAnchor.constraint(equalToConstant: 254)
        let limitedTopConstraint = limitedOfferCard.topAnchor.constraint(equalTo: premiumCard.bottomAnchor, constant: 20)
        let limitedHeightConstraint = limitedOfferCard.heightAnchor.constraint(equalToConstant: 0)
        let dailyTopConstraint = dailyTitleLabel.topAnchor.constraint(equalTo: limitedOfferCard.bottomAnchor, constant: 35)
        self.premiumHeightConstraint = premiumHeightConstraint
        self.limitedTopConstraint = limitedTopConstraint
        self.limitedHeightConstraint = limitedHeightConstraint
        self.dailyTopConstraint = dailyTopConstraint

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 15),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            modeControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28.5),
            modeControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28.5),
            modeControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8.5),
            modeControl.heightAnchor.constraint(equalToConstant: 68),

            premiumCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28.25),
            premiumCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28.25),
            premiumCard.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 22.6),
            premiumHeightConstraint,

            limitedOfferCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28.25),
            limitedOfferCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28.25),
            limitedTopConstraint,
            limitedHeightConstraint,

            dailyTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            dailyTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            dailyTopConstraint,
            dailyTitleLabel.heightAnchor.constraint(equalToConstant: 18),

            packStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28.25),
            packStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28.25),
            packStack.topAnchor.constraint(equalTo: dailyTitleLabel.bottomAnchor, constant: 16),

            confirmPurchaseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28.25),
            confirmPurchaseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28.25),
            confirmPurchaseButton.topAnchor.constraint(equalTo: packStack.bottomAnchor, constant: 24),
            confirmPurchaseButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func configureCTA() {
        footnoteLabel.translatesAutoresizingMaskIntoConstraints = false
        footnoteLabel.text = "Diamonds are consumed for AI generation.\nSecure payments powered by Stripe."
        footnoteLabel.textColor = UIColor(hex: 0x56565C)
        footnoteLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .regular)
        footnoteLabel.textAlignment = .center
        footnoteLabel.numberOfLines = 0

        contentView.addSubview(footnoteLabel)

        NSLayoutConstraint.activate([
            footnoteLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            footnoteLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            footnoteLabel.topAnchor.constraint(equalTo: confirmPurchaseButton.bottomAnchor, constant: 22),
            footnoteLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func bindViewModel() {
        viewModel.state.bind { [weak self] state in
            guard let self else { return }
            self.setLoading(state.isLoading)
            if !self.hasConfiguredInitialDisplayMode, !state.packs.isEmpty {
                self.displayMode = state.isMember ? .subscriber : .general
                self.hasConfiguredInitialDisplayMode = true
            }
            self.updateDisplayPresentation()
            self.handleCompletedActivityPurchaseIfNeeded(packID: state.completedPackID)
            let dailyPacks = self.displayedPacks(from: state.packs)
            let activityOffer = self.activityOffer(from: state.packs)
            self.syncSelectionIfNeeded(
                dailyPacks: dailyPacks,
                activityOffer: activityOffer,
                selectedID: state.selectedPackID
            )
            self.rebuildPacks(
                dailyPacks,
                activityOffer: activityOffer,
                selectedID: self.viewModel.state.value.selectedPackID
            )
            self.updateConfirmPurchaseButton(selectedOption: self.viewModel.selectedOption)
            self.presentErrorIfNeeded(state.errorMessage)
            self.presentCompletionIfNeeded(state.completedMessage, packID: state.completedPackID)
        }
    }

    private func updateDisplayPresentation() {
        let isSubscriberMode = displayMode == .subscriber
        modeControl.configure(isSubscriber: isSubscriberMode)
        premiumCard.isHidden = isSubscriberMode
        premiumHeightConstraint?.constant = isSubscriberMode ? 0 : 254
    }

    private func displayedPacks(from packs: [DiamondPackOption]) -> [DiamondPackOption] {
        packs.filter { option in
            switch displayMode {
            case .general:
                return DiamondProductID.standardDailyIDs.contains(option.id)
            case .subscriber:
                return DiamondProductID.memberDailyIDs.contains(option.id)
            }
        }
    }

    private func activityOffer(from packs: [DiamondPackOption]) -> DiamondPackOption? {
        guard activityOfferState.isActive() else { return nil }
        let offerID = displayMode == .subscriber
            ? DiamondProductID.member1200Activity
            : DiamondProductID.standard1000Activity
        return packs.first { $0.id == offerID }
    }

    private func syncSelectionIfNeeded(
        dailyPacks: [DiamondPackOption],
        activityOffer: DiamondPackOption?,
        selectedID: String?
    ) {
        guard !isSyncingSelection else { return }
        let visibleOptions = [activityOffer].compactMap { $0 } + dailyPacks
        guard !visibleOptions.isEmpty else { return }
        guard selectedID == nil || !visibleOptions.contains(where: { $0.id == selectedID }) else { return }

        isSyncingSelection = true
        viewModel.select(packID: visibleOptions[0].id)
        isSyncingSelection = false
    }

    private func updateConfirmPurchaseButton(selectedOption: DiamondPackOption?) {
        confirmPurchaseButton.configure(
            title: "Confirm Purchase",
            subtitle: selectedOption?.pack.price ?? "Select a package",
            isEnabled: selectedOption != nil && !viewModel.state.value.isLoading
        )
    }

    private func rebuildPacks(
        _ packs: [DiamondPackOption],
        activityOffer: DiamondPackOption?,
        selectedID: String?
    ) {
        let dailyPacks = packs
        let modeKey = displayMode == .subscriber ? "subscriber" : "general"
        let offerKey = activityOffer.map { "activity:\($0.id)" } ?? "activity:none"
        let selectedKey = selectedID.map { "selected:\($0)" } ?? "selected:none"
        let allDisplayedIDs = [modeKey, offerKey, selectedKey] + dailyPacks.map(\.id)
        guard displayedPackIDs != allDisplayedIDs || packCards.contains(where: { $0.isSelectedPack != ($0.packID == selectedID) }) else {
            updateActivityOffer(activityOffer)
            return
        }
        displayedPackIDs = allDisplayedIDs

        packStack.arrangedSubviews.forEach { view in
            packStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        packCards = []

        updateActivityOffer(activityOffer)

        for pack in dailyPacks {
            let card = DiamondPackCardView()
            card.configure(option: pack, isSelected: pack.id == selectedID)
            card.addTarget(self, action: #selector(handlePackTap(_:)), for: .touchUpInside)
            packStack.addArrangedSubview(card)
            card.heightAnchor.constraint(equalToConstant: displayMode == .subscriber ? 90.5 : 75).isActive = true
            packCards.append(card)
        }
    }

    private func updateActivityOffer(_ offer: DiamondPackOption?) {
        let hasOffer = offer != nil
        limitedOfferCard.isHidden = !hasOffer
        limitedHeightConstraint?.constant = hasOffer ? 333 : 0
        limitedTopConstraint?.constant = hasOffer ? (displayMode == .subscriber ? 1 : 20) : 0
        dailyTopConstraint?.constant = hasOffer ? 35 : (displayMode == .subscriber ? 28 : 35)

        guard let offer else {
            stopActivityTimer()
            return
        }

        let remainingTime = activityOfferState.remainingTime()
        limitedOfferCard.configure(
            option: offer,
            isMember: viewModel.state.value.isMember,
            remainingTime: remainingTime,
            comparisonPrice: "$79.99",
            isSelected: offer.id == viewModel.state.value.selectedPackID
        )
        updateActivityTimerState()
    }

    private func updateActivityTimerState() {
        guard activityOfferState.isActive(), !limitedOfferCard.isHidden else {
            stopActivityTimer()
            return
        }
        guard activityTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.handleActivityTimerTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        activityTimer = timer
    }

    private func stopActivityTimer() {
        activityTimer?.invalidate()
        activityTimer = nil
    }

    private func handleActivityTimerTick() {
        guard activityOfferState.isActive() else {
            stopActivityTimer()
            rebuildPacks(
                displayedPacks(from: viewModel.state.value.packs),
                activityOffer: activityOffer(from: viewModel.state.value.packs),
                selectedID: viewModel.state.value.selectedPackID
            )
            return
        }

        limitedOfferCard.updateRemainingTime(activityOfferState.remainingTime())
    }

    private func handleCompletedActivityPurchaseIfNeeded(packID: String?) {
        guard let packID,
              displayedCompletedPackID != packID,
              DiamondProductID.activityIDs.contains(packID) else {
            return
        }
        displayedCompletedPackID = packID
        activityOfferState.markPurchased()
        stopActivityTimer()
    }

    private func presentErrorIfNeeded(_ message: String?) {
        guard let message, !message.isEmpty, displayedErrorMessage != message else { return }
        displayedErrorMessage = message
        showError(message)
    }

    private func presentCompletionIfNeeded(_ message: String?, packID: String?) {
        guard let message, !message.isEmpty else { return }
        guard displayedCompletedMessage != message || displayedCompletedPackID != packID else { return }
        displayedCompletedMessage = message
        displayedCompletedPackID = packID
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
        selectPack(packID: sender.packID)
    }

    @objc private func handleLimitedOfferTap(_ sender: DiamondLimitedOfferCardView) {
        selectPack(packID: sender.packID)
    }

    @objc private func handleConfirmPurchase() {
        guard let packID = viewModel.state.value.selectedPackID else { return }
        purchaseOrUnlock(packID: packID)
    }

    @objc private func handlePremiumTap() {
        presentMembershipPaywall()
    }

    private func handleGeneralModeTap() {
        displayMode = .general
        updateDisplayPresentation()
        let dailyPacks = displayedPacks(from: viewModel.state.value.packs)
        let activityOffer = activityOffer(from: viewModel.state.value.packs)
        syncSelectionIfNeeded(
            dailyPacks: dailyPacks,
            activityOffer: activityOffer,
            selectedID: viewModel.state.value.selectedPackID
        )
        rebuildPacks(
            dailyPacks,
            activityOffer: activityOffer,
            selectedID: viewModel.state.value.selectedPackID
        )
        updateConfirmPurchaseButton(selectedOption: viewModel.selectedOption)
    }

    private func handleSubscriberModeTap() {
        displayMode = .subscriber
        updateDisplayPresentation()
        let dailyPacks = displayedPacks(from: viewModel.state.value.packs)
        let activityOffer = activityOffer(from: viewModel.state.value.packs)
        syncSelectionIfNeeded(
            dailyPacks: dailyPacks,
            activityOffer: activityOffer,
            selectedID: viewModel.state.value.selectedPackID
        )
        rebuildPacks(
            dailyPacks,
            activityOffer: activityOffer,
            selectedID: viewModel.state.value.selectedPackID
        )
        updateConfirmPurchaseButton(selectedOption: viewModel.selectedOption)
    }

    private func selectPack(packID: String) {
        viewModel.select(packID: packID)
    }

    private func purchaseOrUnlock(packID: String) {
        if viewModel.requiresMembership(packID: packID) {
            presentMembershipPaywall()
            return
        }
        viewModel.select(packID: packID)
        viewModel.purchaseSelectedPack()
    }

    private func presentMembershipPaywall() {
        let container = AppRuntime.shared.container
        let paywall = MembershipPaywallViewController(
            viewModel: MembershipPaywallViewModel(
                membershipHandler: container.membershipHandler,
                purchaseHandler: container.membershipPurchaseHandler,
                analytics: container.analytics
            )
        )
        let navigationController = UINavigationController(rootViewController: paywall)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }
}

private final class DiamondModeSegmentedControl: UIView {
    var onGeneralTap: (() -> Void)?
    var onSubscriberTap: (() -> Void)?

    private let generalButton = UIControl()
    private let subscriberButton = UIControl()
    private let generalLabel = UILabel()
    private let subscriberIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
    private let subscriberLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(isSubscriber: Bool) {
        generalButton.backgroundColor = isSubscriber ? .clear : UIColor(hex: 0xFAFAF8)
        subscriberButton.backgroundColor = isSubscriber ? UIColor(hex: 0xFAFAF8) : .clear
        generalLabel.textColor = isSubscriber ? UIColor(hex: 0x9A9AA2) : UIColor(hex: 0x0A0A0C)
        subscriberLabel.textColor = isSubscriber ? UIColor(hex: 0x0A0A0C) : UIColor(hex: 0x9A9AA2)
        subscriberIcon.tintColor = isSubscriber ? UIColor(hex: 0x0A0A0C) : UIColor(hex: 0x9A9AA2)
    }

    private func configureView() {
        backgroundColor = UIColor(hex: 0x0F0F11)
        layer.cornerRadius = 34
        layer.borderWidth = 1
        layer.borderColor = HomeDesignColor.border.cgColor
        clipsToBounds = true

        [generalButton, subscriberButton, generalLabel, subscriberIcon, subscriberLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        generalButton.layer.cornerRadius = 28.4
        subscriberButton.layer.cornerRadius = 28.4
        generalButton.clipsToBounds = true
        subscriberButton.clipsToBounds = true
        generalButton.addTarget(self, action: #selector(handleGeneral), for: .touchUpInside)
        subscriberButton.addTarget(self, action: #selector(handleSubscriber), for: .touchUpInside)

        generalLabel.text = "General"
        generalLabel.font = UIFont.systemFont(ofSize: 18.4, weight: .semibold)
        generalLabel.textAlignment = .center

        subscriberLabel.text = "Subscriber"
        subscriberLabel.font = UIFont.systemFont(ofSize: 18.4, weight: .semibold)
        subscriberLabel.textAlignment = .center

        subscriberIcon.contentMode = .scaleAspectFit
        subscriberIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)

        addSubview(generalButton)
        addSubview(subscriberButton)
        generalButton.addSubview(generalLabel)
        subscriberButton.addSubview(subscriberIcon)
        subscriberButton.addSubview(subscriberLabel)

        NSLayoutConstraint.activate([
            generalButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5.6),
            generalButton.topAnchor.constraint(equalTo: topAnchor, constant: 5.6),
            generalButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5.6),
            generalButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -5.6),

            subscriberButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5.6),
            subscriberButton.topAnchor.constraint(equalTo: topAnchor, constant: 5.6),
            subscriberButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5.6),
            subscriberButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -5.6),

            generalLabel.centerXAnchor.constraint(equalTo: generalButton.centerXAnchor),
            generalLabel.centerYAnchor.constraint(equalTo: generalButton.centerYAnchor),

            subscriberIcon.leadingAnchor.constraint(greaterThanOrEqualTo: subscriberButton.leadingAnchor, constant: 18),
            subscriberIcon.trailingAnchor.constraint(equalTo: subscriberLabel.leadingAnchor, constant: -8),
            subscriberIcon.centerYAnchor.constraint(equalTo: subscriberButton.centerYAnchor),
            subscriberIcon.widthAnchor.constraint(equalToConstant: 18),
            subscriberIcon.heightAnchor.constraint(equalToConstant: 18),

            subscriberLabel.centerXAnchor.constraint(equalTo: subscriberButton.centerXAnchor, constant: 12),
            subscriberLabel.centerYAnchor.constraint(equalTo: subscriberButton.centerYAnchor)
        ])
    }

    @objc private func handleGeneral() {
        onGeneralTap?()
    }

    @objc private func handleSubscriber() {
        onSubscriberTap?()
    }
}

private final class DiamondPremiumCardView: UIControl {
    private let badgeLabel = UILabel()
    private let iconBackground = UIView()
    private let crownIcon = UIImageView(image: UIImage(systemName: "crown.fill"))
    private let titleLabel = UILabel()
    private let firstCheck = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let firstLabel = UILabel()
    private let secondCheck = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let secondLabel = UILabel()
    private let actionBackground = UIView()
    private let actionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        layer.cornerRadius = 22.6
        layer.borderWidth = 1
        layer.borderColor = HomeDesignColor.accent.withAlphaComponent(0.32).cgColor

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "3-DAY FREE TRIAL"
        badgeLabel.textColor = UIColor(hex: 0x06281C)
        badgeLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor(hex: 0x34D399)
        badgeLabel.layer.cornerRadius = 9.9
        badgeLabel.clipsToBounds = true

        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = HomeDesignColor.accent
        iconBackground.layer.cornerRadius = 14.1
        iconBackground.clipsToBounds = true

        crownIcon.translatesAutoresizingMaskIntoConstraints = false
        crownIcon.tintColor = HomeDesignColor.blackText
        crownIcon.contentMode = .scaleAspectFit
        crownIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Premium Member"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 22.6, weight: .bold)

        [firstCheck, secondCheck].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.tintColor = HomeDesignColor.accent
            $0.contentMode = .scaleAspectFit
            $0.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        }

        firstLabel.translatesAutoresizingMaskIntoConstraints = false
        firstLabel.text = "Get 30 diamonds now + weekly"
        secondLabel.translatesAutoresizingMaskIntoConstraints = false
        secondLabel.text = "Unlock all features"
        [firstLabel, secondLabel].forEach {
            $0.textColor = UIColor(hex: 0x9A9AA2)
            $0.font = UIFont.systemFont(ofSize: 16.3, weight: .regular)
        }

        actionBackground.translatesAutoresizingMaskIntoConstraints = false
        actionBackground.backgroundColor = HomeDesignColor.accent
        actionBackground.layer.cornerRadius = 17
        actionBackground.isUserInteractionEnabled = false

        actionLabel.translatesAutoresizingMaskIntoConstraints = false
        actionLabel.text = "Try Free"
        actionLabel.textColor = HomeDesignColor.blackText
        actionLabel.font = UIFont.systemFont(ofSize: 19.8, weight: .bold)
        actionLabel.textAlignment = .center

        addSubview(badgeLabel)
        addSubview(iconBackground)
        iconBackground.addSubview(crownIcon)
        addSubview(titleLabel)
        addSubview(firstCheck)
        addSubview(firstLabel)
        addSubview(secondCheck)
        addSubview(secondLabel)
        addSubview(actionBackground)
        actionBackground.addSubview(actionLabel)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 19.8),
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            badgeLabel.widthAnchor.constraint(equalToConstant: 143.7),
            badgeLabel.heightAnchor.constraint(equalToConstant: 27.7),

            iconBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 19.8),
            iconBackground.topAnchor.constraint(equalTo: topAnchor, constant: 50),
            iconBackground.widthAnchor.constraint(equalToConstant: 48),
            iconBackground.heightAnchor.constraint(equalToConstant: 48),

            crownIcon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            crownIcon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            crownIcon.widthAnchor.constraint(equalToConstant: 25.4),
            crownIcon.heightAnchor.constraint(equalToConstant: 25.4),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 83.3),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            titleLabel.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),

            firstCheck.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 19.8),
            firstCheck.topAnchor.constraint(equalTo: topAnchor, constant: 110),
            firstCheck.widthAnchor.constraint(equalToConstant: 18.4),
            firstCheck.heightAnchor.constraint(equalToConstant: 18.4),

            firstLabel.leadingAnchor.constraint(equalTo: firstCheck.trailingAnchor, constant: 11.3),
            firstLabel.centerYAnchor.constraint(equalTo: firstCheck.centerYAnchor),
            firstLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            secondCheck.leadingAnchor.constraint(equalTo: firstCheck.leadingAnchor),
            secondCheck.topAnchor.constraint(equalTo: firstCheck.bottomAnchor, constant: 15),
            secondCheck.widthAnchor.constraint(equalToConstant: 18.4),
            secondCheck.heightAnchor.constraint(equalToConstant: 18.4),

            secondLabel.leadingAnchor.constraint(equalTo: firstLabel.leadingAnchor),
            secondLabel.centerYAnchor.constraint(equalTo: secondCheck.centerYAnchor),
            secondLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            actionBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 19.8),
            actionBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -19.8),
            actionBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -21.8),
            actionBackground.heightAnchor.constraint(equalToConstant: 65.5),

            actionLabel.centerXAnchor.constraint(equalTo: actionBackground.centerXAnchor),
            actionLabel.centerYAnchor.constraint(equalTo: actionBackground.centerYAnchor)
        ])
    }
}

private final class DiamondConfirmPurchaseButton: UIControl {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let labelStack = UIStackView()

    override var isEnabled: Bool {
        didSet {
            alpha = isEnabled ? 1 : 0.55
        }
    }

    override var isHighlighted: Bool {
        didSet {
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.985, y: 0.985) : .identity
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, subtitle: String, isEnabled: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        self.isEnabled = isEnabled
    }

    private func configureView() {
        backgroundColor = HomeDesignColor.accent
        layer.cornerRadius = 21.2
        clipsToBounds = true

        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.axis = .vertical
        labelStack.alignment = .center
        labelStack.spacing = 3
        labelStack.isUserInteractionEnabled = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Confirm Purchase"
        titleLabel.textColor = HomeDesignColor.blackText
        titleLabel.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.textColor = HomeDesignColor.blackText.withAlphaComponent(0.72)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .semibold)
        subtitleLabel.textAlignment = .center

        addSubview(labelStack)
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            labelStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 18),
            labelStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            labelStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            labelStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class DiamondLimitedOfferCardView: UIControl {
    private let headerView = UIView()
    private let headerLabel = UILabel()
    private let timerLabel = UILabel()
    private let diamondIcon = UILabel()
    private let amountLabel = UILabel()
    private let bonusLabel = UILabel()
    private let priceLabel = UILabel()
    private let soonLabel = UILabel()
    private let buttonBackground = UIView()
    private let buttonLabel = UILabel()

    private(set) var packID = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        option: DiamondPackOption,
        isMember: Bool,
        remainingTime: TimeInterval,
        comparisonPrice: String,
        isSelected: Bool
    ) {
        packID = option.id
        let presentation = DiamondPricingPresentation(amount: option.diamondAmount, isMember: isMember)
        amountLabel.text = presentation.amountText
        bonusLabel.text = presentation.bonusText
        bonusLabel.isHidden = presentation.bonusText == nil
        priceLabel.text = option.pack.price
        soonLabel.text = "Will be \(comparisonPrice) soon"
        backgroundColor = isSelected ? HomeDesignColor.accent.withAlphaComponent(0.06) : .clear
        layer.borderWidth = isSelected ? 2 : 1
        layer.borderColor = (isSelected ? HomeDesignColor.accent : HomeDesignColor.accent.withAlphaComponent(0.32)).cgColor
        buttonLabel.text = isSelected ? "Selected" : "Select"
        updateRemainingTime(remainingTime)
    }

    func updateRemainingTime(_ remainingTime: TimeInterval) {
        timerLabel.text = Self.timeText(remainingTime)
    }

    private func configureView() {
        layer.cornerRadius = 25.4
        layer.borderWidth = 1
        layer.borderColor = HomeDesignColor.accent.withAlphaComponent(0.32).cgColor
        clipsToBounds = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = HomeDesignColor.accent.withAlphaComponent(0.13)

        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "LIMITED OFFER"
        headerLabel.textColor = HomeDesignColor.text
        headerLabel.font = UIFont.systemFont(ofSize: 18.4, weight: .bold)
        headerLabel.letterSpacing = 0.37

        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.text = "00 : 00 : 42"
        timerLabel.textColor = HomeDesignColor.text
        timerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15.5, weight: .bold)
        timerLabel.textAlignment = .right

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.text = "💎"
        diamondIcon.font = UIFont.systemFont(ofSize: 22)
        diamondIcon.textAlignment = .center

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.textColor = HomeDesignColor.text
        amountLabel.font = UIFont.systemFont(ofSize: 28.3, weight: .bold)
        amountLabel.textAlignment = .center

        bonusLabel.translatesAutoresizingMaskIntoConstraints = false
        bonusLabel.textColor = HomeDesignColor.accent
        bonusLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.textColor = HomeDesignColor.text
        priceLabel.font = UIFont.systemFont(ofSize: 42.4, weight: .heavy)
        priceLabel.textAlignment = .center
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.75

        soonLabel.translatesAutoresizingMaskIntoConstraints = false
        soonLabel.textColor = UIColor(hex: 0x9A9AA2)
        soonLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        soonLabel.textAlignment = .center

        buttonBackground.translatesAutoresizingMaskIntoConstraints = false
        buttonBackground.backgroundColor = HomeDesignColor.accent
        buttonBackground.layer.cornerRadius = 21.2
        buttonBackground.isUserInteractionEnabled = false

        buttonLabel.translatesAutoresizingMaskIntoConstraints = false
        buttonLabel.text = "Continue"
        buttonLabel.textColor = HomeDesignColor.blackText
        buttonLabel.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)
        buttonLabel.textAlignment = .center

        addSubview(headerView)
        headerView.addSubview(headerLabel)
        headerView.addSubview(timerLabel)
        addSubview(diamondIcon)
        addSubview(amountLabel)
        addSubview(bonusLabel)
        addSubview(priceLabel)
        addSubview(soonLabel)
        addSubview(buttonBackground)
        buttonBackground.addSubview(buttonLabel)

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 58.8),

            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 19.8),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            timerLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            timerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            timerLabel.widthAnchor.constraint(equalToConstant: 138),

            diamondIcon.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor, constant: 1),
            diamondIcon.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -8),
            diamondIcon.widthAnchor.constraint(equalToConstant: 28),
            diamondIcon.heightAnchor.constraint(equalToConstant: 28),

            amountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            amountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 79),

            bonusLabel.leadingAnchor.constraint(equalTo: amountLabel.trailingAnchor, constant: 8),
            bonusLabel.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor, constant: 3),

            priceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -60),
            priceLabel.topAnchor.constraint(equalTo: topAnchor, constant: 127),
            priceLabel.heightAnchor.constraint(equalToConstant: 54),

            soonLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            soonLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            soonLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 14),

            buttonBackground.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 19.8),
            buttonBackground.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -19.8),
            buttonBackground.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -21.8),
            buttonBackground.heightAnchor.constraint(equalToConstant: 72.3),

            buttonLabel.centerXAnchor.constraint(equalTo: buttonBackground.centerXAnchor),
            buttonLabel.centerYAnchor.constraint(equalTo: buttonBackground.centerYAnchor)
        ])
    }

    private static func timeText(_ remainingTime: TimeInterval) -> String {
        let totalSeconds = max(0, Int(ceil(remainingTime)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d : %02d : %02d", hours, minutes, seconds)
    }
}

private final class DiamondPackCardView: UIControl {
    private let priceLabel = UILabel()
    private let originalPriceLabel = UILabel()
    private let discountBadge = UILabel()
    private let discountStack = UIStackView()
    private let diamondIcon = UILabel()
    private let amountLabel = UILabel()
    private let bonusLabel = UILabel()
    private var amountCenterYConstraint: NSLayoutConstraint?

    private(set) var packID = ""
    private(set) var isSelectedPack = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(option: DiamondPackOption, isSelected: Bool) {
        packID = option.id
        isSelectedPack = isSelected
        let presentation = DiamondPricingPresentation(amount: option.diamondAmount, isMember: option.diamondAmount.map { [15, 60, 240, 600, 1200].contains($0) } ?? false)
        priceLabel.text = option.pack.price
        amountLabel.text = presentation.amountText
        bonusLabel.text = presentation.bonusText
        let hasBonus = presentation.bonusText != nil
        bonusLabel.isHidden = !hasBonus
        amountCenterYConstraint?.constant = hasBonus ? -8 : 0
        originalPriceLabel.attributedText = presentation.originalPrice.map(Self.strikethroughText(_:))
        originalPriceLabel.isHidden = presentation.originalPrice == nil
        discountBadge.text = presentation.discountText
        discountBadge.isHidden = presentation.discountText == nil
        applySelectedState(isSelected)
    }

    private func applySelectedState(_ isSelected: Bool) {
        backgroundColor = isSelected ? HomeDesignColor.accent.withAlphaComponent(0.1) : UIColor(hex: 0x0F0F11)
        layer.borderWidth = isSelected ? 1.7 : 1
        layer.borderColor = (isSelected ? HomeDesignColor.accent : HomeDesignColor.border).cgColor
        priceLabel.textColor = isSelected ? HomeDesignColor.text : HomeDesignColor.text.withAlphaComponent(0.92)
        amountLabel.textColor = HomeDesignColor.accent
    }

    private func configureView() {
        backgroundColor = UIColor(hex: 0x0F0F11)
        layer.cornerRadius = 19.8
        layer.borderWidth = 1
        layer.borderColor = HomeDesignColor.border.cgColor
        clipsToBounds = true

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.textColor = HomeDesignColor.text
        priceLabel.font = UIFont.systemFont(ofSize: 22.6, weight: .bold)
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.78

        originalPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        originalPriceLabel.textColor = UIColor(hex: 0x56565C)
        originalPriceLabel.font = UIFont.systemFont(ofSize: 14.8, weight: .regular)

        discountBadge.translatesAutoresizingMaskIntoConstraints = false
        discountBadge.backgroundColor = HomeDesignColor.accent
        discountBadge.textColor = HomeDesignColor.blackText
        discountBadge.font = UIFont.systemFont(ofSize: 11.3, weight: .heavy)
        discountBadge.textAlignment = .center
        discountBadge.layer.cornerRadius = 7
        discountBadge.clipsToBounds = true

        discountStack.translatesAutoresizingMaskIntoConstraints = false
        discountStack.axis = .vertical
        discountStack.alignment = .leading
        discountStack.distribution = .fill
        discountStack.spacing = 4
        discountStack.addArrangedSubview(originalPriceLabel)
        discountStack.addArrangedSubview(discountBadge)

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.text = "💎"
        diamondIcon.font = UIFont.systemFont(ofSize: 18)
        diamondIcon.textAlignment = .center

        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.textColor = HomeDesignColor.accent
        amountLabel.font = UIFont.systemFont(ofSize: 22.6, weight: .bold)
        amountLabel.textAlignment = .right

        bonusLabel.translatesAutoresizingMaskIntoConstraints = false
        bonusLabel.textColor = UIColor(hex: 0x9A9AA2)
        bonusLabel.font = UIFont.systemFont(ofSize: 14.1, weight: .semibold)
        bonusLabel.textAlignment = .right

        addSubview(priceLabel)
        addSubview(discountStack)
        addSubview(diamondIcon)
        addSubview(amountLabel)
        addSubview(bonusLabel)

        let amountCenterYConstraint = amountLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8)
        self.amountCenterYConstraint = amountCenterYConstraint

        NSLayoutConstraint.activate([
            priceLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21.2),
            priceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            priceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),

            discountStack.leadingAnchor.constraint(equalTo: priceLabel.trailingAnchor, constant: 10),
            discountStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            discountStack.trailingAnchor.constraint(lessThanOrEqualTo: diamondIcon.leadingAnchor, constant: -10),

            discountBadge.widthAnchor.constraint(equalToConstant: 70),
            discountBadge.heightAnchor.constraint(equalToConstant: 24),

            amountLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -48.9),
            amountCenterYConstraint,

            diamondIcon.trailingAnchor.constraint(equalTo: amountLabel.leadingAnchor, constant: -8),
            diamondIcon.centerYAnchor.constraint(equalTo: amountLabel.centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 24),
            diamondIcon.heightAnchor.constraint(equalToConstant: 24),

            bonusLabel.trailingAnchor.constraint(equalTo: amountLabel.trailingAnchor),
            bonusLabel.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 2)
        ])
    }

    private static func strikethroughText(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14.8, weight: .regular),
                .foregroundColor: UIColor(hex: 0x56565C),
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }
}

private struct DiamondPricingPresentation {
    let amountText: String
    let bonusText: String?
    let originalPrice: String?
    let discountText: String?

    init(amount: Int?, isMember: Bool) {
        _ = isMember
        let amount = amount ?? 0
        amountText = amount > 0 ? "\(amount)" : "--"

        switch amount {
        case 15:
            bonusText = "+5"
        case 60:
            bonusText = "+10"
        case 240:
            bonusText = "+40"
        case 600:
            bonusText = "+100"
        case 1200:
            bonusText = "+200"
        default:
            bonusText = nil
        }

        switch amount {
        case 50, 60:
            originalPrice = "$9.99"
            discountText = "40% OFF"
        case 200, 240:
            originalPrice = "$39.99"
            discountText = "58% OFF"
        case 500, 600:
            originalPrice = "$99.99"
            discountText = "60% OFF"
        default:
            originalPrice = nil
            discountText = nil
        }
    }
}

private extension UILabel {
    var letterSpacing: CGFloat {
        get { 0 }
        set {
            guard let text else { return }
            attributedText = NSAttributedString(
                string: text,
                attributes: [.kern: newValue, .font: font as Any, .foregroundColor: textColor as Any]
            )
        }
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
