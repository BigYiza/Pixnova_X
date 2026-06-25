import Kingfisher
import UIKit

final class RemoteImageView: UIImageView {
    private static let options: KingfisherOptionsInfo = [
        .backgroundDecode,
        .cacheOriginalImage,
        .transition(.fade(0.18))
    ]

    func setImage(url: URL?, placeholder: UIImage? = nil) {
        kf.cancelDownloadTask()

        guard let url else {
            image = placeholder
            return
        }

        kf.setImage(
            with: url,
            placeholder: placeholder,
            options: Self.options
        )
    }
}
