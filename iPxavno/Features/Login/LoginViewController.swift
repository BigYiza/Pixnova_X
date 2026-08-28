import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
import UIKit

enum LoginPresentationReason: String {
    case launch
    case generation
    case membership
    case diamonds
    case profile
    case restorePurchases = "restore_purchases"
}

@MainActor
final class LoginPresentationCoordinator {
    private let accountRepository: AccountRepository
    private let analytics: AnalyticsTracking
    private weak var activeLoginViewController: LoginViewController?
    private var pendingCompletions: [(Bool) -> Void] = []

    init(accountRepository: AccountRepository, analytics: AnalyticsTracking) {
        self.accountRepository = accountRepository
        self.analytics = analytics
    }

    var hasLinkedAccount: Bool {
        accountRepository.cachedAccount?.hasLinkedAccount == true
    }

    @discardableResult
    func requireLinkedAccount(
        from presenter: UIViewController,
        reason: LoginPresentationReason,
        onAuthenticated: @escaping () -> Void
    ) -> Bool {
        guard !hasLinkedAccount else { return true }

        present(from: presenter, reason: reason) { authenticated in
            if authenticated { onAuthenticated() }
        }
        return false
    }

    func present(
        from presenter: UIViewController,
        reason: LoginPresentationReason,
        completion: ((Bool) -> Void)? = nil
    ) {
        if hasLinkedAccount {
            completion?(true)
            return
        }
        if let completion { pendingCompletions.append(completion) }
        guard activeLoginViewController == nil else { return }

        let login = LoginViewController(
            authenticationService: FirebaseAuthenticationService(accountRepository: accountRepository),
            analytics: analytics,
            reason: reason
        )
        login.onFinish = { [weak self, weak login] authenticated in
            guard let self else { return }
            let completions = self.pendingCompletions
            self.pendingCompletions.removeAll()
            self.activeLoginViewController = nil
            login?.dismiss(animated: true) {
                completions.forEach { $0(authenticated) }
            }
        }
        activeLoginViewController = login
        topViewController(from: presenter).present(login, animated: true)
    }

    private func topViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = viewController as? UINavigationController,
           let visible = navigation.visibleViewController {
            return topViewController(from: visible)
        }
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return topViewController(from: selected)
        }
        return viewController
    }
}

@MainActor
private final class FirebaseAuthenticationService: NSObject {
    private let accountRepository: AccountRepository
    private var appleContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var applePresentationAnchor: UIWindow?

    init(accountRepository: AccountRepository) {
        self.accountRepository = accountRepository
    }

    func signInWithApple(presenting viewController: UIViewController) async throws -> AccountSnapshot {
        let nonce = Self.randomNonceString()
        applePresentationAnchor = viewController.view.window
        let appleCredential = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) in
            appleContinuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw LoginError.missingIdentityToken
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        return try await authenticateWithFirebase(credential, platform: "apple")
    }

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> AccountSnapshot {
        guard let clientID = FirebaseApp.app()?.options.clientID ??
            Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
            !clientID.isEmpty else {
            throw LoginError.googleClientIDMissing
        }
        guard Self.supportsGoogleCallbackScheme(for: clientID) else {
            throw LoginError.googleURLSchemeMissing
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let googleIDToken = result.user.idToken?.tokenString else {
            throw LoginError.missingIdentityToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: googleIDToken,
            accessToken: result.user.accessToken.tokenString
        )
        return try await authenticateWithFirebase(credential, platform: "google")
    }

    private func authenticateWithFirebase(
        _ credential: FirebaseAuth.AuthCredential,
        platform: String
    ) async throws -> AccountSnapshot {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseIDToken = try await result.user.getIDToken()
            return try await accountRepository.bindFirebaseAccount(
                idToken: firebaseIDToken,
                platform: platform
            )
        } catch {
            try? Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            throw error
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func supportsGoogleCallbackScheme(for clientID: String) -> Bool {
        let callbackScheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let registeredSchemes = urlTypes.flatMap { urlType in
            urlType["CFBundleURLSchemes"] as? [String] ?? []
        }
        return registeredSchemes.contains(callbackScheme)
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
            guard status == errSecSuccess else {
                fatalError("Unable to generate a secure nonce. OSStatus: \(status)")
            }
            randomBytes.forEach { random in
                guard remainingLength > 0, random < charset.count else { return }
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }
}

extension FirebaseAuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleContinuation?.resume(throwing: LoginError.invalidAppleCredential)
            appleContinuation = nil
            return
        }
        appleContinuation?.resume(returning: credential)
        appleContinuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        appleContinuation?.resume(throwing: error)
        appleContinuation = nil
    }
}

extension FirebaseAuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        applePresentationAnchor ?? UIWindow()
    }
}

private enum LoginError: LocalizedError {
    case googleClientIDMissing
    case googleURLSchemeMissing
    case missingIdentityToken
    case invalidAppleCredential
    case bindingNotConfirmed

    var errorDescription: String? {
        switch self {
        case .googleClientIDMissing:
            return "Google Sign-In is not configured. Add CLIENT_ID and REVERSED_CLIENT_ID to GoogleService-Info.plist."
        case .googleURLSchemeMissing:
            return "Google Sign-In is missing its callback URL scheme. Add REVERSED_CLIENT_ID to the app's URL Types."
        case .missingIdentityToken:
            return "The identity provider did not return a valid token. Please try again."
        case .invalidAppleCredential:
            return "Apple Sign-In did not return a valid credential. Please try again."
        case .bindingNotConfirmed:
            return "Your account could not be linked. Please try again."
        }
    }
}

@MainActor
final class LoginViewController: UIViewController {
    var onFinish: ((Bool) -> Void)?

    private let authenticationService: FirebaseAuthenticationService
    private let analytics: AnalyticsTracking
    private let reason: LoginPresentationReason
    private let backgroundView = LoginBackgroundView()
    private let closeButton = UIButton(type: .system)
    private let logoView = LoginLogoView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let appleButton = ASAuthorizationAppleIDButton(
        authorizationButtonType: .continue,
        authorizationButtonStyle: .white
    )
    private let googleButton = UIButton(type: .system)
    private let laterButton = UIButton(type: .system)
    private let legalTextView = UITextView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var loginTask: Task<Void, Never>?

    fileprivate init(
        authenticationService: FirebaseAuthenticationService,
        analytics: AnalyticsTracking,
        reason: LoginPresentationReason
    ) {
        self.authenticationService = authenticationService
        self.analytics = analytics
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        analytics.record(AnalyticsEvent(name: "login_presented", properties: ["reason": reason.rawValue]))
    }

    deinit {
        loginTask?.cancel()
    }

    private func configureView() {
        view.backgroundColor = UIColor(hex: 0x050506)
        configureBackground()
        configureCloseButton()
        configureHero()
        configureButtons()
        configureLegalText()
        configureLoadingIndicator()
    }

    private func configureBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureCloseButton() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        closeButton.tintColor = UIColor(hex: 0xF6F6F8)
        closeButton.setImage(UIImage(named: "login-close")?.withRenderingMode(.alwaysOriginal), for: .normal)
        closeButton.layer.cornerRadius = 19
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        closeButton.accessibilityLabel = "Close sign in"
        closeButton.addTarget(self, action: #selector(handleLater), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.widthAnchor.constraint(equalToConstant: 38),
            closeButton.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    private func configureHero() {
        logoView.translatesAutoresizingMaskIntoConstraints = false
        logoView.layer.shadowColor = UIColor(hex: 0xC8FF35).cgColor
        logoView.layer.shadowOpacity = 0.34
        logoView.layer.shadowRadius = 22
        logoView.layer.shadowOffset = .zero
        logoView.layer.masksToBounds = false

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.attributedText = NSAttributedString(
            string: "PixnovaAI",
            attributes: [
                .font: UIFont.systemFont(ofSize: 34, weight: .bold),
                .foregroundColor: UIColor(hex: 0xF6F6F8),
                .kern: -1
            ]
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        let subtitleParagraph = NSMutableParagraphStyle()
        subtitleParagraph.alignment = .center
        subtitleParagraph.minimumLineHeight = 21.6
        subtitleParagraph.maximumLineHeight = 21.6
        subtitleLabel.attributedText = NSAttributedString(
            string: "Drop your face into trending looks &\nvideos. Sign in to save your creations.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13.5, weight: .regular),
                .foregroundColor: UIColor(hex: 0x9A9AA2),
                .kern: -0.14,
                .paragraphStyle: subtitleParagraph
            ]
        )
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2

        view.addSubview(logoView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            logoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 112),
            logoView.widthAnchor.constraint(equalToConstant: 78),
            logoView.heightAnchor.constraint(equalToConstant: 78),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            titleLabel.topAnchor.constraint(equalTo: logoView.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 54),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -54),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16)
        ])
    }

    private func configureButtons() {
        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.cornerRadius = 17
        appleButton.addTarget(self, action: #selector(handleAppleSignIn), for: .touchUpInside)

        googleButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = "Continue with Google"
        configuration.image = UIImage(named: "google-logo")
        configuration.imagePadding = 14
        configuration.baseForegroundColor = UIColor(hex: 0xF6F6F8)
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        configuration.background.strokeColor = UIColor.white.withAlphaComponent(0.12)
        configuration.background.strokeWidth = 1
        configuration.background.cornerRadius = 17
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 15.3, weight: .bold)
            return outgoing
        }
        googleButton.configuration = configuration
        googleButton.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)

        laterButton.translatesAutoresizingMaskIntoConstraints = false
        laterButton.setTitle("Maybe later", for: .normal)
        laterButton.setTitleColor(UIColor(hex: 0x56565C), for: .normal)
        laterButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        laterButton.addTarget(self, action: #selector(handleLater), for: .touchUpInside)

        view.addSubview(appleButton)
        view.addSubview(googleButton)
        view.addSubview(laterButton)
        NSLayoutConstraint.activate([
            appleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            appleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            appleButton.heightAnchor.constraint(equalToConstant: 60),
            appleButton.bottomAnchor.constraint(equalTo: googleButton.topAnchor, constant: -10),
            googleButton.leadingAnchor.constraint(equalTo: appleButton.leadingAnchor),
            googleButton.trailingAnchor.constraint(equalTo: appleButton.trailingAnchor),
            googleButton.heightAnchor.constraint(equalToConstant: 60),
            googleButton.bottomAnchor.constraint(equalTo: laterButton.topAnchor, constant: -14),
            laterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            laterButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func configureLegalText() {
        legalTextView.translatesAutoresizingMaskIntoConstraints = false
        legalTextView.backgroundColor = .clear
        legalTextView.isEditable = false
        legalTextView.isScrollEnabled = false
        legalTextView.textAlignment = .center
        legalTextView.textContainerInset = .zero
        legalTextView.textContainer.lineFragmentPadding = 0
        legalTextView.delegate = self

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 2
        let attributed = NSMutableAttributedString(
            string: "By continuing, you agree to our\nTerms & Conditions and Privacy Policy",
            attributes: [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor(hex: 0x56565C),
                .paragraphStyle: paragraph
            ]
        )
        addLink(to: attributed, text: "Terms & Conditions", infoKey: "TermsOfServiceURL")
        addLink(to: attributed, text: "Privacy Policy", infoKey: "PrivacyPolicyURL")
        legalTextView.attributedText = attributed
        legalTextView.linkTextAttributes = [
            .foregroundColor: UIColor(hex: 0x9A9AA2),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        view.addSubview(legalTextView)
        NSLayoutConstraint.activate([
            legalTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 50),
            legalTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -50),
            legalTextView.topAnchor.constraint(equalTo: laterButton.bottomAnchor, constant: 2),
            legalTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -15),
            legalTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 46)
        ])
    }

    private func addLink(to attributed: NSMutableAttributedString, text: String, infoKey: String) {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String,
              let url = URL(string: value) else { return }
        attributed.addAttribute(.link, value: url, range: (attributed.string as NSString).range(of: text))
    }

    private func configureLoadingIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = UIColor(hex: 0xC8FF35)
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func handleAppleSignIn() {
        startLogin(provider: "apple") { [authenticationService, weak self] in
            guard let self else { throw CancellationError() }
            return try await authenticationService.signInWithApple(presenting: self)
        }
    }

    @objc private func handleGoogleSignIn() {
        startLogin(provider: "google") { [authenticationService, weak self] in
            guard let self else { throw CancellationError() }
            return try await authenticationService.signInWithGoogle(presenting: self)
        }
    }

    private func startLogin(
        provider: String,
        operation: @escaping () async throws -> AccountSnapshot
    ) {
        guard loginTask == nil else { return }
        setLoading(true)
        analytics.record(
            AnalyticsEvent(name: "login_provider_tapped", properties: ["provider": provider, "reason": reason.rawValue])
        )

        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let account = try await operation()
                guard account.hasLinkedAccount else { throw LoginError.bindingNotConfirmed }
                self.analytics.record(
                    AnalyticsEvent(name: "login_completed", properties: ["provider": provider, "reason": self.reason.rawValue])
                )
                self.onFinish?(true)
            } catch let error as ASAuthorizationError where error.code == .canceled {
                self.setLoading(false)
            } catch let error as GIDSignInError where error.code == .canceled {
                self.setLoading(false)
            } catch is CancellationError {
                self.setLoading(false)
            } catch {
                self.setLoading(false)
                self.presentError(error.localizedDescription)
                self.analytics.record(
                    AnalyticsEvent(
                        name: "login_failed",
                        properties: ["provider": provider, "reason": self.reason.rawValue, "error": error.localizedDescription]
                    )
                )
            }
            self.loginTask = nil
        }
    }

    private func setLoading(_ isLoading: Bool) {
        closeButton.isEnabled = !isLoading
        appleButton.isEnabled = !isLoading
        googleButton.isEnabled = !isLoading
        laterButton.isEnabled = !isLoading
        isLoading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
        [appleButton, googleButton, laterButton].forEach { $0.alpha = isLoading ? 0.5 : 1 }
    }

    private func presentError(_ message: String) {
        let alert = UIAlertController(title: "Sign in failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleLater() {
        guard loginTask == nil else { return }
        analytics.record(AnalyticsEvent(name: "login_dismissed", properties: ["reason": reason.rawValue]))
        onFinish?(false)
    }
}

extension LoginViewController: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        true
    }
}

private final class LoginLogoView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let sparkImageView = UIImageView(image: UIImage(named: "login-logo-spark"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false

        gradientLayer.colors = [
            UIColor(hex: 0xC8FF35).cgColor,
            UIColor(hex: 0x9DDB1F).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 24
        layer.insertSublayer(gradientLayer, at: 0)

        sparkImageView.translatesAutoresizingMaskIntoConstraints = false
        sparkImageView.contentMode = .scaleAspectFit
        addSubview(sparkImageView)
        NSLayoutConstraint.activate([
            sparkImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sparkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            sparkImageView.widthAnchor.constraint(equalToConstant: 40),
            sparkImageView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}

private final class LoginBackgroundView: UIView {
    private let baseGradient = CAGradientLayer()
    private let topAccentGradient = CAGradientLayer()
    private let lowerAccentGradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        baseGradient.colors = [
            UIColor(hex: 0x151D0A).cgColor,
            UIColor(hex: 0x080A07).cgColor,
            UIColor(hex: 0x050506).cgColor
        ]
        baseGradient.locations = [0, 0.46, 1]
        layer.addSublayer(baseGradient)

        topAccentGradient.type = .radial
        topAccentGradient.colors = [
            UIColor(hex: 0xC8FF35).withAlphaComponent(0.24).cgColor,
            UIColor(hex: 0xC8FF35).withAlphaComponent(0).cgColor
        ]
        topAccentGradient.locations = [0, 0.62]
        topAccentGradient.startPoint = CGPoint(x: 0.5, y: 0.08)
        topAccentGradient.endPoint = CGPoint(x: 1, y: 0.72)
        layer.addSublayer(topAccentGradient)

        lowerAccentGradient.type = .radial
        lowerAccentGradient.colors = [
            UIColor(hex: 0x9DDB1F).withAlphaComponent(0.14).cgColor,
            UIColor(hex: 0x9DDB1F).withAlphaComponent(0).cgColor
        ]
        lowerAccentGradient.locations = [0, 0.70]
        lowerAccentGradient.startPoint = CGPoint(x: 0.12, y: 0.78)
        lowerAccentGradient.endPoint = CGPoint(x: 0.62, y: 1.18)
        layer.addSublayer(lowerAccentGradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseGradient.frame = bounds
        topAccentGradient.frame = bounds
        lowerAccentGradient.frame = bounds
    }
}
