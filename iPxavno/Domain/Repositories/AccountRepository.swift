import Foundation

protocol AccountRepository: AnyObject {
    var cachedAccount: AccountSnapshot? { get }

    func clearSession()

    @discardableResult
    func prepareSession() async throws -> AccountSnapshot

    @discardableResult
    func refreshSessionIfNeeded(force: Bool) async throws -> AccountSnapshot

    @discardableResult
    func synchronizeAccount() async throws -> AccountSnapshot

    @discardableResult
    func refreshUserProfile() async throws -> AccountSnapshot

    @discardableResult
    func refreshEntitlements() async throws -> AccountSnapshot

    @discardableResult
    func fetchUserGroups(positions: [String]) async throws -> AccountSnapshot

    @discardableResult
    func restoreAccount(using transactionIDs: [String]) async throws -> AccountSnapshot

    @discardableResult
    func bindFirebaseAccount(idToken: String, platform: String) async throws -> AccountSnapshot

    @discardableResult
    func removeThirdPartyBindings(fallbackPlatform: String?) async throws -> AccountSnapshot
}
