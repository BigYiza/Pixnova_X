import AVFoundation
import UIKit

final class TemplateVideoGenerationViewController: BaseGenerationWorkflowViewController {
    private let template: CreativeTemplate
    private let imageSelectionCoordinator = ImageSelectionCoordinator()
    private let pricing: GenerationParameterPricing

    private var selectedImages: [SelectedImage?]
    private var selectedSlotIndex = 0
    private var parameterCards: [VideoParameterCardView] = []
    private var popupDismissControl: UIControl?
    private var parameterPopup: VideoParameterPopupView?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let diamondPill = UIControl()
    private let diamondIcon = UILabel()
    private let diamondLabel = UILabel()
    private let previewView = VideoTemplatePreviewView()
    private let photoArea = UIStackView()
    private let parameterScrollView = UIScrollView()
    private let parameterStack = UIStackView()
    private var parameterScrollHeightConstraint: NSLayoutConstraint?
    private let generateButton = UIButton(type: .system)
    private let toastLabel = UILabel()

    init(
        template: CreativeTemplate,
        membershipHandler: MembershipHandling,
        generationRepository: GenerationRepository,
        generationWorkflowRunner: GenerationWorkflowRunning,
        analytics: AnalyticsTracking
    ) {
        self.template = template
        pricing = GenerationParameterPricing(template: template)
        selectedImages = Array(repeating: nil, count: Self.requiredImageCount(for: template))
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
        updateAllContent()
        analytics.record(
            AnalyticsEvent(
                name: "template_video_generation_opened",
                properties: ["template_id": "\(template.id)", "title": template.title]
            )
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateDiamondBalance()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            previewView.stop()
        }
    }

    override func makeGenerationWorkflowRequest() async throws -> GenerationWorkflowRequest {
        let imageInputs = selectedImages.map { selectedImage -> GenerationMediaInput in
            guard let localURL = selectedImage?.localURL else { return .empty }
            return .localImage(localURL)
        }

        let draft = GenerationDraft(
            templateID: template.id,
            mediaInputs: imageInputs,
            prompt: template.prompt,
            negativePrompt: nil,
            externalArguments: pricing.externalArguments(),
            combineConfigs: template.combineConfigs
        )

        return GenerationWorkflowRequest(
            kind: .customVideo,
            template: template,
            draft: draft,
            inputRequirement: GenerationWorkflowInputRequirement(requiredMediaCount: selectedImages.count),
            requiredDiamonds: pricing.expense,
            canRunInBackground: true
        )
    }

    override func presentGenerationMediaPicker(kind: GenerationWorkflowMediaKind, index: Int) -> Bool {
        guard kind == .image,
              let slot = photoArea.arrangedSubviews.compactMap({ $0 as? VideoPhotoSlotView }).first(where: { $0.tag == index }) else {
            return false
        }
        handlePhotoSlotTap(slot)
        return true
    }

    override func generationDidStart(task: CreationTask, request: GenerationWorkflowRequest) {
        generateButton.isEnabled = false
        generateButton.setTitle("Generating...", for: .normal)
    }

    override func generationDidFinish(task: CreationTask, request: GenerationWorkflowRequest) {
        generateButton.isEnabled = true
        updateGenerateButtonTitle()
        if let url = task.resultURL {
            previewView.configure(url: url)
        }
    }

    override func generationDidCancel() {
        generateButton.isEnabled = true
        updateGenerateButtonTitle()
    }

    override func generationDidFail(error: Error) {
        generateButton.isEnabled = true
        updateGenerateButtonTitle()
        super.generationDidFail(error: error)
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background

        configureNavigation()
        configureScrollContent()
        configurePreview()
        configurePhotoArea()
        configureParameterStack()
        configureGenerateButton()
        configureToast()
    }

    private func configureNavigation() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.tintColor = HomeDesignColor.text
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold),
            forImageIn: .normal
        )
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72

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

        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(diamondPill)
        diamondPill.addSubview(diamondIcon)
        diamondPill.addSubview(diamondLabel)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            backButton.widthAnchor.constraint(equalToConstant: 34),
            backButton.heightAnchor.constraint(equalToConstant: 34),

            diamondPill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -27),
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

            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: diamondPill.leadingAnchor, constant: -14),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor)
        ])
    }

    private func configureScrollContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = HomeDesignColor.background
        scrollView.showsVerticalScrollIndicator = false

        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 14),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func configurePreview() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewView)

        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            previewView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            previewView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewView.heightAnchor.constraint(equalTo: previewView.widthAnchor, multiplier: 1.095)
        ])
    }

    private func configurePhotoArea() {
        photoArea.translatesAutoresizingMaskIntoConstraints = false
        photoArea.axis = selectedImages.count == 1 ? .vertical : .horizontal
        photoArea.spacing = 14
        photoArea.distribution = .fillEqually
        contentView.addSubview(photoArea)

        NSLayoutConstraint.activate([
            photoArea.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            photoArea.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            photoArea.topAnchor.constraint(equalTo: previewView.bottomAnchor, constant: 18),
            photoArea.heightAnchor.constraint(equalToConstant: selectedImages.count == 1 ? 88 : 136)
        ])
    }

    private func configureParameterStack() {
        parameterScrollView.translatesAutoresizingMaskIntoConstraints = false
        parameterScrollView.showsHorizontalScrollIndicator = false
        parameterScrollView.showsVerticalScrollIndicator = false
        parameterScrollView.alwaysBounceHorizontal = false
        parameterScrollView.isScrollEnabled = false
        contentView.addSubview(parameterScrollView)

        parameterStack.translatesAutoresizingMaskIntoConstraints = false
        parameterStack.axis = .horizontal
        parameterStack.spacing = 14
        parameterStack.distribution = .fillEqually
        parameterScrollView.addSubview(parameterStack)

        let heightConstraint = parameterScrollView.heightAnchor.constraint(equalToConstant: 0)
        parameterScrollHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            parameterScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            parameterScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            parameterScrollView.topAnchor.constraint(equalTo: photoArea.bottomAnchor, constant: 14),
            heightConstraint,

            parameterStack.leadingAnchor.constraint(equalTo: parameterScrollView.contentLayoutGuide.leadingAnchor),
            parameterStack.trailingAnchor.constraint(equalTo: parameterScrollView.contentLayoutGuide.trailingAnchor),
            parameterStack.topAnchor.constraint(equalTo: parameterScrollView.contentLayoutGuide.topAnchor),
            parameterStack.bottomAnchor.constraint(equalTo: parameterScrollView.contentLayoutGuide.bottomAnchor),
            parameterStack.widthAnchor.constraint(equalTo: parameterScrollView.frameLayoutGuide.widthAnchor),
            parameterStack.heightAnchor.constraint(equalTo: parameterScrollView.frameLayoutGuide.heightAnchor)
        ])
    }

    private func configureGenerateButton() {
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.backgroundColor = HomeDesignColor.accent
        generateButton.layer.cornerRadius = 21
        generateButton.clipsToBounds = true
        generateButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        generateButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)
        generateButton.addTarget(self, action: #selector(handleGenerate), for: .touchUpInside)
        contentView.addSubview(generateButton)

        NSLayoutConstraint.activate([
            generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            generateButton.topAnchor.constraint(equalTo: parameterScrollView.bottomAnchor, constant: 14),
            generateButton.heightAnchor.constraint(equalToConstant: 72),
            generateButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -34)
        ])
    }

    private func configureToast() {
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        toastLabel.textColor = .white
        toastLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.numberOfLines = 2
        toastLabel.layer.cornerRadius = 14
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        view.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            toastLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
            toastLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    private func updateAllContent() {
        titleLabel.text = template.title
        updateDiamondBalance()
        previewView.configure(url: template.preferredVideoURL)
        rebuildPhotoSlots()
        rebuildParameterCards()
        updateGenerateButtonTitle()
    }

    private func updateDiamondBalance() {
        let diamonds = membershipHandler.cachedMembership.diamonds
        diamondLabel.text = "\(diamonds)"
        diamondPill.accessibilityLabel = "Diamonds, \(diamonds)"
    }

    private func rebuildPhotoSlots() {
        photoArea.arrangedSubviews.forEach { view in
            photoArea.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for index in selectedImages.indices {
            let slot = VideoPhotoSlotView()
            slot.configure(
                title: selectedImages.count == 1 ? "Choose a photo" : "Face \(index + 1)",
                image: selectedImages[index]?.image,
                compact: selectedImages.count > 1
            )
            slot.tag = index
            slot.addTarget(self, action: #selector(handlePhotoSlotTap(_:)), for: .touchUpInside)
            photoArea.addArrangedSubview(slot)
        }
    }

    private func rebuildParameterCards() {
        parameterStack.arrangedSubviews.forEach { view in
            parameterStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        parameterCards = []

        guard pricing.hasParameters else {
            parameterScrollHeightConstraint?.constant = 0
            return
        }

        let parameterCount = pricing.selections.count
        parameterScrollHeightConstraint?.constant = parameterCount >= 4 ? 48 : 54
        parameterStack.spacing = Self.parameterCardSpacing(for: parameterCount)

        for (index, selection) in pricing.selections.enumerated() {
            let card = VideoParameterCardView()
            card.configure(selection: selection)
            card.tag = index
            card.addTarget(self, action: #selector(handleParameterTap(_:)), for: .touchUpInside)
            parameterStack.addArrangedSubview(card)
            parameterCards.append(card)
        }
    }

    private func updateParameterCards() {
        for (index, card) in parameterCards.enumerated() where pricing.selections.indices.contains(index) {
            card.configure(selection: pricing.selections[index])
        }
    }

    private func updateGenerateButtonTitle() {
        let title = NSAttributedString(
            string: "💎 Generate · \(pricing.expense)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 20.5, weight: .bold),
                .foregroundColor: HomeDesignColor.blackText
            ]
        )
        generateButton.setAttributedTitle(title, for: .normal)
    }

    private func showParameterPopup(for index: Int, sourceView: UIView) {
        dismissParameterPopup()

        guard pricing.selections.indices.contains(index) else { return }

        let dismissControl = UIControl(frame: view.bounds)
        dismissControl.backgroundColor = .clear
        dismissControl.addTarget(self, action: #selector(dismissParameterPopup), for: .touchUpInside)
        view.addSubview(dismissControl)
        popupDismissControl = dismissControl

        let popup = VideoParameterPopupView()
        popup.configure(selection: pricing.selections[index])
        popup.onSelect = { [weak self] valueIndex in
            guard let self else { return }
            self.pricing.select(parameterIndex: index, valueIndex: valueIndex)
            self.updateParameterCards()
            self.updateGenerateButtonTitle()
            if let toast = self.pricing.consumeToastMessage() {
                self.showToast(toast)
            }
            self.dismissParameterPopup()
        }
        popup.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(popup)
        parameterPopup = popup

        view.layoutIfNeeded()
        let sourceFrame = sourceView.convert(sourceView.bounds, to: view)
        let popupWidth: CGFloat = min(244, view.bounds.width - 56)
        let popupHeight = popup.preferredHeight
        let x = max(28, min(sourceFrame.minX, view.bounds.width - popupWidth - 28))
        var y = sourceFrame.minY - popupHeight - 8
        if y < view.safeAreaInsets.top + 16 {
            y = sourceFrame.maxY + 8
        }

        NSLayoutConstraint.activate([
            popup.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: x),
            popup.topAnchor.constraint(equalTo: view.topAnchor, constant: y),
            popup.widthAnchor.constraint(equalToConstant: popupWidth),
            popup.heightAnchor.constraint(equalToConstant: popupHeight)
        ])
    }

    @objc private func dismissParameterPopup() {
        parameterPopup?.removeFromSuperview()
        popupDismissControl?.removeFromSuperview()
        parameterPopup = nil
        popupDismissControl = nil
    }

    private func showToast(_ message: String) {
        toastLabel.text = message
        UIView.animate(withDuration: 0.18) {
            self.toastLabel.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.22, delay: 2.2, options: [.curveEaseInOut]) {
                self.toastLabel.alpha = 0
            }
        }
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleDiamondTap() {
        presentDiamondStore()
    }

    @objc private func handlePhotoSlotTap(_ sender: VideoPhotoSlotView) {
        selectedSlotIndex = sender.tag
        imageSelectionCoordinator.presentImageSourceOptions(from: self) { [weak self] result in
            guard let self else { return }

            switch result {
            case let .success(selectedImage):
                guard selectedImage.localURL != nil else {
                    self.showError("The selected image could not be prepared.")
                    return
                }
                self.selectedImages[self.selectedSlotIndex] = selectedImage
                self.rebuildPhotoSlots()
            case .failure(.cancelled):
                break
            case let .failure(error):
                if let description = error.errorDescription {
                    self.showError(description)
                }
            }
        }
    }

    @objc private func handleParameterTap(_ sender: VideoParameterCardView) {
        showParameterPopup(for: sender.tag, sourceView: sender)
    }

    @objc private func handleGenerate() {
        beginGenerationWorkflow()
    }

    private static func requiredImageCount(for template: CreativeTemplate) -> Int {
        let inputCount = template.inputRequirement?.imageCount

        if template.kind == .multiImageToVideo {
            return min(max(inputCount ?? 2, 1), 2)
        }

        return min(max(inputCount ?? 1, 1), 2)
    }

    private static func parameterCardSpacing(for count: Int) -> CGFloat {
        switch count {
        case 0...2:
            return 14
        case 3:
            return 10
        default:
            return 8
        }
    }
}

private final class VideoTemplatePreviewView: UIView {
    private let imageView = RemoteImageView()
    private let playerLayer = AVPlayerLayer()
    private let tapControl = UIControl()
    private let playButton = UIControl()
    private let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
    private let muteButton = UIControl()
    private let muteIcon = UIImageView(image: UIImage(systemName: "speaker.slash.fill"))
    private var player: AVPlayer?
    private var currentVideoURL: URL?
    private var playbackEndObserver: NSObjectProtocol?
    private var didReachEnd = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func configure(url: URL?) {
        stop()
        imageView.setImage(url: nil, placeholder: nil)
        playButton.isHidden = true
        muteButton.isHidden = true
        tapControl.isHidden = true
        currentVideoURL = nil

        guard let url else { return }

        if Self.isVideoURL(url) {
            currentVideoURL = url
            print("[TemplateVideoGeneration] video resource URL: \(url.absoluteString)")
            imageView.isHidden = true
            playerLayer.isHidden = false
            let player = AVPlayer(url: url)
            player.isMuted = true
            playerLayer.player = player
            self.player = player
            playbackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.handlePlaybackEnded()
            }
            didReachEnd = false
            playButton.isHidden = false
            tapControl.isHidden = false
            updatePlaybackControls(isPlaying: false)
        } else {
            playerLayer.isHidden = true
            imageView.isHidden = false
            imageView.setImage(url: url, placeholder: nil)
        }
    }

    func stop() {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
        player?.pause()
        playerLayer.player = nil
        player = nil
        currentVideoURL = nil
        didReachEnd = false
    }

    private func configureView() {
        backgroundColor = UIColor(hex: 0x0B0B0D)
        layer.cornerRadius = 25
        clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor(hex: 0x0B0B0D)

        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)

        tapControl.translatesAutoresizingMaskIntoConstraints = false
        tapControl.addTarget(self, action: #selector(handlePlayTap), for: .touchUpInside)
        tapControl.isHidden = true

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        playButton.layer.cornerRadius = 41
        playButton.clipsToBounds = true
        playButton.addTarget(self, action: #selector(handlePlayTap), for: .touchUpInside)
        playButton.isHidden = true

        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit
        playIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)

        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        muteButton.layer.cornerRadius = 24
        muteButton.clipsToBounds = true
        muteButton.isUserInteractionEnabled = false
        muteButton.isHidden = true

        muteIcon.translatesAutoresizingMaskIntoConstraints = false
        muteIcon.tintColor = .white
        muteIcon.contentMode = .scaleAspectFit
        muteIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)

        addSubview(imageView)
        addSubview(tapControl)
        addSubview(playButton)
        addSubview(muteButton)
        playButton.addSubview(playIcon)
        muteButton.addSubview(muteIcon)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tapControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            tapControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            tapControl.topAnchor.constraint(equalTo: topAnchor),
            tapControl.bottomAnchor.constraint(equalTo: bottomAnchor),

            playButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 82),
            playButton.heightAnchor.constraint(equalToConstant: 82),

            playIcon.centerXAnchor.constraint(equalTo: playButton.centerXAnchor, constant: 2),
            playIcon.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 34),
            playIcon.heightAnchor.constraint(equalToConstant: 34),

            muteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 24),
            muteButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -17),
            muteButton.widthAnchor.constraint(equalToConstant: 48),
            muteButton.heightAnchor.constraint(equalToConstant: 48),

            muteIcon.centerXAnchor.constraint(equalTo: muteButton.centerXAnchor),
            muteIcon.centerYAnchor.constraint(equalTo: muteButton.centerYAnchor),
            muteIcon.widthAnchor.constraint(equalToConstant: 21),
            muteIcon.heightAnchor.constraint(equalToConstant: 21)
        ])
    }

    @objc private func handlePlayTap() {
        guard let player else { return }

        if player.timeControlStatus == .playing {
            player.pause()
            updatePlaybackControls(isPlaying: false)
            return
        }

        if didReachEnd {
            player.seek(to: .zero)
            didReachEnd = false
        }

        if let currentVideoURL {
            print("[TemplateVideoGeneration] play video URL: \(currentVideoURL.absoluteString)")
        }
        player.play()
        updatePlaybackControls(isPlaying: true)
    }

    private func handlePlaybackEnded() {
        didReachEnd = true
        updatePlaybackControls(isPlaying: false)
    }

    private func updatePlaybackControls(isPlaying: Bool) {
        playIcon.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
        playButton.alpha = isPlaying ? 0 : 1
        muteIcon.image = UIImage(systemName: player?.isMuted == false ? "speaker.wave.2.fill" : "speaker.slash.fill")
    }

    private static func isVideoURL(_ url: URL) -> Bool {
        ["mp4", "mov", "m4v", "webm"].contains(url.pathExtension.lowercased())
    }
}

private final class VideoPhotoSlotView: UIControl {
    private let imageView = UIImageView()
    private let contentStack = UIStackView()
    private let iconView = UIImageView(image: UIImage(systemName: "plus"))
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
            cornerRadius: 21
        ).cgPath
    }

    func configure(title: String, image: UIImage?, compact: Bool) {
        titleLabel.text = title
        imageView.image = image
        imageView.isHidden = image == nil
        contentStack.isHidden = image != nil
        dashedBorderLayer.isHidden = image != nil
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: compact ? 23 : 21,
            weight: .semibold
        )
    }

    private func configureView() {
        backgroundColor = UIColor.white.withAlphaComponent(0.02)
        layer.cornerRadius = 21
        clipsToBounds = true

        dashedBorderLayer.fillColor = UIColor.clear.cgColor
        dashedBorderLayer.strokeColor = UIColor.white.withAlphaComponent(0.24).cgColor
        dashedBorderLayer.lineWidth = 1.2
        dashedBorderLayer.lineDashPattern = [4, 3]
        layer.addSublayer(dashedBorderLayer)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.distribution = .fill
        contentStack.spacing = 11
        contentStack.isUserInteractionEnabled = false

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = UIColor(hex: 0x9A9AA2)
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = UIColor(hex: 0x9A9AA2)
        titleLabel.font = UIFont.systemFont(ofSize: 17.2, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        addSubview(imageView)
        addSubview(contentStack)
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            iconView.widthAnchor.constraint(equalToConstant: 25),
            iconView.heightAnchor.constraint(equalToConstant: 25)
        ])
    }
}

private final class VideoParameterCardView: UIControl {
    private let titleLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.down"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(selection: GenerationParameterSelection) {
        titleLabel.text = selection.selectedValue?.label ?? selection.parameter.title
    }

    private func configureView() {
        backgroundColor = UIColor.white.withAlphaComponent(0.06)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.09).cgColor
        clipsToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.58
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = HomeDesignColor.text
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10.5, weight: .bold)
        chevronView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleLabel)
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -7),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),

            chevronView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 5),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -9),
            chevronView.widthAnchor.constraint(equalToConstant: 12),
            chevronView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
}

private final class VideoParameterPopupView: UIVisualEffectView {
    var onSelect: ((Int) -> Void)?
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    private var selection: GenerationParameterSelection?

    var preferredHeight: CGFloat {
        CGFloat(48 + max(selection?.parameter.values.count ?? 0, 1) * 64)
    }

    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(selection: GenerationParameterSelection) {
        self.selection = selection
        titleLabel.text = selection.parameter.title.uppercased()
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for (index, value) in selection.parameter.values.enumerated() {
            let row = VideoParameterPopupRow()
            row.configure(value: value, isSelected: index == selection.selectedIndex)
            row.tag = index
            row.addTarget(self, action: #selector(handleRowTap(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 64).isActive = true
        }
    }

    private func configureView() {
        backgroundColor = UIColor(hex: 0x1C1C20).withAlphaComponent(0.82)
        layer.cornerRadius = 22
        layer.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = UIColor(hex: 0x56565C)
        titleLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        titleLabel.letterSpacing = 0.9

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill

        contentView.addSubview(titleLabel)
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 21),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -21),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 17),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func handleRowTap(_ sender: VideoParameterPopupRow) {
        onSelect?(sender.tag)
    }
}

private final class VideoParameterPopupRow: UIControl {
    private let label = UILabel()
    private let diamondIcon = UILabel()
    private let timesLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(value: GenerationParameterValue, isSelected: Bool) {
        let color = isSelected ? HomeDesignColor.accent : HomeDesignColor.text
        label.text = value.label
        label.textColor = color
        timesLabel.text = "×\(value.times)"
        timesLabel.textColor = isSelected ? HomeDesignColor.accent : UIColor(hex: 0x9A9AA2)
    }

    private func configureView() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 19.5, weight: .semibold)

        diamondIcon.translatesAutoresizingMaskIntoConstraints = false
        diamondIcon.text = "💎"
        diamondIcon.font = UIFont.systemFont(ofSize: 14)
        diamondIcon.textAlignment = .center

        timesLabel.translatesAutoresizingMaskIntoConstraints = false
        timesLabel.font = UIFont.systemFont(ofSize: 19.5, weight: .semibold)
        timesLabel.textAlignment = .right

        addSubview(label)
        addSubview(diamondIcon)
        addSubview(timesLabel)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 21),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: diamondIcon.leadingAnchor, constant: -10),

            timesLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -21),
            timesLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            diamondIcon.trailingAnchor.constraint(equalTo: timesLabel.leadingAnchor, constant: -8),
            diamondIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            diamondIcon.widthAnchor.constraint(equalToConstant: 22),
            diamondIcon.heightAnchor.constraint(equalToConstant: 22)
        ])
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
