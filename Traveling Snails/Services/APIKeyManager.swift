//
//  APIKeyManager.swift
//  Traveling Snails
//
//  Retrieves encrypted API keys from CloudKit public database and
//  caches them in the Keychain for offline access.
//

import CloudKit
import Foundation
import Security

actor APIKeyManager {
    static let shared = APIKeyManager()

    private let container = CKContainer(identifier: "iCloud.TravelingSnails")
    private let keychainService = "com.ryanleewilliams.Traveling-Snails.apikeys"

    private var inMemoryCache: [String: String] = [:]
    private var hasFetched = false

    // MARK: - Public API

    /// Retrieve a key by name. Checks in-memory cache, then Keychain, then CloudKit.
    func key(for name: String) async -> String {
        // 1. In-memory cache
        if let cached = inMemoryCache[name] {
            return cached
        }

        // 2. Keychain
        if let keychainValue = readFromKeychain(key: name) {
            inMemoryCache[name] = keychainValue
            return keychainValue
        }

        // 3. Fetch from CloudKit if we haven't yet this session
        if !hasFetched {
            await fetchAllKeys()
            if let cached = inMemoryCache[name] {
                return cached
            }
        }

        return ""
    }

    /// Force refresh all keys from CloudKit
    func refreshKeys() async {
        await fetchAllKeys()
    }

    // MARK: - CloudKit Fetch

    private static let knownKeyNames = ["googleBooks", "tmdb", "tvdb"]

    private func fetchAllKeys() async {
        hasFetched = true

        let publicDB = container.publicCloudDatabase

        // Fetch by known record IDs directly — avoids needing queryable indexes
        for keyName in Self.knownKeyNames {
            let recordID = CKRecord.ID(recordName: "apikey-\(keyName)")
            do {
                let record = try await publicDB.record(for: recordID)
                if let keyValue = record["keyValue"] as? String {
                    let decrypted = decrypt(keyValue)
                    inMemoryCache[keyName] = decrypted
                    saveToKeychain(key: keyName, value: decrypted)
                    Logger.shared.info("APIKeyManager: loaded key '\(keyName)' from CloudKit", category: .network)
                }
            } catch {
                Logger.shared.warning("APIKeyManager: could not fetch '\(keyName)': \(error.localizedDescription)", category: .network)
            }
        }
    }

    // MARK: - Encryption

    /// Decrypt a key value fetched from CloudKit.
    /// For now uses Base64 encoding as a basic obfuscation layer.
    /// Replace with AES or other encryption if desired.
    private func decrypt(_ encoded: String) -> String {
        guard let data = Data(base64Encoded: encoded),
              let decoded = String(data: data, encoding: .utf8) else {
            return encoded
        }
        return decoded
    }

    // MARK: - Keychain

    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            Logger.shared.warning("APIKeyManager: Keychain save failed for '\(key)': \(status)", category: .network)
        }
    }

    private func readFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    /// Remove all cached keys from Keychain
    func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]
        SecItemDelete(query as CFDictionary)
        inMemoryCache.removeAll()
        hasFetched = false
    }
}
