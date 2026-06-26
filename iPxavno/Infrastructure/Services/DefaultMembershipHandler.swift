import Foundation

final class DefaultMembershipHandler: MembershipHandling {
    private let accountRepository: AccountRepository
    private let notificationCenter: NotificationCenter

    init(
        accountRepository: AccountRepository,
        notificationCenter: NotificationCenter = .default
    ) {
        self.accountRepository = accountRepository
        self.notificationCenter = notificationCenter
    }

    var cachedMembership: MembershipSnapshot {
        MembershipSnapshot(account: accountRepository.cachedAccount ?? .empty)
    }

    @discardableResult
    func refreshStatus() async throws -> MembershipSnapshot {
        let account = try await accountRepository.refreshEntitlements()
        return MembershipSnapshot(account: account)
    }

    @discardableResult
    func maintainStatusAfterSessionPrepared() async throws -> MembershipSnapshot {
        _ = try await accountRepository.refreshSessionIfNeeded(force: false)
        let membership = try await refreshStatus()
        _ = try? await accountRepository.refreshUserProfile()
        _ = try? await accountRepository.fetchUserGroups(positions: [
            AccountUserGroupPosition.membershipCloseButton,
            AccountUserGroupPosition.membershipPaywall
        ])
        return MembershipSnapshot(account: accountRepository.cachedAccount ?? membership.account)
    }

    @discardableResult
    func membershipStatus(forceRefresh: Bool = false) async throws -> MembershipSnapshot {
        if forceRefresh {
            return try await maintainStatusAfterSessionPrepared()
        }

        let account = try await accountRepository.refreshSessionIfNeeded(force: false)
        return MembershipSnapshot(account: account)
    }

    func access(to template: CreativeTemplate) -> MembershipAccessDecision {
        cachedMembership.access(to: template)
    }

    func accessToCutout() -> MembershipAccessDecision {
        cachedMembership.accessToCutout()
    }

    func accessToDiamonds(required: Int) -> MembershipAccessDecision {
        cachedMembership.accessToDiamonds(required: required)
    }

    func shouldApplyWatermark() -> Bool {
        cachedMembership.shouldApplyWatermark
    }

    func canSkipWaiting() -> Bool {
        cachedMembership.canSkipWaiting
    }

    func freeBenefitPresentation() -> MembershipFreeBenefitPresentation {
        cachedMembership.freeBenefitPresentation
    }

    func observeMembershipChanges(_ handler: @escaping (MembershipSnapshot) -> Void) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: AccountNotifications.accountDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let account = notification.userInfo?[AccountNotificationUserInfoKey.account] as? AccountSnapshot else {
                return
            }
            handler(MembershipSnapshot(account: account))
        }
    }
}
