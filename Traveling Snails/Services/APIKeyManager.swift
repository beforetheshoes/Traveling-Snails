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
    private let keychainClient: KeychainClient

    private var inMemoryCache: [String: String] = [:]
    private var hasFetched = false

    init(keychainClient: KeychainClient = .liveValue) {
        self.keychainClient = keychainClient
    }

    // MARK: - Public API

    /// Retrieve a key by name. Checks in-memory cache, then Keychain, then CloudKit.
    func key(for name: String) async -> String {
        // 1. In-memory cache
        if let cached = inMemoryCache[name] {
            return cached
        }

        // 2. Keychain (Data Protection only — no legacy fallback yet)
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
        let success = keychainClient.save(key, value, true)
        if !success {
            Logger.shared.warning("APIKeyManager: Keychain save failed for '\(key)'", category: .network)
        }
    }

    private func readFromKeychain(key: String) -> String? {
        // 1. Try Data Protection keychain (post-PR#84)
        if let value = keychainClient.read(key, true) {
            return value
        }

        // 2. Fallback: try legacy keychain (pre-PR#84 entries)
        if let legacyValue = keychainClient.read(key, false) {
            Logger.shared.info("APIKeyManager: migrating '\(key)' from legacy to Data Protection keychain", category: .network)
            _ = keychainClient.save(key, legacyValue, true)
            keychainClient.delete(key, false)
            return legacyValue
        }

        return nil
    }

    /// Remove all cached keys from Keychain (both Data Protection and legacy)
    func clearKeychain() {
        keychainClient.deleteAll(true)
        keychainClient.deleteAll(false)
        inMemoryCache.removeAll()
        hasFetched = false
    }
}
