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

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(
            UIAlertAction(title: Source.photoLibrary.title, style: .default) { [weak self, weak viewController] _ in
                guard let self, let viewController else { return }
                self.presentPhotoLibrary(from: viewController, completion: completion)
            }
        )

        if allowsCamera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(
                UIAlertAction(title: Source.camera.title, style: .default) { [weak self, weak viewController] _ in
                    guard let self, let viewController else { return }
                    self.presentCamera(from: viewController, completion: completion)
                }
            )
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.finish(.failure(.cancelled))
        })

        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.maxY,
                width: 1,
                height: 1
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(alert, animated: true)
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
