import Foundation
import Security
import UIKit

final class DeviceIdentifierProvider: DeviceIdentifying {
    private let keychainStore = KeychainStringStore(service: "com.creative.device", account: "device-id")
    private let keyValueStore: KeyValueStore
    private let fallbackKey = "device.id.v1"

    init(keyValueStore: KeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    var deviceID: String {
        if let keychainID = try? keychainStore.read(), !keychainID.isEmpty {
            return keychainID
        }

        if let fallbackID = keyValueStore.string(forKey: fallbackKey), !fallbackID.isEmpty {
            try? keychainStore.save(fallbackID)
            return fallbackID
        }

        let generatedID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        keyValueStore.set(generatedID, forKey: fallbackKey)
        try? keychainStore.save(generatedID)
        return generatedID
    }
}

private struct KeychainStringStore {
    let service: String
    let account: String

    func read() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw AppError.invalidResponse
        }

        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String) throws {
        try delete()

        var item = baseQuery()
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.invalidResponse
        }
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.invalidResponse
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
