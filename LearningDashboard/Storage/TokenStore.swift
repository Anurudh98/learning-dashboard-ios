//
//  TokenStore.swift
//  LearningDashboard
//

import Foundation
import Security

protocol TokenStoreProtocol {
    func saveToken(_ token: String) throws
    func readToken() -> String?
    func deleteToken()
}

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus:
            return "We couldn't securely save your session. Please try again."
        }
    }
}

/// Production token storage: the Keychain, readable only on this device after first unlock.
final class KeychainTokenStore: TokenStoreProtocol {

    private let service: String
    private let account = "auth_token"

    init(service: String = Bundle.main.bundleIdentifier ?? "LearningDashboard") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func saveToken(_ token: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            let addQuery = baseQuery.merging(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func readToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
