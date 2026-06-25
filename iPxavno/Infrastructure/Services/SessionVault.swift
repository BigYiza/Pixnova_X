import Foundation
import Security

final class SessionVault: SessionProviding {
    private let keychain = KeychainCredentialStore(service: "com.creative.session", account: "primary")
    private(set) var currentCredential: AuthCredential?

    init() {
        currentCredential = try? keychain.read()
    }

    func save(_ credential: AuthCredential) throws {
        currentCredential = credential
        try keychain.save(credential)
    }

    func clear() {
        currentCredential = nil
        try? keychain.delete()
    }
}

private struct KeychainCredentialStore {
    let service: String
    let account: String

    func read() throws -> AuthCredential? {
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

        return try JSONDecoder().decode(AuthCredential.self, from: data)
    }

    func save(_ credential: AuthCredential) throws {
        let data = try JSONEncoder().encode(credential)
        try delete()

        var item = baseQuery()
        item[kSecValueData as String] = data
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
