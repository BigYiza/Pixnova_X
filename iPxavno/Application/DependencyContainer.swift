import Foundation

struct DependencyContainer {
    let sessionVault: SessionVault
    let deviceIdentifier: DeviceIdentifying
    let accountRepository: AccountRepository
    let membershipHandler: MembershipHandling
    let contentRepository: ContentRepository
    let generationRepository: GenerationRepository
    let analytics: AnalyticsTracking
    let keyValueStore: KeyValueStore

    static func live() -> DependencyContainer {
        let keyValueStore = UserDefaults.standard
        let sessionVault = SessionVault()
        let deviceIdentifier = DeviceIdentifierProvider(keyValueStore: keyValueStore)
        let accountStore = UserDefaultsAccountStore(keyValueStore: keyValueStore)
        let contentCatalogStore = UserDefaultsContentCatalogStore(keyValueStore: keyValueStore)
        let headerProvider = DefaultRequestHeaderProvider(
            sessionProvider: sessionVault,
            deviceIdentifier: deviceIdentifier
        )
        let apiClient = APIClient(environment: .current, headerProvider: headerProvider)
        let remoteContent = RemoteContentRepository(
            apiClient: apiClient,
            catalogStore: contentCatalogStore
        )
        let accountRepository = RemoteAccountRepository(
            apiClient: apiClient,
            sessionVault: sessionVault,
            accountStore: accountStore
        )
        let membershipHandler = DefaultMembershipHandler(accountRepository: accountRepository)
        apiClient.tokenRefreshHandler = { [weak accountRepository] in
            guard let accountRepository else {
                throw AppError.tokenExpired
            }
            _ = try await accountRepository.refreshSessionIfNeeded(force: true)
        }

        return DependencyContainer(
            sessionVault: sessionVault,
            deviceIdentifier: deviceIdentifier,
            accountRepository: accountRepository,
            membershipHandler: membershipHandler,
            contentRepository: remoteContent,
            generationRepository: RemoteGenerationRepository(apiClient: apiClient),
            analytics: ConsoleAnalyticsTracker(),
            keyValueStore: keyValueStore
        )
    }
}
