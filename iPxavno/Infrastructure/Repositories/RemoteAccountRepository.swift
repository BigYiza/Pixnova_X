import Foundation

final class RemoteAccountRepository: AccountRepository {
    private let apiClient: APIClient
    private let sessionVault: SessionVault
    private let accountStore: AccountStoring
    private let notificationCenter: NotificationCenter

    init(
        apiClient: APIClient,
        sessionVault: SessionVault,
        accountStore: AccountStoring,
        notificationCenter: NotificationCenter = .default
    ) {
        self.apiClient = apiClient
        self.sessionVault = sessionVault
        self.accountStore = accountStore
        self.notificationCenter = notificationCenter

        if let credential = accountStore.currentAccount?.credential {
            try? sessionVault.save(credential)
        }
    }

    var cachedAccount: AccountSnapshot? {
        accountStore.currentAccount
    }

    @discardableResult
    func prepareSession() async throws -> AccountSnapshot {
        if let account = accountStore.currentAccount, let credential = account.credential, credential.isValid {
            try sessionVault.save(credential)
            return account
        }

        return try await login()
    }

    @discardableResult
    func refreshSessionIfNeeded(force: Bool = false) async throws -> AccountSnapshot {
        let account = try await prepareSession()

        guard force || account.credential?.needsRefresh == true else {
            return account
        }

        do {
            return try await refreshToken(from: account)
        } catch {
            return try await login()
        }
    }

    @discardableResult
    func synchronizeAccount() async throws -> AccountSnapshot {
        _ = try await refreshSessionIfNeeded(force: false)
        _ = try? await refreshEntitlements()
        _ = try? await refreshUserProfile()
        return try await fetchUserGroups(positions: [
            AccountUserGroupPosition.membershipCloseButton,
            AccountUserGroupPosition.membershipPaywall
        ])
    }

    @discardableResult
    func refreshUserProfile() async throws -> AccountSnapshot {
        _ = try await refreshSessionIfNeeded(force: false)
        let endpoint = APIEndpoint<ServiceEnvelope<UserInfoPayload>>(
            method: .get,
            path: "/api/query_user_info"
        )

        do {
            let payload = try await apiClient.send(endpoint).requirePayload()
            var account = accountStore.currentAccount ?? .empty
            let previousInvitationInfo = account.invitationInfo
            account.applyUserInfo(payload)
            try persist(account)
            postInvitationNotifications(previous: previousInvitationInfo, current: account)
            return account
        } catch AppError.tokenExpired {
            _ = try await refreshSessionIfNeeded(force: true)
            return try await refreshUserProfile()
        }
    }

    @discardableResult
    func refreshEntitlements() async throws -> AccountSnapshot {
        _ = try await refreshSessionIfNeeded(force: false)
        let endpoint = APIEndpoint<ServiceEnvelope<EntitlementSnapshot>>(
            method: .get,
            path: "/api/query_vip_status"
        )

        do {
            let entitlement = try await apiClient.send(endpoint).requirePayload()
            var account = accountStore.currentAccount ?? .empty
            let wasVIP = account.isVIP
            account.applyEntitlement(entitlement)
            try persist(account)

            if wasVIP != account.isVIP {
                notificationCenter.post(
                    name: AccountNotifications.membershipStateDidChange,
                    object: nil,
                    userInfo: [AccountNotificationUserInfoKey.account: account]
                )
            }

            return account
        } catch AppError.tokenExpired {
            _ = try await refreshSessionIfNeeded(force: true)
            return try await refreshEntitlements()
        }
    }

    @discardableResult
    func fetchUserGroups(positions: [String]) async throws -> AccountSnapshot {
        _ = try await refreshSessionIfNeeded(force: false)
        let body = try JSONEncoder().encode(UserGroupRequest(positions: positions))
        let endpoint = APIEndpoint<ServiceEnvelope<[String: JSONValue]>>(
            method: .post,
            path: "/api/query_user_group_by_pos",
            body: body
        )

        do {
            let groupMap = try await apiClient.send(endpoint).requirePayload()
            var account = accountStore.currentAccount ?? .empty
            account.userGroupMap = groupMap
            try persist(account)
            return account
        } catch AppError.tokenExpired {
            _ = try await refreshSessionIfNeeded(force: true)
            return try await fetchUserGroups(positions: positions)
        }
    }

    private func login() async throws -> AccountSnapshot {
        let endpoint = APIEndpoint<ServiceEnvelope<LoginPayload>>(
            method: .post,
            path: "/openapi/login",
            requiresAuthentication: false
        )
        let payload = try await apiClient.send(endpoint).requirePayload()
        var account = accountStore.currentAccount ?? .empty
        account.applyLogin(payload)
        try persist(account)
        return account
    }

    private func refreshToken(from account: AccountSnapshot) async throws -> AccountSnapshot {
        let endpoint = APIEndpoint<ServiceEnvelope<LoginPayload>>(
            method: .post,
            path: "/openapi/refresh_token"
        )
        let payload = try await apiClient.send(endpoint).requirePayload()
        var updatedAccount = account
        updatedAccount.applyLogin(payload)
        try persist(updatedAccount)
        return updatedAccount
    }

    private func persist(_ account: AccountSnapshot) throws {
        try accountStore.save(account)
        if let credential = account.credential {
            try sessionVault.save(credential)
        }
        notificationCenter.post(
            name: AccountNotifications.accountDidChange,
            object: nil,
            userInfo: [AccountNotificationUserInfoKey.account: account]
        )
    }

    private func postInvitationNotifications(previous: InvitationInfo?, current account: AccountSnapshot) {
        guard previous != nil else { return }

        notificationCenter.post(
            name: AccountNotifications.invitationInfoDidUpdateResetFlag,
            object: nil,
            userInfo: [AccountNotificationUserInfoKey.account: account]
        )

        if account.displayInvitationInfo != nil || account.invitationInfo?.shouldShowDialog == true {
            notificationCenter.post(
                name: AccountNotifications.invitationInfoDidUpdateNeedShowDialog,
                object: nil,
                userInfo: [AccountNotificationUserInfoKey.account: account]
            )
        }
    }
}

private struct UserGroupRequest: Encodable {
    let positions: [String]

    enum CodingKeys: String, CodingKey {
        case positions = "postion_list"
    }
}
