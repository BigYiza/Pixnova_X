import Foundation

protocol AccountStoring {
    var currentAccount: AccountSnapshot? { get }
    func save(_ account: AccountSnapshot) throws
    func clear()
}

final class UserDefaultsAccountStore: AccountStoring {
    private let keyValueStore: KeyValueStore
    private let accountKey = "currentUserAccount"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(keyValueStore: KeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    var currentAccount: AccountSnapshot? {
        guard let json = keyValueStore.string(forKey: accountKey),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? decoder.decode(AccountSnapshot.self, from: data)
    }

    func save(_ account: AccountSnapshot) throws {
        let data = try encoder.encode(account)
        let json = String(data: data, encoding: .utf8)
        keyValueStore.set(json, forKey: accountKey)
    }

    func clear() {
        keyValueStore.set(nil as String?, forKey: accountKey)
    }
}
