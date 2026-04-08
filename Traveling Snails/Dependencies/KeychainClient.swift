//
//  KeychainClient.swift
//  Traveling Snails
//
//  Abstraction over Security framework keychain operations,
//  supporting both Data Protection and legacy keychains.
//

import Dependencies
import Foundation
import Security

struct KeychainClient: Sendable {
    var read: @Sendable (_ key: String, _ useDataProtection: Bool) -> String?
    var save: @Sendable (_ key: String, _ value: String, _ useDataProtection: Bool) -> Bool
    var delete: @Sendable (_ key: String, _ useDataProtection: Bool) -> Void
    var deleteAll: @Sendable (_ useDataProtection: Bool) -> Void
}

extension KeychainClient: DependencyKey {

    private static let keychainService = "com.ryanleewilliams.Traveling-Snails.apikeys"

    static let liveValue = KeychainClient(
        read: { key, useDataProtection in
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
            }

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            guard status == errSecSuccess,
                  let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                return nil
            }
            return value
        },
        save: { key, value, useDataProtection in
            guard let data = value.data(using: .utf8) else { return false }

            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key,
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
            }

            // Delete existing
            SecItemDelete(query as CFDictionary)

            // Add new
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let status = SecItemAdd(addQuery as CFDictionary, nil)
            return status == errSecSuccess
        },
        delete: { key, useDataProtection in
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: key,
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
            }
            SecItemDelete(query as CFDictionary)
        },
        deleteAll: { useDataProtection in
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
            ]
            if useDataProtection {
                query[kSecUseDataProtectionKeychain as String] = true
            }
            SecItemDelete(query as CFDictionary)
        }
    )

    static let testValue = KeychainClient(
        read: { _, _ in nil },
        save: { _, _, _ in false },
        delete: { _, _ in },
        deleteAll: { _ in }
    )
}

extension DependencyValues {
    var keychainClient: KeychainClient {
        get { self[KeychainClient.self] }
        set { self[KeychainClient.self] = newValue }
    }
}
