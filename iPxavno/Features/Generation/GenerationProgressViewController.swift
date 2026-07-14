import UIKit

final class GenerationProgressViewController: BaseViewController {
    var onCancel: (() -> Void)?
    var onSkipWait: (() -> Void)?
    var onViewResult: (() -> Void)?
    var onRetry: (() -> Void)?
    var onBack: (() -> Void)?

    private let template: CreativeTemplate
    private let requiredDiamonds: Int
    private let isMember: Bool

    private let closeButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let previewContainer = UIView()
    private let previewImageView = RemoteImageView()
    private let previewOverlay = UIView()
    private let previewFocusFrame = UIView()
    private let previewCaptionLabel = UILabel()
    private let shimmerView = UIView()
    private let percentLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let successBadge = UILabel()
    private let benefitCard = UIControl()
    private let benefitIconContainer = UIView()
    private let benefitIcon = UIImageView(image: UIImage(systemName: "bolt.fill"))
    private let benefitTitleLabel = UILabel()
    private let benefitSubtitleLabel = UILabel()
    private let benefitButton = UIButton(type: .system)
    private let cancelActionButton = UIButton(type: .system)
    private let resultButton = UIButton(type: .system)
    private let failureContainer = UIView()
    private let failureIconContainer = UIView()
    private let failureIcon = UIImageView(image: UIImage(systemName: "exclamationmark"))
    private let failureTitleLabel = UILabel()
    private let failureMessageLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let failureBackButton = UIButton(type: .system)
    private let cancelConfirmationOverlay = UIControl()
    private let cancelConfirmationCard = UIView()
    private let cancelConfirmationIconContainer = UIView()
    private let cancelConfirmationIcon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
    private let cancelConfirmationTitleLabel = UILabel()
    private let cancelConfirmationMessageLabel = UILabel()
    private let keepWaitingButton = UIButton(type: .system)
    private let confirmCancelButton = UIButton(type: .system)

    private var progressFillWidthConstraint: NSLayoutConstraint?
    private var currentProgress: Double = 0
    private var isGenerationActive = true
    private var previousInteractivePopEnabled: Bool?

    init(template: CreativeTemplate, requiredDiamonds: Int, isMember: Bool) {
        self.template = template
        self.requiredDiamonds = requiredDiamonds
        self.isMember = isMember
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
        update(progress: 0.04, title: "Preparing", detail: "Checking your request...")
        setSkipActionEnabled(isMember)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        previousInteractivePopEnabled = navigationController?.interactivePopGestureRecognizer?.isEnabled
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let previousInteractivePopEnabled {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = previousInteractivePopEnabled
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyProgress(animated: false)
        updateShimmer()
    }

    func update(progress: Double, title: String, detail: String) {
        performOnMain { [weak self] in
            guard let self else { return }
            self.currentProgress = max(self.currentProgress, min(max(progress, 0), 0.97))
            self.statusLabel.text = title
            self.detailLabel.text = detail
            self.percentLabel.text = "\(Int(round(self.currentProgress * 100)))%"
            self.updatePreviewCaption()
            self.applyProgress(animated: true)
        }
    }

    func finish(resultURL: URL?) {
        performOnMain { [weak self] in
            guard let self else { return }
            self.isGenerationActive = false
            self.currentProgress = 1
            self.statusLabel.text = "Creation complete"
            self.detailLabel.text = resultURL == nil ? "Your result is ready." : "Your result is ready to preview."
            self.percentLabel.text = "100%"
            self.updatePreviewCaption()
            self.applyProgress(animated: true)
            self.showSuccessAnimation()
            self.benefitCard.isHidden = true
            self.cancelActionButton.isHidden = true
            self.resultButton.isHidden = false
        }
    }

    func showFailure(message: String) {
        performOnMain { [weak self] in
            guard let self else { return }
            self.isGenerationActive = false
            self.titleLabel.text = "Generation"
            self.failureMessageLabel.attributedText = self.failureMessage(errorMessage: message)
            self.subtitleLabel.isHidden = true
            self.previewContainer.isHidden = true
            self.percentLabel.isHidden = true
            self.statusLabel.isHidden = true
            self.detailLabel.isHidden = true
            self.progressTrack.isHidden = true
            self.successBadge.isHidden = true
            self.progressFill.backgroundColor = UIColor(hex: 0xFF5A5F)
            self.cancelActionButton.isHidden = true
            self.resultButton.isHidden = true
            self.benefitCard.isHidden = true
            self.failureContainer.isHidden = false
        }
    }

    func showBackgroundAccepted() {
        performOnMain { [weak self] in
            self?.isGenerationActive = false
            self?.detailLabel.text = "You can check the result later in Me."
        }
    }

    func setSkipActionEnabled(_ isEnabled: Bool) {
        performOnMain { [weak self] in
            self?.benefitCard.isUserInteractionEnabled = isEnabled || self?.isMember == false
            self?.benefitButton.isEnabled = isEnabled || self?.isMember == false
            self?.benefitButton.alpha = (isEnabled || self?.isMember == false) ? 1 : 0.55
        }
    }

    private func configureView() {
        view.backgroundColor = HomeDesignColor.background
        configureNavigation()
        configureHero()
        configureProgress()
        configureBenefit()
        configureCancelButton()
        configureResultButton()
        configureFailure()
        configureCancelConfirmation()
    }

    private func configureNavigation() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.tintColor = HomeDesignColor.text
        closeButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        closeButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold),
            forImageIn: .normal
        )
        closeButton.addTarget(self, action: #selector(handleNavigationBack), for: .touchUpInside)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Generating"
        titleLabel.textColor = HomeDesignColor.text
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center

        view.addSubview(closeButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -76)
        ])
    }

    private func configureHero() {
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "This may take 1-4 min. Stay on this page."
        subtitleLabel.textColor = HomeDesignColor.mutedText
        subtitleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75

        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.backgroundColor = HomeDesignColor.card
        previewContainer.layer.cornerRadius = 20
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = HomeDesignColor.border.cgColor
        previewContainer.clipsToBounds = true

        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.backgroundColor = UIColor(hex: 0x111114)
        previewImageView.setImage(url: template.preferredImageURL, placeholder: UIImage(systemName: "sparkles"))
        previewImageView.tintColor = HomeDesignColor.accent.withAlphaComponent(0.55)

        shimmerView.translatesAutoresizingMaskIntoConstraints = false
        shimmerView.backgroundColor = UIColor.white.withAlphaComponent(0.08)

        previewOverlay.translatesAutoresizingMaskIntoConstraints = false
        previewOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.34)

        previewFocusFrame.translatesAutoresizingMaskIntoConstraints = false
        previewFocusFrame.layer.cornerRadius = 20
        previewFocusFrame.layer.borderWidth = 3
        previewFocusFrame.layer.borderColor = HomeDesignColor.accent.cgColor

        previewCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        previewCaptionLabel.textColor = HomeDesignColor.text.withAlphaComponent(0.9)
        previewCaptionLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .medium)
        previewCaptionLabel.textAlignment = .center
        previewCaptionLabel.numberOfLines = 1
        previewCaptionLabel.adjustsFontSizeToFitWidth = true
        previewCaptionLabel.minimumScaleFactor = 0.75
        updatePreviewCaption()

        view.addSubview(previewContainer)
        previewContainer.addSubview(previewImageView)
        previewContainer.addSubview(previewOverlay)
        previewContainer.addSubview(previewFocusFrame)
        previewContainer.addSubview(previewCaptionLabel)
        previewContainer.addSubview(shimmerView)
        previewContainer.bringSubviewToFront(previewOverlay)
        previewContainer.bringSubviewToFront(previewFocusFrame)
        previewContainer.bringSubviewToFront(previewCaptionLabel)
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            previewContainer.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 22),
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 0.97),

            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

            previewOverlay.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewOverlay.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewOverlay.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewOverlay.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

            previewFocusFrame.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            previewFocusFrame.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            previewFocusFrame.widthAnchor.constraint(equalToConstant: 40),
            previewFocusFrame.heightAnchor.constraint(equalToConstant: 40),

            previewCaptionLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 24),
            previewCaptionLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -24),
            previewCaptionLabel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -22),

            shimmerView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            shimmerView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            shimmerView.widthAnchor.constraint(equalTo: previewContainer.widthAnchor, multiplier: 0.32),

            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            subtitleLabel.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 22)
        ])
    }

    private func configureProgress() {
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.textColor = HomeDesignColor.accent
        percentLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        percentLabel.textAlignment = .center
        percentLabel.isHidden = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = HomeDesignColor.text
        statusLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.isHidden = true

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.textColor = HomeDesignColor.mutedText
        detailLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .regular)
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 2
        detailLabel.isHidden = true

        progressTrack.translatesAutoresizingMaskIntoConstraints = false
        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        progressTrack.layer.cornerRadius = 4
        progressTrack.clipsToBounds = true

        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = HomeDesignColor.accent
        progressFill.layer.cornerRadius = 4
        progressFill.clipsToBounds = true

        successBadge.translatesAutoresizingMaskIntoConstraints = false
        successBadge.text = "success 🎉"
        successBadge.textColor = HomeDesignColor.blackText
        successBadge.backgroundColor = HomeDesignColor.accent
        successBadge.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        successBadge.textAlignment = .center
        successBadge.layer.cornerRadius = 13
        successBadge.clipsToBounds = true
        successBadge.alpha = 0

        view.addSubview(percentLabel)
        view.addSubview(statusLabel)
        view.addSubview(detailLabel)
        view.addSubview(progressTrack)
        progressTrack.addSubview(progressFill)
        view.addSubview(successBadge)

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressFillWidthConstraint = fillWidth

        NSLayoutConstraint.activate([
            percentLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            percentLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            percentLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 10),

            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            statusLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 8),

            detailLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            detailLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            detailLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),

            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 38),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -38),
            progressTrack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            progressTrack.heightAnchor.constraint(equalToConstant: 8),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            fillWidth,

            successBadge.trailingAnchor.constraint(equalTo: progressTrack.trailingAnchor),
            successBadge.bottomAnchor.constraint(equalTo: progressTrack.topAnchor, constant: -9),
            successBadge.widthAnchor.constraint(equalToConstant: 92),
            successBadge.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func configureBenefit() {
        benefitCard.translatesAutoresizingMaskIntoConstraints = false
        benefitCard.backgroundColor = isMember ? HomeDesignColor.accent : UIColor(hex: 0x0F0F11)
        benefitCard.layer.cornerRadius = isMember ? 29 : 25
        benefitCard.layer.borderWidth = 1
        benefitCard.layer.borderColor = (isMember ? UIColor.white.withAlphaComponent(0.20) : HomeDesignColor.accent.withAlphaComponent(0.30)).cgColor
        benefitCard.addTarget(self, action: #selector(handleSkipWait), for: .touchUpInside)

        benefitIconContainer.translatesAutoresizingMaskIntoConstraints = false
        benefitIconContainer.backgroundColor = isMember ? UIColor.white.withAlphaComponent(0.22) : .clear
        benefitIconContainer.layer.cornerRadius = isMember ? 24 : 13
        benefitIconContainer.clipsToBounds = true

        benefitIcon.translatesAutoresizingMaskIntoConstraints = false
        benefitIcon.image = isMember ? UIImage(named: "ic_Vip") : UIImage(systemName: "bolt.fill")
        benefitIcon.tintColor = isMember ? nil : HomeDesignColor.accent
        benefitIcon.contentMode = .scaleAspectFit
        benefitIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 23, weight: .bold)

        benefitTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        benefitTitleLabel.text = isMember ? "VIP Skip The Wait" : "Skip the wait"
        benefitTitleLabel.textColor = isMember ? HomeDesignColor.blackText : HomeDesignColor.text
        benefitTitleLabel.font = UIFont.systemFont(ofSize: isMember ? 20 : 19.8, weight: .bold)
        benefitTitleLabel.numberOfLines = 1
        benefitTitleLabel.adjustsFontSizeToFitWidth = true
        benefitTitleLabel.minimumScaleFactor = 0.72
        benefitTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        benefitSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        benefitSubtitleLabel.text = isMember
            ? "You're a valued VIP.\nTap Skip to leave the wait.\nView it later in Me."
            : "Generate in background,\nwe'll notify you"
        benefitSubtitleLabel.textColor = isMember ? HomeDesignColor.blackText.withAlphaComponent(0.72) : HomeDesignColor.mutedText
        benefitSubtitleLabel.font = UIFont.systemFont(ofSize: isMember ? 13.2 : 14.1, weight: .regular)
        benefitSubtitleLabel.numberOfLines = isMember ? 3 : 2
        benefitSubtitleLabel.lineBreakMode = .byWordWrapping
        benefitSubtitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        benefitButton.translatesAutoresizingMaskIntoConstraints = false
        benefitButton.backgroundColor = isMember ? HomeDesignColor.blackText : HomeDesignColor.accent
        benefitButton.layer.cornerRadius = isMember ? 20 : 18
        benefitButton.clipsToBounds = true
        benefitButton.setTitle(isMember ? "Skip Now" : "Skip the wait", for: .normal)
        benefitButton.setTitleColor(isMember ? HomeDesignColor.accent : HomeDesignColor.blackText, for: .normal)
        benefitButton.titleLabel?.font = UIFont.systemFont(ofSize: isMember ? 17 : 16, weight: .bold)
        benefitButton.titleLabel?.adjustsFontSizeToFitWidth = true
        benefitButton.titleLabel?.minimumScaleFactor = 0.72
        benefitButton.addTarget(self, action: #selector(handleSkipWait), for: .touchUpInside)

        view.addSubview(benefitCard)
        benefitCard.addSubview(benefitIconContainer)
        benefitIconContainer.addSubview(benefitIcon)
        benefitCard.addSubview(benefitTitleLabel)
        benefitCard.addSubview(benefitSubtitleLabel)
        benefitCard.addSubview(benefitButton)

        NSLayoutConstraint.activate([
            benefitCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            benefitCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            benefitCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -42),
            benefitCard.heightAnchor.constraint(equalToConstant: isMember ? 176 : 154),

            benefitIconContainer.leadingAnchor.constraint(equalTo: benefitCard.leadingAnchor, constant: isMember ? 20 : 22),
            benefitIconContainer.topAnchor.constraint(equalTo: benefitCard.topAnchor, constant: isMember ? 18 : 24),
            benefitIconContainer.widthAnchor.constraint(equalToConstant: isMember ? 48 : 26),
            benefitIconContainer.heightAnchor.constraint(equalToConstant: isMember ? 48 : 26),

            benefitIcon.centerXAnchor.constraint(equalTo: benefitIconContainer.centerXAnchor),
            benefitIcon.centerYAnchor.constraint(equalTo: benefitIconContainer.centerYAnchor),
            benefitIcon.widthAnchor.constraint(equalToConstant: isMember ? 34 : 24),
            benefitIcon.heightAnchor.constraint(equalToConstant: isMember ? 34 : 24),

            benefitButton.leadingAnchor.constraint(equalTo: benefitCard.leadingAnchor, constant: 18),
            benefitButton.trailingAnchor.constraint(equalTo: benefitCard.trailingAnchor, constant: -18),
            benefitButton.bottomAnchor.constraint(equalTo: benefitCard.bottomAnchor, constant: isMember ? -14 : -18),
            benefitButton.heightAnchor.constraint(equalToConstant: isMember ? 46 : 46),

            benefitTitleLabel.leadingAnchor.constraint(equalTo: benefitIconContainer.trailingAnchor, constant: isMember ? 15 : 17),
            benefitTitleLabel.trailingAnchor.constraint(equalTo: benefitCard.trailingAnchor, constant: -20),
            benefitTitleLabel.topAnchor.constraint(equalTo: benefitIconContainer.topAnchor, constant: isMember ? 1 : -1),

            benefitSubtitleLabel.leadingAnchor.constraint(equalTo: benefitTitleLabel.leadingAnchor),
            benefitSubtitleLabel.trailingAnchor.constraint(equalTo: benefitCard.trailingAnchor, constant: -20),
            benefitSubtitleLabel.topAnchor.constraint(equalTo: benefitTitleLabel.bottomAnchor, constant: isMember ? 4 : 6),
            benefitSubtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: benefitButton.topAnchor, constant: isMember ? -16 : -12)
        ])
    }

    private func configureCancelButton() {
        cancelActionButton.translatesAutoresizingMaskIntoConstraints = false
        cancelActionButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        cancelActionButton.layer.cornerRadius = 21
        cancelActionButton.layer.borderWidth = 1
        cancelActionButton.layer.borderColor = HomeDesignColor.border.cgColor
        cancelActionButton.clipsToBounds = true
        cancelActionButton.setTitle("Cancel", for: .normal)
        cancelActionButton.setTitleColor(HomeDesignColor.text, for: .normal)
        cancelActionButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.5, weight: .semibold)
        cancelActionButton.addTarget(self, action: #selector(handleCancelAction), for: .touchUpInside)

        view.addSubview(cancelActionButton)

        NSLayoutConstraint.activate([
            cancelActionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            cancelActionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            cancelActionButton.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 22),
            cancelActionButton.heightAnchor.constraint(equalToConstant: 72),
            cancelActionButton.bottomAnchor.constraint(lessThanOrEqualTo: benefitCard.topAnchor, constant: -24)
        ])
    }

    private func configureResultButton() {
        resultButton.translatesAutoresizingMaskIntoConstraints = false
        resultButton.backgroundColor = HomeDesignColor.accent
        resultButton.layer.cornerRadius = 22
        resultButton.clipsToBounds = true
        resultButton.setTitle("View Result", for: .normal)
        resultButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        resultButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        resultButton.addTarget(self, action: #selector(handleViewResult), for: .touchUpInside)
        resultButton.isHidden = true
        view.addSubview(resultButton)

        NSLayoutConstraint.activate([
            resultButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            resultButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            resultButton.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 22),
            resultButton.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    private func configureFailure() {
        failureContainer.translatesAutoresizingMaskIntoConstraints = false
        failureContainer.isHidden = true

        failureIconContainer.translatesAutoresizingMaskIntoConstraints = false
        failureIconContainer.backgroundColor = UIColor(hex: 0xFF5A5F).withAlphaComponent(0.16)
        failureIconContainer.layer.cornerRadius = 42
        failureIconContainer.clipsToBounds = true

        failureIcon.translatesAutoresizingMaskIntoConstraints = false
        failureIcon.tintColor = UIColor(hex: 0xFF5A5F)
        failureIcon.contentMode = .scaleAspectFit
        failureIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 36, weight: .bold)

        failureTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        failureTitleLabel.text = "Generation failed"
        failureTitleLabel.textColor = HomeDesignColor.text
        failureTitleLabel.font = UIFont.systemFont(ofSize: 25.4, weight: .bold)
        failureTitleLabel.textAlignment = .center
        failureTitleLabel.numberOfLines = 1
        failureTitleLabel.adjustsFontSizeToFitWidth = true
        failureTitleLabel.minimumScaleFactor = 0.75

        failureMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        failureMessageLabel.textColor = HomeDesignColor.mutedText
        failureMessageLabel.font = UIFont.systemFont(ofSize: 17.7, weight: .regular)
        failureMessageLabel.textAlignment = .center
        failureMessageLabel.numberOfLines = 3

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.backgroundColor = HomeDesignColor.accent
        retryButton.layer.cornerRadius = 21
        retryButton.clipsToBounds = true
        retryButton.setTitle("Try again", for: .normal)
        retryButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.5, weight: .bold)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)

        failureBackButton.translatesAutoresizingMaskIntoConstraints = false
        failureBackButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        failureBackButton.layer.cornerRadius = 21
        failureBackButton.layer.borderWidth = 1
        failureBackButton.layer.borderColor = HomeDesignColor.border.cgColor
        failureBackButton.clipsToBounds = true
        failureBackButton.setTitle("Back", for: .normal)
        failureBackButton.setTitleColor(HomeDesignColor.text, for: .normal)
        failureBackButton.titleLabel?.font = UIFont.systemFont(ofSize: 20.5, weight: .semibold)
        failureBackButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)

        view.addSubview(failureContainer)
        failureContainer.addSubview(failureIconContainer)
        failureIconContainer.addSubview(failureIcon)
        failureContainer.addSubview(failureTitleLabel)
        failureContainer.addSubview(failureMessageLabel)
        failureContainer.addSubview(retryButton)
        failureContainer.addSubview(failureBackButton)

        NSLayoutConstraint.activate([
            failureContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
            failureContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
            failureContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 166),
            failureContainer.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),

            failureIconContainer.topAnchor.constraint(equalTo: failureContainer.topAnchor),
            failureIconContainer.centerXAnchor.constraint(equalTo: failureContainer.centerXAnchor),
            failureIconContainer.widthAnchor.constraint(equalToConstant: 84),
            failureIconContainer.heightAnchor.constraint(equalToConstant: 84),

            failureIcon.centerXAnchor.constraint(equalTo: failureIconContainer.centerXAnchor),
            failureIcon.centerYAnchor.constraint(equalTo: failureIconContainer.centerYAnchor),
            failureIcon.widthAnchor.constraint(equalToConstant: 42),
            failureIcon.heightAnchor.constraint(equalToConstant: 42),

            failureTitleLabel.leadingAnchor.constraint(equalTo: failureContainer.leadingAnchor),
            failureTitleLabel.trailingAnchor.constraint(equalTo: failureContainer.trailingAnchor),
            failureTitleLabel.topAnchor.constraint(equalTo: failureIconContainer.bottomAnchor, constant: 28),

            failureMessageLabel.leadingAnchor.constraint(equalTo: failureContainer.leadingAnchor, constant: 12),
            failureMessageLabel.trailingAnchor.constraint(equalTo: failureContainer.trailingAnchor, constant: -12),
            failureMessageLabel.topAnchor.constraint(equalTo: failureTitleLabel.bottomAnchor, constant: 13),

            retryButton.leadingAnchor.constraint(equalTo: failureContainer.leadingAnchor),
            retryButton.trailingAnchor.constraint(equalTo: failureContainer.trailingAnchor),
            retryButton.topAnchor.constraint(equalTo: failureMessageLabel.bottomAnchor, constant: 36),
            retryButton.heightAnchor.constraint(equalToConstant: 72),

            failureBackButton.leadingAnchor.constraint(equalTo: failureContainer.leadingAnchor),
            failureBackButton.trailingAnchor.constraint(equalTo: failureContainer.trailingAnchor),
            failureBackButton.topAnchor.constraint(equalTo: retryButton.bottomAnchor, constant: 14),
            failureBackButton.heightAnchor.constraint(equalToConstant: 72),
            failureBackButton.bottomAnchor.constraint(equalTo: failureContainer.bottomAnchor)
        ])
    }

    private func configureCancelConfirmation() {
        cancelConfirmationOverlay.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        cancelConfirmationOverlay.alpha = 0
        cancelConfirmationOverlay.isHidden = true

        cancelConfirmationCard.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationCard.backgroundColor = UIColor(hex: 0x141417).withAlphaComponent(0.98)
        cancelConfirmationCard.layer.cornerRadius = 24
        cancelConfirmationCard.layer.borderWidth = 1
        cancelConfirmationCard.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        cancelConfirmationCard.clipsToBounds = true

        cancelConfirmationIconContainer.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationIconContainer.backgroundColor = UIColor(hex: 0xFFB020).withAlphaComponent(0.16)
        cancelConfirmationIconContainer.layer.cornerRadius = 30
        cancelConfirmationIconContainer.clipsToBounds = true

        cancelConfirmationIcon.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationIcon.tintColor = UIColor(hex: 0xFFB020)
        cancelConfirmationIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)

        cancelConfirmationTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationTitleLabel.text = "Cancel this creation?"
        cancelConfirmationTitleLabel.textColor = HomeDesignColor.text
        cancelConfirmationTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        cancelConfirmationTitleLabel.textAlignment = .center
        cancelConfirmationTitleLabel.numberOfLines = 1
        cancelConfirmationTitleLabel.adjustsFontSizeToFitWidth = true
        cancelConfirmationTitleLabel.minimumScaleFactor = 0.75

        cancelConfirmationMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        cancelConfirmationMessageLabel.text = "Leaving now will stop generation and cancel the task. Your result will not be created."
        cancelConfirmationMessageLabel.textColor = HomeDesignColor.mutedText
        cancelConfirmationMessageLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .regular)
        cancelConfirmationMessageLabel.textAlignment = .center
        cancelConfirmationMessageLabel.numberOfLines = 3

        keepWaitingButton.translatesAutoresizingMaskIntoConstraints = false
        keepWaitingButton.backgroundColor = HomeDesignColor.accent
        keepWaitingButton.layer.cornerRadius = 18
        keepWaitingButton.clipsToBounds = true
        keepWaitingButton.setTitle("Keep waiting", for: .normal)
        keepWaitingButton.setTitleColor(HomeDesignColor.blackText, for: .normal)
        keepWaitingButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        keepWaitingButton.addTarget(self, action: #selector(handleKeepWaiting), for: .touchUpInside)

        confirmCancelButton.translatesAutoresizingMaskIntoConstraints = false
        confirmCancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        confirmCancelButton.layer.cornerRadius = 18
        confirmCancelButton.layer.borderWidth = 1
        confirmCancelButton.layer.borderColor = HomeDesignColor.border.cgColor
        confirmCancelButton.clipsToBounds = true
        confirmCancelButton.setTitle("Cancel creation", for: .normal)
        confirmCancelButton.setTitleColor(UIColor(hex: 0xFF7A7A), for: .normal)
        confirmCancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        confirmCancelButton.addTarget(self, action: #selector(handleConfirmCancel), for: .touchUpInside)

        view.addSubview(cancelConfirmationOverlay)
        cancelConfirmationOverlay.addSubview(cancelConfirmationCard)
        cancelConfirmationCard.addSubview(cancelConfirmationIconContainer)
        cancelConfirmationIconContainer.addSubview(cancelConfirmationIcon)
        cancelConfirmationCard.addSubview(cancelConfirmationTitleLabel)
        cancelConfirmationCard.addSubview(cancelConfirmationMessageLabel)
        cancelConfirmationCard.addSubview(keepWaitingButton)
        cancelConfirmationCard.addSubview(confirmCancelButton)

        NSLayoutConstraint.activate([
            cancelConfirmationOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            cancelConfirmationOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cancelConfirmationOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cancelConfirmationOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cancelConfirmationCard.leadingAnchor.constraint(equalTo: cancelConfirmationOverlay.leadingAnchor, constant: 28),
            cancelConfirmationCard.trailingAnchor.constraint(equalTo: cancelConfirmationOverlay.trailingAnchor, constant: -28),
            cancelConfirmationCard.centerYAnchor.constraint(equalTo: cancelConfirmationOverlay.centerYAnchor),

            cancelConfirmationIconContainer.topAnchor.constraint(equalTo: cancelConfirmationCard.topAnchor, constant: 28),
            cancelConfirmationIconContainer.centerXAnchor.constraint(equalTo: cancelConfirmationCard.centerXAnchor),
            cancelConfirmationIconContainer.widthAnchor.constraint(equalToConstant: 60),
            cancelConfirmationIconContainer.heightAnchor.constraint(equalToConstant: 60),

            cancelConfirmationIcon.centerXAnchor.constraint(equalTo: cancelConfirmationIconContainer.centerXAnchor),
            cancelConfirmationIcon.centerYAnchor.constraint(equalTo: cancelConfirmationIconContainer.centerYAnchor),
            cancelConfirmationIcon.widthAnchor.constraint(equalToConstant: 30),
            cancelConfirmationIcon.heightAnchor.constraint(equalToConstant: 30),

            cancelConfirmationTitleLabel.leadingAnchor.constraint(equalTo: cancelConfirmationCard.leadingAnchor, constant: 22),
            cancelConfirmationTitleLabel.trailingAnchor.constraint(equalTo: cancelConfirmationCard.trailingAnchor, constant: -22),
            cancelConfirmationTitleLabel.topAnchor.constraint(equalTo: cancelConfirmationIconContainer.bottomAnchor, constant: 20),

            cancelConfirmationMessageLabel.leadingAnchor.constraint(equalTo: cancelConfirmationCard.leadingAnchor, constant: 28),
            cancelConfirmationMessageLabel.trailingAnchor.constraint(equalTo: cancelConfirmationCard.trailingAnchor, constant: -28),
            cancelConfirmationMessageLabel.topAnchor.constraint(equalTo: cancelConfirmationTitleLabel.bottomAnchor, constant: 11),

            keepWaitingButton.leadingAnchor.constraint(equalTo: cancelConfirmationCard.leadingAnchor, constant: 22),
            keepWaitingButton.trailingAnchor.constraint(equalTo: cancelConfirmationCard.trailingAnchor, constant: -22),
            keepWaitingButton.topAnchor.constraint(equalTo: cancelConfirmationMessageLabel.bottomAnchor, constant: 25),
            keepWaitingButton.heightAnchor.constraint(equalToConstant: 56),

            confirmCancelButton.leadingAnchor.constraint(equalTo: cancelConfirmationCard.leadingAnchor, constant: 22),
            confirmCancelButton.trailingAnchor.constraint(equalTo: cancelConfirmationCard.trailingAnchor, constant: -22),
            confirmCancelButton.topAnchor.constraint(equalTo: keepWaitingButton.bottomAnchor, constant: 12),
            confirmCancelButton.heightAnchor.constraint(equalToConstant: 56),
            confirmCancelButton.bottomAnchor.constraint(equalTo: cancelConfirmationCard.bottomAnchor, constant: -22)
        ])
    }

    private func updatePreviewCaption() {
        let trimmedTitle = template.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmedTitle.isEmpty ? "Generating" : trimmedTitle
        previewCaptionLabel.text = "\(displayTitle) · \(Int(round(currentProgress * 100)))%"
    }

    private func failureMessage(errorMessage: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 1

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17.7, weight: .regular),
            .foregroundColor: HomeDesignColor.mutedText,
            .paragraphStyle: paragraphStyle
        ]
        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17.7, weight: .bold),
            .foregroundColor: HomeDesignColor.accent,
            .paragraphStyle: paragraphStyle
        ]

        guard requiredDiamonds > 0 else {
            let fallback = errorMessage.isEmpty
                ? "Something went wrong. Please try again."
                : errorMessage
            return NSAttributedString(string: fallback, attributes: baseAttributes)
        }

        let message = NSMutableAttributedString(
            string: "Something went wrong. Your ",
            attributes: baseAttributes
        )
        message.append(NSAttributedString(string: "\(requiredDiamonds)", attributes: highlightAttributes))
        message.append(NSAttributedString(string: "\n", attributes: baseAttributes))
        message.append(NSAttributedString(string: "diamonds", attributes: highlightAttributes))
        message.append(NSAttributedString(string: " were refunded.", attributes: baseAttributes))
        return message
    }

    private func applyProgress(animated: Bool) {
        let width = progressTrack.bounds.width * currentProgress
        progressFillWidthConstraint?.constant = width

        let animations = {
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut], animations: animations)
        } else {
            animations()
        }
    }

    private func showSuccessAnimation() {
        successBadge.transform = CGAffineTransform(scaleX: 0.78, y: 0.78).translatedBy(x: 0, y: 8)
        UIView.animate(
            withDuration: 0.42,
            delay: 0.12,
            usingSpringWithDamping: 0.58,
            initialSpringVelocity: 0.7,
            options: [.curveEaseOut]
        ) {
            self.successBadge.alpha = 1
            self.successBadge.transform = .identity
            self.progressFill.transform = CGAffineTransform(scaleX: 1, y: 1.22)
        } completion: { _ in
            UIView.animate(withDuration: 0.18) {
                self.progressFill.transform = .identity
            }
        }
    }

    private func updateShimmer() {
        shimmerView.layer.removeAllAnimations()
        shimmerView.transform = CGAffineTransform(translationX: -previewContainer.bounds.width, y: 0)
        UIView.animate(
            withDuration: 3.2,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut]
        ) {
            self.shimmerView.transform = CGAffineTransform(translationX: self.previewContainer.bounds.width * 1.15, y: 0)
        }
    }

    private func performOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private func showCancelConfirmation() {
        view.bringSubviewToFront(cancelConfirmationOverlay)
        cancelConfirmationOverlay.isHidden = false
        cancelConfirmationCard.transform = CGAffineTransform(scaleX: 0.94, y: 0.94).translatedBy(x: 0, y: 16)
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            self.cancelConfirmationOverlay.alpha = 1
            self.cancelConfirmationCard.transform = .identity
        }
    }

    private func hideCancelConfirmation() {
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            self.cancelConfirmationOverlay.alpha = 0
            self.cancelConfirmationCard.transform = CGAffineTransform(scaleX: 0.96, y: 0.96).translatedBy(x: 0, y: 10)
        } completion: { _ in
            self.cancelConfirmationOverlay.isHidden = true
            self.cancelConfirmationCard.transform = .identity
        }
    }

    private func cancelGenerationAndLeave() {
        isGenerationActive = false
        cancelActionButton.isEnabled = false
        closeButton.isEnabled = false
        hideCancelConfirmation()
        onCancel?()
    }

    @objc private func handleNavigationBack() {
        guard isGenerationActive else {
            onBack?()
            return
        }

        if isMember {
            cancelGenerationAndLeave()
        } else {
            showCancelConfirmation()
        }
    }

    @objc private func handleCancelAction() {
        guard isGenerationActive else {
            onBack?()
            return
        }
        cancelGenerationAndLeave()
    }

    @objc private func handleKeepWaiting() {
        hideCancelConfirmation()
    }

    @objc private func handleConfirmCancel() {
        cancelGenerationAndLeave()
    }

    @objc private func handleSkipWait() {
        onSkipWait?()
    }

    @objc private func handleViewResult() {
        onViewResult?()
    }

    @objc private func handleRetry() {
        onRetry?()
    }

    @objc private func handleBack() {
        onBack?()
    }
}
