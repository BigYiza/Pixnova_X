import Foundation

struct ProfileViewState {
    var isLoading: Bool
    var displayName: String
    var subtitle: String
    var userID: String
    var diamonds: String
    var videoCredits: String
    var membership: String
    var inviteState: String
    var errorMessage: String?

    static let initial = ProfileViewState(
        isLoading: false,
        displayName: "Guest Creator",
        subtitle: "Account and assets",
        userID: "-",
        diamonds: "0",
        videoCredits: "0",
        membership: "Free",
        inviteState: "Available",
        errorMessage: nil
    )
}

@MainActor
final class ProfileViewModel {
    let state = Observable(ProfileViewState.initial)

    private let accountRepository: AccountRepository
    private let analytics: AnalyticsTracking
    private var accountObserver: NSObjectProtocol?

    init(accountRepository: AccountRepository, analytics: AnalyticsTracking) {
        self.accountRepository = accountRepository
        self.analytics = analytics
        observeAccountChanges()
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func load() {
        if let cachedAccount = accountRepository.cachedAccount {
            state.value = makeState(from: cachedAccount, isLoading: true, errorMessage: nil)
        } else {
            state.value = ProfileViewState(
                isLoading: true,
                displayName: state.value.displayName,
                subtitle: state.value.subtitle,
                userID: state.value.userID,
                diamonds: state.value.diamonds,
                videoCredits: state.value.videoCredits,
                membership: state.value.membership,
                inviteState: state.value.inviteState,
                errorMessage: nil
            )
        }

        Task {
            do {
                let account = try await accountRepository.synchronizeAccount()
                analytics.record(AnalyticsEvent(name: "profile_loaded", properties: ["member": "\(account.isVIP)"]))
                state.value = makeState(from: account, isLoading: false, errorMessage: nil)
            } catch {
                let cachedAccount = accountRepository.cachedAccount
                state.value = cachedAccount.map {
                    makeState(from: $0, isLoading: false, errorMessage: nil)
                } ?? ProfileViewState(
                    isLoading: false,
                    displayName: "Guest Creator",
                    subtitle: "Offline account snapshot",
                    userID: "-",
                    diamonds: "0",
                    videoCredits: "0",
                    membership: "Free",
                    inviteState: "Unavailable",
                    errorMessage: nil
                )
            }
        }
    }

    private func observeAccountChanges() {
        accountObserver = NotificationCenter.default.addObserver(
            forName: AccountNotifications.accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let account = notification.userInfo?[AccountNotificationUserInfoKey.account] as? AccountSnapshot else {
                return
            }
            Task { @MainActor in
                self.state.value = self.makeState(from: account, isLoading: false, errorMessage: nil)
            }
        }
    }

    private func makeState(
        from account: AccountSnapshot,
        isLoading: Bool,
        errorMessage: String?
    ) -> ProfileViewState {
        ProfileViewState(
            isLoading: isLoading,
            displayName: account.isVIP ? "Member Creator" : "Guest Creator",
            subtitle: account.isVIP ? membershipSubtitle(account) : "Free workspace",
            userID: account.userID.isEmpty ? "-" : account.userID,
            diamonds: "\(account.diamonds)",
            videoCredits: "\(account.videoTimes)",
            membership: account.isVIP ? "Active" : "Free",
            inviteState: inviteStateText(account.invitationRedeemState),
            errorMessage: errorMessage
        )
    }

    private func membershipSubtitle(_ account: AccountSnapshot) -> String {
        guard let vipExpirationTime = account.vipExpirationTime, vipExpirationTime > 0 else {
            return "Membership active"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Valid until \(formatter.string(from: Date(timeIntervalSince1970: vipExpirationTime)))"
    }

    private func inviteStateText(_ state: InvitationRedeemState) -> String {
        switch state {
        case .redeemed:
            return "Redeemed"
        case .expired:
            return "Expired"
        case .available:
            return "Available"
        }
    }
}
