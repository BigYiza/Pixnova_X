import Foundation

protocol KeyValueStore {
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
    func string(forKey key: String) -> String?
    func set(_ value: String?, forKey key: String)
    func data(forKey key: String) -> Data?
    func set(_ value: Data?, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func set(_ value: String?, forKey key: String) {
        set(value as Any?, forKey: key)
    }

    func set(_ value: Data?, forKey key: String) {
        set(value as Any?, forKey: key)
    }
}

enum AppStorageKey {
    static let onboardingCompleted = "onboarding.completed.v1"
}
