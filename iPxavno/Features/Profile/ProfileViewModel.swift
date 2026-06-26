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

    private let membershipHandler: MembershipHandling
    private let analytics: AnalyticsTracking
    private var accountObserver: NSObjectProtocol?

    init(membershipHandler: MembershipHandling, analytics: AnalyticsTracking) {
        self.membershipHandler = membershipHandler
        self.analytics = analytics
        observeAccountChanges()
    }

    deinit {
        if let accountObserver {
            NotificationCenter.default.removeObserver(accountObserver)
        }
    }

    func load() {
        let cachedMembership = membershipHandler.cachedMembership
        if !cachedMembership.account.userID.isEmpty {
            state.value = makeState(from: cachedMembership, isLoading: true, errorMessage: nil)
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
                let membership = try await membershipHandler.membershipStatus(forceRefresh: true)
                analytics.record(AnalyticsEvent(name: "profile_loaded", properties: ["member": "\(membership.isVIP)"]))
                state.value = makeState(from: membership, isLoading: false, errorMessage: nil)
            } catch {
                let cachedMembership = membershipHandler.cachedMembership
                if !cachedMembership.account.userID.isEmpty {
                    state.value = makeState(from: cachedMembership, isLoading: false, errorMessage: nil)
                    return
                }

                state.value = ProfileViewState(
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
        accountObserver = membershipHandler.observeMembershipChanges { [weak self] membership in
            guard let self else { return }
            Task { @MainActor in
                self.state.value = self.makeState(from: membership, isLoading: false, errorMessage: nil)
            }
        }
    }

    private func makeState(
        from membership: MembershipSnapshot,
        isLoading: Bool,
        errorMessage: String?
    ) -> ProfileViewState {
        let account = membership.account
        return ProfileViewState(
            isLoading: isLoading,
            displayName: membership.isVIP ? "Member Creator" : "Guest Creator",
            subtitle: membership.isVIP ? membershipSubtitle(membership) : "Free workspace",
            userID: account.userID.isEmpty ? "-" : account.userID,
            diamonds: "\(membership.diamonds)",
            videoCredits: "\(membership.videoTimes)",
            membership: membership.isVIP ? "Active" : "Free",
            inviteState: inviteStateText(account.invitationRedeemState),
            errorMessage: errorMessage
        )
    }

    private func membershipSubtitle(_ membership: MembershipSnapshot) -> String {
        guard let expirationDate = membership.expirationDate else {
            return "Membership active"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Valid until \(formatter.string(from: expirationDate))"
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
