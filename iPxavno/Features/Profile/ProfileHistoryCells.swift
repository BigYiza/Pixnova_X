import AVFoundation
import UIKit

final class ProfileMembershipCardCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileMembershipCardCell"

    private let iconBackground = UIView()
    private let crownView = UIImageView(image: UIImage(systemName: "crown"))
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(membership: ProfileMembershipState) {
        let isVIP = membership.isVIP
        contentView.backgroundColor = isVIP
            ? HomeDesignColor.accent.withAlphaComponent(0.08)
            : HomeDesignColor.card
        contentView.layer.borderColor = HomeDesignColor.accent
            .withAlphaComponent(isVIP ? 0.4 : 0.32)
            .cgColor

        titleLabel.text = isVIP ? "PRO Member" : "Unlock PRO"
        detailLabel.text = isVIP
            ? membership.renewalText ?? "Membership active"
            : "Unlimited photos · skip\nwait · weekly diamonds"
        detailLabel.numberOfLines = isVIP ? 1 : 2
        statusLabel.isHidden = !isVIP
        chevronView.isHidden = isVIP
    }

    private func configureView() {
        contentView.layer.cornerRadius = 23
        contentView.layer.borderWidth = 1
        contentView.clipsToBounds = true

        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = HomeDesignColor.accent
        iconBackground.layer.cornerRadius = 17

        crownView.translatesAutoresizingMaskIntoConstraints = false
        crownView.tintColor = HomeDesignColor.blackText
        crownView.contentMode = .scaleAspectFit
        crownView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .bold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.textColor = UIColor(hex: 0x9A9AA2)
        detailLabel.font = UIFont.systemFont(ofSize: 14.8, weight: .regular)
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.8

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Active"
        statusLabel.textColor = HomeDesignColor.accent
        statusLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
        statusLabel.textAlignment = .right

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.tintColor = UIColor(hex: 0x56565C)
        chevronView.contentMode = .scaleAspectFit
        chevronView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        contentView.addSubview(iconBackground)
        iconBackground.addSubview(crownView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(detailLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            iconBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            iconBackground.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconBackground.widthAnchor.constraint(equalToConstant: 57),
            iconBackground.heightAnchor.constraint(equalToConstant: 57),

            crownView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            crownView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            crownView.widthAnchor.constraint(equalToConstant: 28),
            crownView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.leadingAnchor.constraint(equalTo: iconBackground.trailingAnchor, constant: 17),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -10),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -18),

            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -12),
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),

            chevronView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            chevronView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 20),
            chevronView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
}

final class ProfileHistoryHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "ProfileHistoryHeaderView"

    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureView() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MY ART"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 19, weight: .bold)

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 5)
        ])
    }
}

final class ProfileHistoryEmptyCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileHistoryEmptyCell"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No creations yet.\nPick a template to start."
        label.textColor = UIColor(hex: 0x9A9AA2)
        label.font = UIFont.systemFont(ofSize: 18.4, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ProfileHistoryTaskCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileHistoryTaskCell"

    private let imageView = RemoteImageView()
    private let gradientView = ProfileHistoryGradientView()
    private let failureOverlay = UIView()
    private let failureLabel = UILabel()
    private let progressOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let progressLabel = UILabel()
    private let playBadge = UIView()
    private let playIcon = UIImageView(image: UIImage(systemName: "play.fill"))
    private var thumbnailTask: Task<Void, Never>?
    private var representedTaskID = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailTask?.cancel()
        thumbnailTask = nil
        representedTaskID = ""
        imageView.setImage(url: nil)
        failureOverlay.isHidden = true
        progressOverlay.isHidden = true
        playBadge.isHidden = true
    }

    func configure(task: HistoryTask) {
        thumbnailTask?.cancel()
        representedTaskID = task.id
        failureOverlay.isHidden = task.state != .failed
        progressOverlay.isHidden = task.resultURL != nil || task.state == .failed
        playBadge.isHidden = !task.isVideoResult || task.resultURL == nil

        switch task.state {
        case .pending:
            progressLabel.text = "Queued"
        case .processing:
            progressLabel.text = "Creating"
        default:
            progressLabel.text = nil
        }
        progressOverlay.isHidden ? activityIndicator.stopAnimating() : activityIndicator.startAnimating()

        guard let resultURL = task.resultURL else {
            imageView.setImage(url: task.template?.preferredImageURL)
            return
        }

        if task.isVideoResult {
            imageView.setImage(url: task.template?.preferredImageURL)
            let taskID = task.id
            thumbnailTask = Task { [weak self] in
                let image = await ProfileVideoThumbnailLoader.image(for: resultURL)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.representedTaskID == taskID else { return }
                    if let image {
                        self?.imageView.image = image
                    }
                }
            }
        } else {
            imageView.setImage(url: resultURL)
        }
    }

    private func configureView() {
        contentView.backgroundColor = HomeDesignColor.card
        contentView.layer.cornerRadius = 20
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = HomeDesignColor.border.cgColor
        contentView.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = HomeDesignColor.card
        imageView.clipsToBounds = true

        gradientView.translatesAutoresizingMaskIntoConstraints = false

        failureOverlay.translatesAutoresizingMaskIntoConstraints = false
        failureOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        failureOverlay.isHidden = true

        failureLabel.translatesAutoresizingMaskIntoConstraints = false
        failureLabel.text = "Failed"
        failureLabel.textColor = .white
        failureLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)

        progressOverlay.translatesAutoresizingMaskIntoConstraints = false
        progressOverlay.layer.cornerRadius = 16
        progressOverlay.clipsToBounds = true
        progressOverlay.isHidden = true

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = HomeDesignColor.accent

        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        progressLabel.textColor = HomeDesignColor.text
        progressLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)

        playBadge.translatesAutoresizingMaskIntoConstraints = false
        playBadge.backgroundColor = UIColor.black.withAlphaComponent(0.46)
        playBadge.layer.cornerRadius = 20
        playBadge.clipsToBounds = true
        playBadge.isHidden = true

        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playIcon.tintColor = .white
        playIcon.contentMode = .scaleAspectFit
        playIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)

        contentView.addSubview(imageView)
        contentView.addSubview(gradientView)
        contentView.addSubview(failureOverlay)
        failureOverlay.addSubview(failureLabel)
        contentView.addSubview(progressOverlay)
        progressOverlay.contentView.addSubview(activityIndicator)
        progressOverlay.contentView.addSubview(progressLabel)
        contentView.addSubview(playBadge)
        playBadge.addSubview(playIcon)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gradientView.topAnchor.constraint(equalTo: contentView.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            failureOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            failureOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            failureOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            failureOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            failureLabel.centerXAnchor.constraint(equalTo: failureOverlay.centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: failureOverlay.centerYAnchor),

            progressOverlay.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            progressOverlay.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            progressOverlay.heightAnchor.constraint(equalToConstant: 38),

            activityIndicator.leadingAnchor.constraint(equalTo: progressOverlay.contentView.leadingAnchor, constant: 11),
            activityIndicator.centerYAnchor.constraint(equalTo: progressOverlay.contentView.centerYAnchor),
            activityIndicator.widthAnchor.constraint(equalToConstant: 18),
            activityIndicator.heightAnchor.constraint(equalToConstant: 18),

            progressLabel.leadingAnchor.constraint(equalTo: activityIndicator.trailingAnchor, constant: 6),
            progressLabel.trailingAnchor.constraint(equalTo: progressOverlay.contentView.trailingAnchor, constant: -12),
            progressLabel.centerYAnchor.constraint(equalTo: progressOverlay.contentView.centerYAnchor),

            playBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            playBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            playBadge.widthAnchor.constraint(equalToConstant: 40),
            playBadge.heightAnchor.constraint(equalToConstant: 40),

            playIcon.centerXAnchor.constraint(equalTo: playBadge.centerXAnchor, constant: 1),
            playIcon.centerYAnchor.constraint(equalTo: playBadge.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 15),
            playIcon.heightAnchor.constraint(equalToConstant: 15)
        ])
    }
}

private final class ProfileHistoryGradientView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.5).cgColor
        ]
        gradientLayer.locations = [0, 0.56, 1]
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private enum ProfileVideoThumbnailLoader {
    static func image(for url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.generateCGImageAsynchronously(for: .zero) { image, _, _ in
                continuation.resume(returning: image.map(UIImage.init(cgImage:)))
            }
        }
    }
}
