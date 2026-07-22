import Foundation

struct DependencyContainer {
    let sessionVault: SessionVault
    let deviceIdentifier: DeviceIdentifying
    let accountRepository: AccountRepository
    let membershipHandler: MembershipHandling
    let membershipPurchaseHandler: MembershipPurchaseHandling
    let diamondPurchaseHandler: DiamondPurchaseHandling
    let contentRepository: ContentRepository
    let generationRepository: GenerationRepository
    let historyRepository: HistoryRepository
    let generationMediaUploader: GenerationMediaUploading
    let generationWorkflowRunner: GenerationWorkflowRunning
    let analytics: AnalyticsTracking
    let solarEngine: SolarEngineAnalyticsDestination
    let keyValueStore: KeyValueStore

    static func live() -> DependencyContainer {
        let keyValueStore = UserDefaults.standard
        let sessionVault = SessionVault()
        let deviceIdentifier = DeviceIdentifierProvider(keyValueStore: keyValueStore)
        let accountStore = UserDefaultsAccountStore(keyValueStore: keyValueStore)
        let contentCatalogStore = UserDefaultsContentCatalogStore(keyValueStore: keyValueStore)
        let solarEngine = SolarEngineAnalyticsDestination()
        let analytics = AnalyticsPipeline(
            destinations: [
                FirebaseAnalyticsDestination(),
                solarEngine,
                ConsoleAnalyticsDestination(),
            ],
            propertyProviders: [
                {
                    ["device_id": deviceIdentifier.deviceID]
                }
            ]
        )
        solarEngine.analytics = analytics
        let environment = APIEnvironment.current
        let headerProvider = DefaultRequestHeaderProvider(
            sessionProvider: sessionVault,
            deviceIdentifier: deviceIdentifier,
            environment: environment
        )
        let apiClient = APIClient(
            environment: environment,
            headerProvider: headerProvider,
            analytics: analytics
        )
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
        let paymentRepository = RemoteMembershipPaymentRepository(apiClient: apiClient)
        let generationRepository = RemoteGenerationRepository(apiClient: apiClient)
        let historyRepository = RemoteHistoryRepository(apiClient: apiClient)
        let mediaUploader = OSSGenerationMediaUploader(apiClient: apiClient)
        let purchaseHandler = StoreKitMembershipPurchaseHandler(
            catalogProvider: { membershipHandler.cachedMembership.productCatalog },
            paymentRepository: paymentRepository,
            accountRepository: accountRepository,
            membershipHandler: membershipHandler,
            analytics: analytics
        )
        let diamondPurchaseHandler = StoreKitDiamondPurchaseHandler(
            catalogProvider: { .configured },
            paymentRepository: paymentRepository,
            membershipHandler: membershipHandler,
            analytics: analytics
        )
        let workflowRunner = DefaultGenerationWorkflowRunner(
            membershipHandler: membershipHandler,
            mediaUploader: mediaUploader,
            generationRepository: generationRepository,
            analytics: analytics
        )
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
            membershipPurchaseHandler: purchaseHandler,
            diamondPurchaseHandler: diamondPurchaseHandler,
            contentRepository: remoteContent,
            generationRepository: generationRepository,
            historyRepository: historyRepository,
            generationMediaUploader: mediaUploader,
            generationWorkflowRunner: workflowRunner,
            analytics: analytics,
            solarEngine: solarEngine,
            keyValueStore: keyValueStore
        )
    }
}
