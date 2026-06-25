import Foundation

protocol ContentCatalogStoring {
    var cachedAllCards: [ContentSection]? { get }
    func cachedHomePage(tab: HomePageTab) -> DiscoverySnapshot?
    func saveAllCards(_ cards: [ContentSection]) throws
    func saveHomePage(_ snapshot: DiscoverySnapshot, tab: HomePageTab) throws
}

final class UserDefaultsContentCatalogStore: ContentCatalogStoring {
    private let keyValueStore: KeyValueStore
    private let cardsKey = "cached_all_data"
    private let timestampKey = "cached_data_timestamp"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(keyValueStore: KeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    var cachedAllCards: [ContentSection]? {
        guard let data = keyValueStore.data(forKey: cardsKey) else {
            return nil
        }
        return try? decoder.decode([ContentSection].self, from: data).map { $0.permeatingCardID() }
    }

    func cachedHomePage(tab: HomePageTab) -> DiscoverySnapshot? {
        guard let data = keyValueStore.data(forKey: homePageKey(tab: tab)) else {
            return nil
        }
        return try? decoder.decode(DiscoverySnapshot.self, from: data)
    }

    func saveAllCards(_ cards: [ContentSection]) throws {
        let permeatedCards = cards.map { $0.permeatingCardID() }
        let data = try encoder.encode(permeatedCards)
        keyValueStore.set(data, forKey: cardsKey)
        keyValueStore.set(String(Date().timeIntervalSince1970), forKey: timestampKey)
    }

    func saveHomePage(_ snapshot: DiscoverySnapshot, tab: HomePageTab) throws {
        let data = try encoder.encode(snapshot)
        keyValueStore.set(data, forKey: homePageKey(tab: tab))
        keyValueStore.set(String(Date().timeIntervalSince1970), forKey: homePageTimestampKey(tab: tab))
    }

    private func homePageKey(tab: HomePageTab) -> String {
        "cached_homepage_data_type_\(tab.rawValue)"
    }

    private func homePageTimestampKey(tab: HomePageTab) -> String {
        "cached_data_timestamp_type_\(tab.rawValue)"
    }
}
