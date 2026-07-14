import AVFoundation
import Photos
import PhotosUI
import UIKit

struct SelectedImage {
    let image: UIImage
    let localURL: URL?
}

enum ImageSelectionError: LocalizedError {
    case cancelled
    case cameraUnavailable
    case permissionDenied(source: ImageSelectionCoordinator.Source)
    case loadFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .cameraUnavailable:
            return "Camera is not available on this device."
        case let .permissionDenied(source):
            return "\(source.permissionTitle) permission is required."
        case .loadFailed:
            return "The selected image could not be loaded."
        }
    }
}

final class ImageSelectionCoordinator: NSObject {
    enum Source {
        case camera
        case photoLibrary

        var title: String {
            switch self {
            case .camera:
                return "Camera"
            case .photoLibrary:
                return "Photo Library"
            }
        }

        var permissionTitle: String {
            switch self {
            case .camera:
                return "Camera"
            case .photoLibrary:
                return "Photo library"
            }
        }
    }

    private weak var presentingViewController: UIViewController?
    private var completion: ((Result<SelectedImage, ImageSelectionError>) -> Void)?

    func presentImageSourceOptions(
        from viewController: UIViewController,
        allowsCamera: Bool = true,
        completion: @escaping (Result<SelectedImage, ImageSelectionError>) -> Void
    ) {
        presentingViewController = viewController
        self.completion = completion

        var sources: [Source] = [.photoLibrary]
        if allowsCamera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            sources.append(.camera)
        }

        let sheet = ImageSourceActionSheetViewController(sources: sources)
        sheet.onSelect = { [weak self, weak viewController] source in
            guard let self, let viewController else { return }
            switch source {
            case .photoLibrary:
                self.presentPhotoLibrary(from: viewController, completion: completion)
            case .camera:
                self.presentCamera(from: viewController, completion: completion)
            }
        }
        sheet.onCancel = { [weak self] in
            self?.finish(.failure(.cancelled))
        }
        viewController.present(sheet, animated: false)
    }

    func presentPhotoLibrary(
        from viewController: UIViewController,
        completion: @escaping (Result<SelectedImage, ImageSelectionError>) -> Void
    ) {
        presentingViewController = viewController
        self.completion = completion

        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            showPhotoLibraryPicker(from: viewController)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self, weak viewController] status in
                DispatchQueue.main.async {
                    guard let self, let viewController else { return }
                    self.handlePhotoLibraryAuthorization(status, from: viewController)
                }
            }
        case .denied, .restricted:
            presentSettingsAlert(for: .photoLibrary, from: viewController)
        @unknown default:
            presentSettingsAlert(for: .photoLibrary, from: viewController)
        }
    }

    func presentCamera(
        from viewController: UIViewController,
        completion: @escaping (Result<SelectedImage, ImageSelectionError>) -> Void
    ) {
        presentingViewController = viewController
        self.completion = completion

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            finish(.failure(.cameraUnavailable))
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraPicker(from: viewController)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self, weak viewController] granted in
                DispatchQueue.main.async {
                    guard let self, let viewController else { return }
                    if granted {
                        self.showCameraPicker(from: viewController)
                    } else {
                        self.presentSettingsAlert(for: .camera, from: viewController)
                    }
                }
            }
        case .denied, .restricted:
            presentSettingsAlert(for: .camera, from: viewController)
        @unknown default:
            presentSettingsAlert(for: .camera, from: viewController)
        }
    }

    private func handlePhotoLibraryAuthorization(
        _ status: PHAuthorizationStatus,
        from viewController: UIViewController
    ) {
        switch status {
        case .authorized, .limited:
            showPhotoLibraryPicker(from: viewController)
        case .denied, .restricted, .notDetermined:
            presentSettingsAlert(for: .photoLibrary, from: viewController)
        @unknown default:
            presentSettingsAlert(for: .photoLibrary, from: viewController)
        }
    }

    private func showPhotoLibraryPicker(from viewController: UIViewController) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    private func showCameraPicker(from viewController: UIViewController) {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        picker.allowsEditing = false
        picker.delegate = self
        viewController.present(picker, animated: true)
    }

    private func presentSettingsAlert(for source: Source, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "\(source.permissionTitle) Permission Needed",
            message: "Enable \(source.permissionTitle.lowercased()) access in Settings to choose a photo.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(.failure(.permissionDenied(source: source)))
        })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { [weak self] _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                self?.finish(.failure(.permissionDenied(source: source)))
                return
            }
            UIApplication.shared.open(settingsURL)
            self?.finish(.failure(.permissionDenied(source: source)))
        })
        viewController.present(alert, animated: true)
    }

    private func finish(_ result: Result<SelectedImage, ImageSelectionError>) {
        let completion = completion
        self.completion = nil
        completion?(result)
    }

    private func selectedImage(from image: UIImage) -> SelectedImage {
        SelectedImage(image: image, localURL: writeTemporaryJPEG(from: image))
    }

    private func writeTemporaryJPEG(from image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("selected-image-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private final class ImageSourceActionSheetViewController: UIViewController {
    var onSelect: ((ImageSelectionCoordinator.Source) -> Void)?
    var onCancel: (() -> Void)?

    private let sources: [ImageSelectionCoordinator.Source]
    private let dimmingView = UIControl()
    private let panelView = UIView()
    private let grabberView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let optionGroupView = UIView()
    private let optionStackView = UIStackView()
    private let cancelButton = UIButton(type: .system)
    private var panelBottomConstraint: NSLayoutConstraint?
    private var didChooseSource = false

    init(sources: [ImageSelectionCoordinator.Source]) {
        self.sources = sources
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
        buildOptions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPanel()
    }

    private func configureView() {
        view.backgroundColor = .clear

        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        dimmingView.alpha = 0
        dimmingView.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = UIColor(hex: 0x111113)
        panelView.layer.cornerRadius = 24
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panelView.clipsToBounds = true

        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        grabberView.layer.cornerRadius = 2

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Choose Photo"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.text = "Select an image source"
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.55)
        messageLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        messageLabel.textAlignment = .center

        optionGroupView.translatesAutoresizingMaskIntoConstraints = false
        optionGroupView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        optionGroupView.layer.cornerRadius = 16
        optionGroupView.clipsToBounds = true

        optionStackView.translatesAutoresizingMaskIntoConstraints = false
        optionStackView.axis = .vertical
        optionStackView.spacing = 0
        optionStackView.distribution = .fill

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        cancelButton.layer.cornerRadius = 16
        cancelButton.clipsToBounds = true
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)

        view.addSubview(dimmingView)
        view.addSubview(panelView)
        panelView.addSubview(grabberView)
        panelView.addSubview(titleLabel)
        panelView.addSubview(messageLabel)
        panelView.addSubview(optionGroupView)
        optionGroupView.addSubview(optionStackView)
        panelView.addSubview(cancelButton)

        panelBottomConstraint = panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 320)

        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelBottomConstraint!,

            grabberView.topAnchor.constraint(equalTo: panelView.topAnchor, constant: 10),
            grabberView.centerXAnchor.constraint(equalTo: panelView.centerXAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 38),
            grabberView.heightAnchor.constraint(equalToConstant: 4),

            titleLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -24),
            titleLabel.topAnchor.constraint(equalTo: grabberView.bottomAnchor, constant: 18),

            messageLabel.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -24),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),

            optionGroupView.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            optionGroupView.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            optionGroupView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 18),

            optionStackView.leadingAnchor.constraint(equalTo: optionGroupView.leadingAnchor),
            optionStackView.trailingAnchor.constraint(equalTo: optionGroupView.trailingAnchor),
            optionStackView.topAnchor.constraint(equalTo: optionGroupView.topAnchor),
            optionStackView.bottomAnchor.constraint(equalTo: optionGroupView.bottomAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: panelView.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: panelView.trailingAnchor, constant: -16),
            cancelButton.topAnchor.constraint(equalTo: optionGroupView.bottomAnchor, constant: 10),
            cancelButton.heightAnchor.constraint(equalToConstant: 58),
            cancelButton.bottomAnchor.constraint(equalTo: panelView.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func buildOptions() {
        for (index, source) in sources.enumerated() {
            if index > 0 {
                let separator = UIView()
                separator.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                optionStackView.addArrangedSubview(separator)
                separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
            }

            let row = ImageSourceActionRow(source: source)
            row.addTarget(self, action: #selector(handleSourceTap(_:)), for: .touchUpInside)
            optionStackView.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 64).isActive = true
        }
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

    @objc private func handleSourceTap(_ sender: ImageSourceActionRow) {
        didChooseSource = true
        let source = sender.source
        dismissPanel { [weak self] in
            self?.onSelect?(source)
        }
    }

    @objc private func handleCancel() {
        guard !didChooseSource else { return }
        dismissPanel { [weak self] in
            self?.onCancel?()
        }
    }
}

private final class ImageSourceActionRow: UIControl {
    let source: ImageSelectionCoordinator.Source

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    init(source: ImageSelectionCoordinator.Source) {
        self.source = source
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? UIColor.white.withAlphaComponent(0.08) : .clear
        }
    }

    private func configureView() {
        backgroundColor = .clear

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = HomeDesignColor.accent.withAlphaComponent(0.16)
        iconContainer.layer.cornerRadius = 18
        iconContainer.clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: source.iconName)
        iconView.tintColor = HomeDesignColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = source.title
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = UIColor.white.withAlphaComponent(0.32)
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)

        addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        addSubview(titleLabel)
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -12),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 16),
            chevronView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
}

private extension ImageSelectionCoordinator.Source {
    var iconName: String {
        switch self {
        case .camera:
            return "camera.fill"
        case .photoLibrary:
            return "photo.on.rectangle.angled"
        }
    }
}

extension ImageSelectionCoordinator: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let provider = results.first?.itemProvider else {
            finish(.failure(.cancelled))
            return
        }

        guard provider.canLoadObject(ofClass: UIImage.self) else {
            finish(.failure(.loadFailed))
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async {
                guard let self, let image = object as? UIImage else {
                    self?.finish(.failure(.loadFailed))
                    return
                }
                self.finish(.success(self.selectedImage(from: image)))
            }
        }
    }
}

extension ImageSelectionCoordinator: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)

        guard let image = info[.originalImage] as? UIImage else {
            finish(.failure(.loadFailed))
            return
        }
        finish(.success(selectedImage(from: image)))
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        finish(.failure(.cancelled))
    }
}
