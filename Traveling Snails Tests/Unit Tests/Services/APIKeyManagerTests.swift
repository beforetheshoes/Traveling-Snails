//
//  APIKeyManagerTests.swift
//  Traveling Snails Tests
//

import Foundation
import os
import Testing
@testable import Traveling_Snails

@Suite("APIKeyManager Keychain Migration Tests")
struct APIKeyManagerTests {

    // MARK: - Helpers

    private final class CallRecorder: Sendable {
        private let _readCalls = OSAllocatedUnfairLock<[(key: String, useDP: Bool)]>(initialState: [])
        private let _saveCalls = OSAllocatedUnfairLock<[(key: String, value: String, useDP: Bool)]>(initialState: [])
        private let _deleteCalls = OSAllocatedUnfairLock<[(key: String, useDP: Bool)]>(initialState: [])
        private let _deleteAllCalls = OSAllocatedUnfairLock<[Bool]>(initialState: [])

        var readCalls: [(key: String, useDP: Bool)] { _readCalls.withLock { $0 } }
        var saveCalls: [(key: String, value: String, useDP: Bool)] { _saveCalls.withLock { $0 } }
        var deleteCalls: [(key: String, useDP: Bool)] { _deleteCalls.withLock { $0 } }
        var deleteAllCalls: [Bool] { _deleteAllCalls.withLock { $0 } }

        func recordRead(_ key: String, _ useDP: Bool) {
            _readCalls.withLock { $0.append((key, useDP)) }
        }
        func recordSave(_ key: String, _ value: String, _ useDP: Bool) {
            _saveCalls.withLock { $0.append((key, value, useDP)) }
        }
        func recordDelete(_ key: String, _ useDP: Bool) {
            _deleteCalls.withLock { $0.append((key, useDP)) }
        }
        func recordDeleteAll(_ useDP: Bool) {
            _deleteAllCalls.withLock { $0.append(useDP) }
        }
    }

    private static func makeMockKeychain(
        dataProtection: [String: String] = [:],
        legacy: [String: String] = [:]
    ) -> (client: KeychainClient, recorder: CallRecorder) {
        let recorder = CallRecorder()
        let dp = dataProtection
        let leg = legacy

        let client = KeychainClient(
            read: { key, useDP in
                recorder.recordRead(key, useDP)
                return useDP ? dp[key] : leg[key]
            },
            save: { key, value, useDP in
                recorder.recordSave(key, value, useDP)
                return true
            },
            delete: { key, useDP in
                recorder.recordDelete(key, useDP)
            },
            deleteAll: { useDP in
                recorder.recordDeleteAll(useDP)
            }
        )
        return (client, recorder)
    }

    // MARK: - Tests

    @Test("Returns key from Data Protection keychain when present", .tags(.unit, .fast, .parallel))
    func dataProtectionKey_returnsDirectly() async {
        let (client, recorder) = Self.makeMockKeychain(dataProtection: ["tmdb": "dp-api-key"])
        let manager = APIKeyManager(keychainClient: client)

        let result = await manager.key(for: "tmdb")

        #expect(result == "dp-api-key")
        let reads = recorder.readCalls
        #expect(reads.count == 1)
        #expect(reads[0].useDP == true)
    }

    @Test("Falls back to legacy keychain when Data Protection is empty", .tags(.unit, .fast, .parallel))
    func fallsBackToLegacy_whenDataProtectionEmpty() async {
        let (client, _) = Self.makeMockKeychain(legacy: ["tmdb": "legacy-api-key"])
        let manager = APIKeyManager(keychainClient: client)

        let result = await manager.key(for: "tmdb")

        #expect(result == "legacy-api-key")
    }

    @Test("Migrates legacy key to Data Protection keychain", .tags(.unit, .fast, .parallel))
    func migratesLegacyKey_toDataProtection() async {
        let (client, recorder) = Self.makeMockKeychain(legacy: ["tmdb": "legacy-api-key"])
        let manager = APIKeyManager(keychainClient: client)

        _ = await manager.key(for: "tmdb")

        let saves = recorder.saveCalls
        let migrationSave = saves.first(where: { $0.key == "tmdb" && $0.useDP == true })
        #expect(migrationSave != nil, "Expected a save to Data Protection keychain")
        #expect(migrationSave?.value == "legacy-api-key")
    }

    @Test("Deletes legacy key after migration", .tags(.unit, .fast, .parallel))
    func deletesLegacyKey_afterMigration() async {
        let (client, recorder) = Self.makeMockKeychain(legacy: ["tmdb": "legacy-api-key"])
        let manager = APIKeyManager(keychainClient: client)

        _ = await manager.key(for: "tmdb")

        let deletes = recorder.deleteCalls
        let legacyDelete = deletes.first(where: { $0.key == "tmdb" && $0.useDP == false })
        #expect(legacyDelete != nil, "Expected legacy keychain entry to be deleted")
    }

    @Test("Returns empty string when both keychains are empty", .tags(.unit, .fast, .parallel))
    func returnsEmpty_whenBothKeychainsEmpty() async {
        let (client, _) = Self.makeMockKeychain()
        let manager = APIKeyManager(keychainClient: client)

        let result = await manager.key(for: "nonexistent")

        #expect(result == "")
    }
}
