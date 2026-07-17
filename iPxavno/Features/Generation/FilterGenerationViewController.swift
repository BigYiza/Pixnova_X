import UIKit

final class FilterGenerationViewController: BaseGenerationWorkflowViewController {
    private let contentRepository: ContentRepository
    private let sourceSection: ContentSection?
    private let imageSelectionCoordinator = ImageSelectionCoordinator()

    private var cards: [ContentSection] = []
    private var selectedCardIndex = 0
    private var selectedTemplateIndex = 0
    private var selectedTemplate: CreativeTemplate
    private var selectedPhotoURLs: [URL] = []
    private var selectedLocalPhotoURL: URL?
    private var contentObserver: NSObjectProtocol?
    private var pendingSegmentScrollIndex: Int?
    private var pendingTemplateScrollIndexPath: IndexPath?
    private var hasSelectedPhoto: Bool {
        selectedPhotoURLs.first != nil
    }

    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let diamondPill = UIControl()
    private let diamondIcon = UILabel()
    private let diamondLabel = UILabel()
    private let photoPlaceholderView = FilterPhotoPlaceholderView()
    private let resultPreviewView = FilterResultPreviewView()
    private let arrowImageView = UIImageView(image: UIImage(systemName: "arrow.right"))
    private let choosePhotoButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private let bottomContentView = UIView()
    private lazy var segmentCollectionView = UICollectionView(frame: .zero, collectionViewLayout: makeSegmentLayout())
    private lazy var templateCollectionView = UICollectionView(frame: .zero, collectionViewLayout: makeTemplateLayout())

    init(
        initialTemplate: CreativeTemplate,
        sourceSection: ContentSection?,
        contentRepository: ContentRepository,
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        generationWorkflowRunner: GenerationWorkflowRunning,
        analytics: AnalyticsTracking
    ) {
        selectedTemplate = initialTemplate
        self.sourceSection = sourceSection
        self.contentRepository = contentRepository
        super.init(
            membershipHandler: membershipHandler,
            generationRepository: generationRepository,
            generationWorkflowRunner: generationWorkflowRunner,
            analytics: analytics
        )
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        configureView()
        observeContentCatalogChanges()
        prepareDataSource(from: contentRepository.cachedAllCards, preferredTemplateID: selectedTemplate.id)
        updateSelectedTemplate(animated: false)
        analytics.record(
            AnalyticsEvent(
                name: "filter_generation_opened",
                properties: ["template_id": "\(selectedTemplate.id)", "title": selectedTemplate.title]
            )
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDiamondBalance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollPendingItems()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard isMovingFromParent || isBeingDismissed, let contentObserver else { return }
        NotificationCenter.default.removeObserver(contentObserver)
        self.contentObserver = nil
    }

    override func makeGenerationWorkflowRequest() async throws -> GenerationWorkflowRequest {
        let mediaInputs: [GenerationMediaInput] = selectedPhotoURLs.first.map { [.localImage($0)] } ?? [.empty]
        let draft = CreationDraft(
            templateID: selectedTemplate.id,
            mediaInputs: mediaInputs,
            prompt: selectedTemplate.prompt,
            negativePrompt: nil,
            externalArguments: [:],
            combineConfigs: selectedTemplate.combineConfigs
        )
        return GenerationWorkflowRequest(
            kind: .filter,
            template: selectedTemplate,
            draft: draft,
            inputRequirement: GenerationWorkflowInputRequirement(requiredMediaCount: 1)
        )
    }

    override func presentGenerationMediaPicker(kind: GenerationWorkflowMediaKind, index: Int) -> Bool {
        guard kind == .image else { return false }
        handleChoosePhoto()
        return true
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background

        configureNavigation()
        configureHero()
        configureBottomContent()

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(diamondPill)
        diamondPill.addSubview(diamondIcon)
        diamondPill.addSubview(diamondLabel)
        view.addSubview(photoPlaceholderView)
        view.addSubview(resultPreviewView)
        view.addSubview(arrowImageView)
        view.addSubview(choosePhotoButton)
        view.addSubview(hintLabel)
        view.addSubview(bottomContentView)
        bottomContentView.addSubview(segmentCollectionView)
        bottomContentView.addSubview(templateCollectionView)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: diamondPill.leadingAnchor, constant: -14),

            diamondPill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            diamondPill.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            diamondPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            diamondPill.heightAnchor.constraint(equalToConstant: 45),

            diamondIcon.leadingAnchor.constraint(equalTo: diamondPill.leadingAnchor, constant: 17),
            diamondIcon.centerYAnchor.constraint(equalTo: diamondPill.centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 22),
            diamondIcon.heightAnchor.constraint(equalToConstant: 22),

            diamondLabel.leadingAnchor.constraint(equalTo: diamondIcon.trailingAnchor, constant: 5),
            diamondLabel.trailingAnchor.constraint(equalTo: diamondPill.trailingAnchor, constant: -16),
            diamondLabel.centerYAnchor.constraint(equalTo: diamondPill.centerYAnchor),

            photoPlaceholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            photoPlaceholderView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 24),
            photoPlaceholderView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.35),
            photoPlaceholderView.heightAnchor.constraint(equalTo: photoPlaceholderView.widthAnchor, multiplier: 1.34),

            resultPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            resultPreviewView.topAnchor.constraint(equalTo: photoPlaceholderView.topAnchor, constant: 2),
            resultPreviewView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.34),
            resultPreviewView.heightAnchor.constraint(equalTo: photoPlaceholderView.heightAnchor),

            arrowImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arrowImageView.centerYAnchor.constraint(equalTo: photoPlaceholderView.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 20),
            arrowImageView.heightAnchor.constraint(equalToConstant: 20),

            choosePhotoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            choosePhotoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            choosePhotoButton.topAnchor.constraint(equalTo: photoPlaceholderView.bottomAnchor, constant: 22),
            choosePhotoButton.heightAnchor.constraint(equalToConstant: 72),

            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            hintLabel.topAnchor.constraint(equalTo: choosePhotoButton.bottomAnchor, constant: 13),

            bottomContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomContentView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 18),
            bottomContentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            segmentCollectionView.leadingAnchor.constraint(equalTo: bottomContentView.leadingAnchor),
            segmentCollectionView.trailingAnchor.constraint(equalTo: bottomContentView.trailingAnchor),
            segmentCollectionView.topAnchor.constraint(equalTo: bottomContentView.topAnchor),
            segmentCollectionView.heightAnchor.constraint(equalToConstant: 60),

            templateCollectionView.leadingAnchor.constraint(equalTo: bottomContentView.leadingAnchor),
            templateCollectionView.trailingAnchor.constraint(equalTo: bottomContentView.trailingAnchor),
            templateCollectionView.topAnchor.constraint(equalTo: segmentCollectionView.bottomAnchor),
            templateCollectionView.bottomAnchor.constraint(equalTo: bottomContentView.bottomAnchor)
        ])
    }

    private func configureNavigation() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = HomeDesignColor.text
        backButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        backButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 20, weight: .regular),
            forImageIn: .normal
        )
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        diamondPill.translatesAutoresizingMaskIntoConstraints = false
        diamondPill.backgroundColor = HomeDesignColor.accent
        diamondPill.layer.cornerRadius = 22.5
        diamondPill.clipsToBounds = true
        diamondPill.accessibilityTraits = [.button]
        diamondPill.addTarget(self, action: #selector(handleDiamondTap), for: .touchUpInside)

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.text = "💎"
        diamondIcon.font = UIFont.systemFont(ofSize: 15)
        diamondIcon.textAlignment = .center

        diamondLabel.translatesAutoresizingMaskIntoConstraints = false
        diamondLabel.textColor = HomeDesignColor.blackText
        diamondLabel.font = UIFont.systemFont(ofSize: 17.5, weight: .bold)
        diamondLabel.adjustsFontSizeToFitWidth = true
        diamondLabel.minimumScaleFactor = 0.75
        updateDiamondBalance()
    }

    private func configureHero() {
        photoPlaceholderView.translatesAutoresizingMaskIntoConstraints = false
        photoPlaceholderView.isUserInteractionEnabled = true
        photoPlaceholderView.accessibilityTraits = [.button, .image]
        let photoTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleChoosePhoto))
        photoPlaceholderView.addGestureRecognizer(photoTapGesture)

        resultPreviewView.translatesAutoresizingMaskIntoConstraints = false

        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.tintColor = HomeDesignColor.accent
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)

        choosePhotoButton.translatesAutoresizingMaskIntoConstraints = false
        choosePhotoButton.backgroundColor = HomeDesignColor.accent
        choosePhotoButton.layer.cornerRadius = 21
        choosePhotoButton.clipsToBounds = true
        choosePhotoButton.setTitle("Choose a Photo", for: .normal)
        choosePhotoButton.setTitleColor(UIColor.black, for: .normal)
        choosePhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        choosePhotoButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)

        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.text = "Use a half-body or portrait photo for best\nresults"
        hintLabel.textColor = UIColor(hex: 0x9A9AA2)
        hintLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.lineBreakMode = .byWordWrapping
    }

    private func configureBottomContent() {
        bottomContentView.translatesAutoresizingMaskIntoConstraints = false
        bottomContentView.backgroundColor = HomeDesignColor.background
        bottomContentView.clipsToBounds = true

        segmentCollectionView.translatesAutoresizingMaskIntoConstraints = false
        segmentCollectionView.backgroundColor = HomeDesignColor.background
        segmentCollectionView.showsHorizontalScrollIndicator = false
        segmentCollectionView.dataSource = self
        segmentCollectionView.delegate = self
        segmentCollectionView.register(FilterSegmentCell.self, forCellWithReuseIdentifier: FilterSegmentCell.reuseIdentifier)

        templateCollectionView.translatesAutoresizingMaskIntoConstraints = false
        templateCollectionView.backgroundColor = HomeDesignColor.background
        templateCollectionView.showsVerticalScrollIndicator = false
        templateCollectionView.dataSource = self
        templateCollectionView.delegate = self
        templateCollectionView.register(FilterTemplateCell.self, forCellWithReuseIdentifier: FilterTemplateCell.reuseIdentifier)
    }

    private func makeSegmentLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
        return layout
    }

    private func makeTemplateLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let horizontalInset: CGFloat = 28
            let spacing: CGFloat = 12.7
            let availableWidth = environment.container.effectiveContentSize.width - horizontalInset * 2 - spacing * 3
            let itemWidth = floor(availableWidth / 4)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemWidth)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(itemWidth)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, repeatingSubitem: item, count: 4)
            group.interItemSpacing = .fixed(spacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 14,
                leading: horizontalInset,
                bottom: 34,
                trailing: horizontalInset
            )
            return section
        }
    }

    private func prepareDataSource(from allCards: [ContentSection], preferredTemplateID: Int) {
        var resolvedCards = allCards
            .filter { $0.category == selectedTemplate.kind && !$0.templates.isEmpty }

        if let sourceSection, !resolvedCards.contains(where: { $0.id == sourceSection.id }) {
            resolvedCards.insert(sourceSection, at: 0)
        }

        if !resolvedCards.contains(where: { section in
            section.templates.contains(where: { $0.id == preferredTemplateID })
        }) {
            let fallbackCard = ContentSection(
                id: selectedTemplate.cardID ?? -selectedTemplate.id,
                title: selectedTemplate.kind.filterWorkflowTitle(fallback: selectedTemplate.title),
                homeStyle: 1,
                category: selectedTemplate.kind,
                templates: [selectedTemplate],
                relationCardID: nil,
                relationCardMedia: nil,
                showPositions: []
            )
            resolvedCards.insert(fallbackCard, at: 0)
        }

        cards = resolvedCards
        selectedCardIndex = cards.firstIndex { section in
            section.templates.contains(where: { $0.id == preferredTemplateID })
        } ?? 0
        selectedTemplateIndex = cards.indices.contains(selectedCardIndex)
            ? cards[selectedCardIndex].templates.firstIndex { $0.id == preferredTemplateID } ?? 0
            : 0

        if cards.indices.contains(selectedCardIndex),
           cards[selectedCardIndex].templates.indices.contains(selectedTemplateIndex) {
            selectedTemplate = cards[selectedCardIndex].templates[selectedTemplateIndex]
        }

        pendingSegmentScrollIndex = selectedCardIndex
        pendingTemplateScrollIndexPath = IndexPath(item: selectedTemplateIndex, section: 0)
        segmentCollectionView.reloadData()
        templateCollectionView.reloadData()
        scrollPendingItems()
    }

    private func updateSelectedTemplate(animated: Bool) {
        titleLabel.text = selectedTemplate.title
        resultPreviewView.configure(template: selectedTemplate)
        updateDiamondBalance()
        updatePrimaryActionState()
        templateCollectionView.reloadData()
        pendingTemplateScrollIndexPath = IndexPath(item: selectedTemplateIndex, section: 0)
        scrollPendingItems(animated: animated)
    }

    private func updateDiamondBalance() {
        let diamonds = membershipHandler.cachedMembership.diamonds
        diamondLabel.text = "\(diamonds)"
        diamondPill.accessibilityLabel = "Diamonds, \(diamonds)"
    }

    private func scrollPendingItems(animated: Bool = false) {
        if let index = pendingSegmentScrollIndex,
           cards.indices.contains(index),
           segmentCollectionView.numberOfItems(inSection: 0) > index {
            segmentCollectionView.layoutIfNeeded()
            segmentCollectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredHorizontally,
                animated: animated
            )
            pendingSegmentScrollIndex = nil
        }

        if let indexPath = pendingTemplateScrollIndexPath,
           templateCollectionView.numberOfItems(inSection: 0) > indexPath.item {
            templateCollectionView.layoutIfNeeded()
            templateCollectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: animated
            )
            pendingTemplateScrollIndexPath = nil
        }
    }

    private func observeContentCatalogChanges() {
        contentObserver = NotificationCenter.default.addObserver(
            forName: ContentNotifications.allCardsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let cards = notification.userInfo?[ContentNotificationUserInfoKey.cards] as? [ContentSection] else {
                return
            }

            Task { @MainActor in
                self.prepareDataSource(from: cards, preferredTemplateID: self.selectedTemplate.id)
                self.updateSelectedTemplate(animated: false)
            }
        }
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleDiamondTap() {
        presentDiamondStore()
    }

    @objc private func handlePrimaryAction() {
        if hasSelectedPhoto {
            analytics.record(
                AnalyticsEvent(
                    name: "filter_generation_generate_tapped",
                    properties: [
                        "template_id": "\(selectedTemplate.id)",
                        "diamonds": "\(selectedTemplate.diamondCost)"
                    ]
                )
            )
            beginGenerationWorkflow()
        } else {
            handleChoosePhoto()
        }
    }

    @objc private func handleChoosePhoto() {
        analytics.record(
            AnalyticsEvent(
                name: "filter_generation_choose_photo_tapped",
                properties: ["template_id": "\(selectedTemplate.id)"]
            )
        )
        imageSelectionCoordinator.presentImageSourceOptions(from: self) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(selectedImage):
                guard let localURL = selectedImage.localURL else {
                    self.selectedLocalPhotoURL = nil
                    self.selectedPhotoURLs = []
                    self.photoPlaceholderView.configure(image: nil)
                    self.updatePrimaryActionState()
                    self.showError("The selected image could not be prepared.")
                    return
                }
                self.selectedLocalPhotoURL = localURL
                self.selectedPhotoURLs = [localURL]
                self.photoPlaceholderView.configure(image: selectedImage.image)
                self.updatePrimaryActionState()
                self.analytics.record(
                    AnalyticsEvent(
                        name: "filter_generation_photo_selected",
                        properties: [
                            "template_id": "\(self.selectedTemplate.id)",
                            "has_local_url": "true"
                        ]
                    )
                )
            case .failure(.cancelled):
                break
            case let .failure(error):
                self.showError(error.localizedDescription)
            }
        }
    }

    private func updatePrimaryActionState() {
        if hasSelectedPhoto {
            let title = selectedTemplate.diamondCost > 0
                ? "Generate · 💎 \(selectedTemplate.diamondCost)"
                : "Generate"
            choosePhotoButton.setTitle(title, for: .normal)
            choosePhotoButton.accessibilityLabel = "Generate"
        } else {
            choosePhotoButton.setTitle("Choose a Photo", for: .normal)
            choosePhotoButton.accessibilityLabel = "Choose a Photo"
        }
    }
}

extension FilterGenerationViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === segmentCollectionView {
            return cards.count
        }
        return cards.indices.contains(selectedCardIndex) ? cards[selectedCardIndex].templates.count : 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView === segmentCollectionView {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: FilterSegmentCell.reuseIdentifier,
                for: indexPath
            ) as? FilterSegmentCell
            cell?.configure(title: cards[indexPath.item].title, isSelected: indexPath.item == selectedCardIndex)
            return cell ?? UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FilterTemplateCell.reuseIdentifier,
            for: indexPath
        ) as? FilterTemplateCell
        let template = cards[selectedCardIndex].templates[indexPath.item]
        cell?.configure(
            template: template,
            isSelected: indexPath.item == selectedTemplateIndex
        )
        return cell ?? UICollectionViewCell()
    }
}

extension FilterGenerationViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === segmentCollectionView {
            guard cards.indices.contains(indexPath.item), selectedCardIndex != indexPath.item else { return }
            selectedCardIndex = indexPath.item
            selectedTemplateIndex = 0
            pendingSegmentScrollIndex = indexPath.item
            segmentCollectionView.reloadData()
            templateCollectionView.reloadData()
            if let template = cards[selectedCardIndex].templates.first {
                selectedTemplate = template
                updateSelectedTemplate(animated: true)
            }
            analytics.record(
                AnalyticsEvent(
                    name: "filter_generation_card_selected",
                    properties: ["card_id": "\(cards[indexPath.item].id)", "title": cards[indexPath.item].title]
                )
            )
            return
        }

        guard cards.indices.contains(selectedCardIndex),
              cards[selectedCardIndex].templates.indices.contains(indexPath.item) else {
            return
        }
        selectedTemplateIndex = indexPath.item
        selectedTemplate = cards[selectedCardIndex].templates[indexPath.item]
        updateSelectedTemplate(animated: true)
        analytics.record(
            AnalyticsEvent(
                name: "filter_generation_template_selected",
                properties: ["template_id": "\(selectedTemplate.id)", "title": selectedTemplate.title]
            )
        )
    }
}

extension FilterGenerationViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        guard collectionView === segmentCollectionView else { return .zero }
        let title = cards[indexPath.item].title as NSString
        let font = UIFont.systemFont(ofSize: 19.8, weight: indexPath.item == selectedCardIndex ? .bold : .semibold)
        let width = ceil(title.size(withAttributes: [.font: font]).width) + 26
        return CGSize(width: max(58, width), height: 58)
    }
}

private final class FilterPhotoPlaceholderView: UIView {
    private let imageView = UIImageView()
    private let iconView = UIImageView(image: UIImage(systemName: "person"))
    private let titleLabel = UILabel()
    private let dashedBorderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedBorderLayer.frame = bounds
        dashedBorderLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 1, dy: 1),
            cornerRadius: 22
        ).cgPath
    }

    func configure(image: UIImage?) {
        imageView.image = image
        imageView.isHidden = image == nil
        iconView.isHidden = image != nil
        titleLabel.isHidden = image != nil
        dashedBorderLayer.isHidden = image != nil
        backgroundColor = image == nil ? UIColor.white.withAlphaComponent(0.02) : HomeDesignColor.card
    }

    private func configureView() {
        backgroundColor = UIColor.white.withAlphaComponent(0.02)
        layer.cornerRadius = 22
        clipsToBounds = true

        dashedBorderLayer.fillColor = UIColor.clear.cgColor
        dashedBorderLayer.strokeColor = UIColor.white.withAlphaComponent(0.24).cgColor
        dashedBorderLayer.lineWidth = 2
        dashedBorderLayer.lineDashPattern = [6, 4]
        layer.addSublayer(dashedBorderLayer)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true
        imageView.isHidden = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = UIColor(hex: 0xA4A4AD)
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .regular)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Your Photo"
        titleLabel.textColor = UIColor(hex: 0xA4A4AD)
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        addSubview(imageView)
        addSubview(iconView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -18),
            iconView.widthAnchor.constraint(equalToConstant: 42),
            iconView.heightAnchor.constraint(equalToConstant: 42),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 13)
        ])
    }
}

private final class FilterResultPreviewView: UIView {
    private let imageView = RemoteImageView()
    private let badgeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(template: CreativeTemplate) {
        imageView.setImage(url: template.preferredImageURL, placeholder: nil)
    }

    private func configureView() {
        backgroundColor = HomeDesignColor.card
        layer.cornerRadius = 22
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "Result"
        badgeLabel.textColor = .white
        badgeLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        badgeLabel.layer.cornerRadius = 15
        badgeLabel.clipsToBounds = true

        addSubview(imageView)
        addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            badgeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            badgeLabel.widthAnchor.constraint(equalToConstant: 64),
            badgeLabel.heightAnchor.constraint(equalToConstant: 31)
        ])
    }
}

private final class FilterSegmentCell: UICollectionViewCell {
    static let reuseIdentifier = "FilterSegmentCell"

    private let titleLabel = UILabel()
    private let indicatorView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isSelected: Bool) {
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 19.8, weight: isSelected ? .bold : .semibold)
        titleLabel.textColor = isSelected ? HomeDesignColor.text : UIColor(hex: 0x56565C)
        indicatorView.isHidden = !isSelected
    }

    private func configureView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.78

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.backgroundColor = HomeDesignColor.accent
        indicatorView.layer.cornerRadius = 1.5
        indicatorView.isHidden = true

        contentView.addSubview(titleLabel)
        contentView.addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            titleLabel.heightAnchor.constraint(equalToConstant: 32),

            indicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            indicatorView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            indicatorView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
}

private final class FilterTemplateCell: UICollectionViewCell {
    static let reuseIdentifier = "FilterTemplateCell"

    private let imageView = RemoteImageView()
    private let gradientView = FilterTemplateGradientView()
    private let titleLabel = UILabel()
    private let badgeView = UIView()
    private let badgeIcon = UIImageView(image: UIImage(systemName: "crown"))
    private let selectedMarkView = UIView()
    private let selectedMarkIcon = UIImageView(image: UIImage(systemName: "checkmark"))

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
        titleLabel.text = nil
    }

    func configure(template: CreativeTemplate, isSelected: Bool) {
        titleLabel.text = template.title
        imageView.setImage(url: template.preferredImageURL, placeholder: nil)
        titleLabel.isHidden = !isSelected
        selectedMarkView.isHidden = !isSelected
        badgeView.isHidden = isSelected || !template.requiresMembership
        contentView.layer.borderWidth = isSelected ? 2.8 : 1.4
        contentView.layer.borderColor = isSelected
            ? HomeDesignColor.accent.cgColor
            : HomeDesignColor.border.cgColor
        badgeView.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        badgeIcon.tintColor = .white
    }

    private func configureView() {
        contentView.backgroundColor = HomeDesignColor.card
        contentView.layer.cornerRadius = 19.8
        contentView.layer.borderWidth = 1.4
        contentView.layer.borderColor = HomeDesignColor.border.cgColor
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.layer.cornerRadius = 10.5
        badgeView.clipsToBounds = true

        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)

        selectedMarkView.translatesAutoresizingMaskIntoConstraints = false
        selectedMarkView.backgroundColor = HomeDesignColor.accent
        selectedMarkView.layer.cornerRadius = 10.5
        selectedMarkView.clipsToBounds = true

        selectedMarkIcon.translatesAutoresizingMaskIntoConstraints = false
        selectedMarkIcon.tintColor = UIColor.black
        selectedMarkIcon.contentMode = .scaleAspectFit
        selectedMarkIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)

        contentView.addSubview(imageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(badgeView)
        contentView.addSubview(selectedMarkView)
        badgeView.addSubview(badgeIcon)
        selectedMarkView.addSubview(selectedMarkIcon)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            badgeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            badgeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            badgeView.widthAnchor.constraint(equalToConstant: 21),
            badgeView.heightAnchor.constraint(equalToConstant: 21),

            badgeIcon.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 11),
            badgeIcon.heightAnchor.constraint(equalToConstant: 11),

            selectedMarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            selectedMarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            selectedMarkView.widthAnchor.constraint(equalToConstant: 21),
            selectedMarkView.heightAnchor.constraint(equalToConstant: 21),

            selectedMarkIcon.centerXAnchor.constraint(equalTo: selectedMarkView.centerXAnchor),
            selectedMarkIcon.centerYAnchor.constraint(equalTo: selectedMarkView.centerYAnchor),
            selectedMarkIcon.widthAnchor.constraint(equalToConstant: 11),
            selectedMarkIcon.heightAnchor.constraint(equalToConstant: 11),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 9),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}

private final class FilterTemplateGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.68).cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = bounds
        CATransaction.commit()
    }
}

private extension CreativeKind {
    func filterWorkflowTitle(fallback: String) -> String {
        switch self {
        case .filter:
            return "For You"
        case .hair:
            return "Hairstyle"
        case .cutout:
            return "Cutout"
        case .photo, .textToImage, .imageToImage:
            return "Photo"
        case .avatar:
            return "Avatar"
        case .outfit:
            return "Outfit"
        case .baby:
            return "Baby"
        case .makeup:
            return "Makeup"
        case .video, .textToVideo, .imageToVideo, .multiImageToVideo, .videoEnhance:
            return "Video"
        case .collection, .unknown:
            return fallback
        }
    }
}
