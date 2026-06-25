import Foundation

final class RemoteContentRepository: ContentRepository {
    private let apiClient: APIClient
    private let catalogStore: ContentCatalogStoring
    private let notificationCenter: NotificationCenter
    private var allCards: [ContentSection]

    init(
        apiClient: APIClient,
        catalogStore: ContentCatalogStoring,
        notificationCenter: NotificationCenter = .default
    ) {
        self.apiClient = apiClient
        self.catalogStore = catalogStore
        self.notificationCenter = notificationCenter
        allCards = catalogStore.cachedAllCards ?? []
    }

    var cachedAllCards: [ContentSection] {
        allCards
    }

    func cachedHomePage(tab: HomePageTab) -> DiscoverySnapshot? {
        catalogStore.cachedHomePage(tab: tab)
    }

    func fetchHomePage(tab: HomePageTab) async throws -> DiscoverySnapshot {
        let endpoint = APIEndpoint<ServiceEnvelope<DiscoverySnapshot>>(
            method: .get,
            path: "/api/query_home_data",
            queryItems: [URLQueryItem(name: "tab", value: tab.rawValue)]
        )
        let snapshot = try await apiClient.sendService(endpoint)
        try? catalogStore.saveHomePage(snapshot, tab: tab)
        return snapshot
    }

    @discardableResult
    func refreshAllCards() async throws -> [ContentSection] {
        let endpoint = APIEndpoint<ServiceEnvelope<[ContentSection]>>(
            method: .get,
            path: "/api/query_cards",
            queryItems: [URLQueryItem(name: "category_id", value: "0")]
        )
        let cards = try await apiClient.sendService(endpoint)
        let permeatedCards = cards.map { $0.permeatingCardID() }
        try catalogStore.saveAllCards(permeatedCards)
        allCards = permeatedCards
        notificationCenter.post(
            name: ContentNotifications.allCardsDidChange,
            object: nil,
            userInfo: [ContentNotificationUserInfoKey.cards: permeatedCards]
        )
        return permeatedCards
    }
}
