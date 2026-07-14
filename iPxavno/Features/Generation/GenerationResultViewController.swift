import AVFoundation
import Photos
import UIKit

final class GenerationResultViewController: BaseViewController {
    var onUseTemplateAgain: (() -> Void)?

    private let template: CreativeTemplate
    private let resultURL: URL
    private let mediaKind: GenerationResultMediaKind

    private let backButton = UIButton(type: .system)
    private let topSaveButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let mediaView = GenerationResultMediaView()
    private let saveButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let templateButton = UIButton(type: .system)
    private let toastView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let toastIconView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
    private let toastLabel = UILabel()

    private var saveTask: Task<Void, Never>?

    init(template: CreativeTemplate, resultURL: URL) {
        self.template = template
        self.resultURL = resultURL
        self.mediaKind = GenerationResultMediaKind(url: resultURL)
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
        mediaView.configure(url: resultURL, kind: mediaKind)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = navigationController?.viewControllers.count ?? 0 > 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mediaView.pause()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = navigationController?.viewControllers.count ?? 0 > 1
        mediaView.play()
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background
        configureNavigation()
        configureMedia()
        configureActions()
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

        topSaveButton.translatesAutoresizingMaskIntoConstraints = false
        topSaveButton.tintColor = HomeDesignColor.text
        topSaveButton.setImage(UIImage(systemName: "square.and.arrow.down"), for: .normal)
        topSaveButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold),
            forImageIn: .normal
        )
        topSaveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Result"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center

        view.addSubview(backButton)
        view.addSubview(topSaveButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            backButton.widthAnchor.constraint(equalToConstant: 38),
            backButton.heightAnchor.constraint(equalToConstant: 38),

            topSaveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            topSaveButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            topSaveButton.widthAnchor.constraint(equalToConstant: 38),
            topSaveButton.heightAnchor.constraint(equalToConstant: 38),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: topSaveButton.leadingAnchor, constant: -16)
        ])
    }

    private func configureMedia() {
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.backgroundColor = HomeDesignColor.card
        mediaView.layer.cornerRadius = 20
        mediaView.layer.borderWidth = 1
        mediaView.layer.borderColor = HomeDesignColor.border.cgColor
        mediaView.clipsToBounds = true
        view.addSubview(mediaView)

        let aspectConstraint = mediaView.heightAnchor.constraint(equalTo: mediaView.widthAnchor, multiplier: 1.18)
        aspectConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            mediaView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            mediaView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            mediaView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.48),
            mediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            aspectConstraint
        ])
    }

    private func configureActions() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        configureActionButton(
            saveButton,
            title: "Save",
            imageName: "square.and.arrow.down",
            foregroundColor: HomeDesignColor.blackText,
            backgroundColor: HomeDesignColor.accent,
            borderColor: nil
        )
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)

        shareButton.translatesAutoresizingMaskIntoConstraints = false
        configureActionButton(
            shareButton,
            title: "Share",
            imageName: "square.and.arrow.up",
            foregroundColor: HomeDesignColor.text,
            backgroundColor: UIColor.white.withAlphaComponent(0.06),
            borderColor: HomeDesignColor.border
        )
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)

        templateButton.translatesAutoresizingMaskIntoConstraints = false
        configureActionButton(
            templateButton,
            title: "Use this template again",
            imageName: nil,
            foregroundColor: HomeDesignColor.text,
            backgroundColor: UIColor.white.withAlphaComponent(0.06),
            borderColor: HomeDesignColor.border
        )
        templateButton.addTarget(self, action: #selector(handleUseTemplateAgain), for: .touchUpInside)

        let actionsStack = UIStackView(arrangedSubviews: [saveButton, shareButton])
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.axis = .horizontal
        actionsStack.distribution = .fillEqually
        actionsStack.spacing = 12

        view.addSubview(actionsStack)
        view.addSubview(templateButton)

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 18),
            actionsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            actionsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            actionsStack.heightAnchor.constraint(equalToConstant: 64),

            templateButton.topAnchor.constraint(equalTo: actionsStack.bottomAnchor, constant: 22),
            templateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            templateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            templateButton.heightAnchor.constraint(equalToConstant: 64),
            templateButton.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110)
        ])
    }

    private func configureActionButton(
        _ button: UIButton,
        title: String,
        imageName: String?,
        foregroundColor: UIColor,
        backgroundColor: UIColor,
        borderColor: UIColor?
    ) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = imageName.flatMap { UIImage(systemName: $0) }
        configuration.imagePadding = imageName == nil ? 0 : 8
        configuration.baseForegroundColor = foregroundColor
        configuration.baseBackgroundColor = backgroundColor
        configuration.cornerStyle = .large
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        button.configuration = configuration
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 21
        button.clipsToBounds = true
        if let borderColor {
            button.layer.borderWidth = 1
            button.layer.borderColor = borderColor.cgColor
        }
    }

    private func configureToast() {
        toastView.translatesAutoresizingMaskIntoConstraints = false
        toastView.alpha = 0
        toastView.layer.cornerRadius = 17
        toastView.clipsToBounds = true
        toastView.layer.borderWidth = 1
        toastView.layer.borderColor = HomeDesignColor.border.cgColor

        toastIconView.translatesAutoresizingMaskIntoConstraints = false
        toastIconView.tintColor = HomeDesignColor.accent

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        toastLabel.text = "Saved to Photos - no watermark"
        toastLabel.textColor = HomeDesignColor.text
        toastLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        toastLabel.adjustsFontSizeToFitWidth = true
        toastLabel.minimumScaleFactor = 0.8

        view.addSubview(toastView)
        toastView.contentView.addSubview(toastIconView)
        toastView.contentView.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            toastView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -42),
            toastView.heightAnchor.constraint(equalToConstant: 61),

            toastIconView.leadingAnchor.constraint(equalTo: toastView.contentView.leadingAnchor, constant: 22),
            toastIconView.centerYAnchor.constraint(equalTo: toastView.contentView.centerYAnchor),
            toastIconView.widthAnchor.constraint(equalToConstant: 22),
            toastIconView.heightAnchor.constraint(equalToConstant: 22),

            toastLabel.leadingAnchor.constraint(equalTo: toastIconView.trailingAnchor, constant: 12),
            toastLabel.trailingAnchor.constraint(equalTo: toastView.contentView.trailingAnchor, constant: -22),
            toastLabel.centerYAnchor.constraint(equalTo: toastView.contentView.centerYAnchor)
        ])
    }

    private func setSaving(_ isSaving: Bool) {
        saveButton.isEnabled = !isSaving
        topSaveButton.isEnabled = !isSaving
        saveButton.alpha = isSaving ? 0.72 : 1
        topSaveButton.alpha = isSaving ? 0.55 : 1
        setLoading(isSaving)
    }

    private func showSavedToast() {
        view.bringSubviewToFront(toastView)
        UIView.animate(withDuration: 0.22) {
            self.toastView.alpha = 1
            self.toastView.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 1.8, options: [.curveEaseInOut]) {
                self.toastView.alpha = 0
            }
        }
    }

    @objc private func handleBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleSave() {
        guard saveTask == nil else { return }
        setSaving(true)

        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await GenerationResultPhotoSaver.save(url: resultURL, preferredKind: mediaKind)
                await MainActor.run {
                    self.showSavedToast()
                    self.setSaving(false)
                    self.saveTask = nil
                }
            } catch {
                await MainActor.run {
                    self.setSaving(false)
                    self.saveTask = nil
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func handleShare() {
        let activityController = UIActivityViewController(activityItems: [resultURL], applicationActivities: nil)
        if let popover = activityController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityController, animated: true)
    }

    @objc private func handleUseTemplateAgain() {
        onUseTemplateAgain?()
    }
}

enum GenerationResultMediaKind {
    case image
    case video

    init(url: URL, mimeType: String? = nil) {
        if let mimeType {
            if mimeType.lowercased().hasPrefix("video/") {
                self = .video
                return
            }
            if mimeType.lowercased().hasPrefix("image/") {
                self = .image
                return
            }
        }

        let pathExtension = url.pathExtension.lowercased()
        if Self.videoExtensions.contains(pathExtension) {
            self = .video
        } else {
            self = .image
        }
    }

    var resourceType: PHAssetResourceType {
        switch self {
        case .image:
            return .photo
        case .video:
            return .video
        }
    }

    var defaultPathExtension: String {
        switch self {
        case .image:
            return "jpg"
        case .video:
            return "mp4"
        }
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "webm"]
}

private final class GenerationResultMediaView: UIView {
    private let imageView = RemoteImageView()
    private let videoView = GenerationResultVideoView()
    private let overlayView = UIView()
    private let playIconContainer = UIView()
    private let playIconView = UIImageView(image: UIImage(systemName: "play.fill"))
    private var endObserver: NSObjectProtocol?
    private var player: AVPlayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func configure(url: URL, kind: GenerationResultMediaKind) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }

        switch kind {
        case .image:
            player?.pause()
            player = nil
            videoView.player = nil
            videoView.isHidden = true
            playIconContainer.isHidden = true
            imageView.isHidden = false
            imageView.setImage(url: url, placeholder: UIImage(systemName: "photo"))
        case .video:
            imageView.isHidden = true
            videoView.isHidden = false
            playIconContainer.isHidden = false
            let player = AVPlayer(url: url)
            player.isMuted = true
            videoView.player = player
            self.player = player
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
            player.play()
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    private func configureView() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.tintColor = HomeDesignColor.accent.withAlphaComponent(0.5)
        imageView.backgroundColor = HomeDesignColor.card

        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.videoGravity = .resizeAspectFill
        videoView.backgroundColor = .black

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.18)

        playIconContainer.translatesAutoresizingMaskIntoConstraints = false
        playIconContainer.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        playIconContainer.layer.cornerRadius = 34
        playIconContainer.clipsToBounds = true
        playIconContainer.isHidden = true

        playIconView.translatesAutoresizingMaskIntoConstraints = false
        playIconView.tintColor = .white

        addSubview(imageView)
        addSubview(videoView)
        addSubview(overlayView)
        addSubview(playIconContainer)
        playIconContainer.addSubview(playIconView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            videoView.topAnchor.constraint(equalTo: topAnchor),
            videoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor),

            playIconContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            playIconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            playIconContainer.widthAnchor.constraint(equalToConstant: 68),
            playIconContainer.heightAnchor.constraint(equalToConstant: 68),

            playIconView.centerXAnchor.constraint(equalTo: playIconContainer.centerXAnchor, constant: 2),
            playIconView.centerYAnchor.constraint(equalTo: playIconContainer.centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 26),
            playIconView.heightAnchor.constraint(equalToConstant: 26)
        ])
    }
}

private final class GenerationResultVideoView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    var videoGravity: AVLayerVideoGravity {
        get {
            playerLayer.videoGravity
        }
        set {
            playerLayer.videoGravity = newValue
        }
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private enum GenerationResultPhotoSaver {
    static func save(url: URL, preferredKind: GenerationResultMediaKind) async throws {
        guard await requestAddAuthorization() else {
            throw AppError.server(
                message: "Allow Photos access to save generated results.",
                code: 0
            )
        }

        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        let responseKind = GenerationResultMediaKind(url: url, mimeType: response.mimeType)
        let kind = response.mimeType == nil ? preferredKind : responseKind
        let localURL = try moveDownloadedFile(downloadedURL, sourceURL: url, kind: kind)
        defer {
            try? FileManager.default.removeItem(at: localURL)
        }

        try await performPhotoLibraryChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: kind.resourceType, fileURL: localURL, options: options)
        }
    }

    private static func requestAddAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let requestedStatus = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    continuation.resume(returning: status)
                }
            }
            return requestedStatus == .authorized || requestedStatus == .limited
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func moveDownloadedFile(
        _ downloadedURL: URL,
        sourceURL: URL,
        kind: GenerationResultMediaKind
    ) throws -> URL {
        let pathExtension = sourceURL.pathExtension.isEmpty
            ? kind.defaultPathExtension
            : sourceURL.pathExtension
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: downloadedURL, to: destinationURL)
        return destinationURL
    }

    private static func performPhotoLibraryChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: AppError.invalidResponse)
                }
            }
        }
    }
}
