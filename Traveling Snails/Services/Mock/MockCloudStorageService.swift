//
//  MockCloudStorageService.swift
//  Traveling Snails
//
//

import Foundation
import os.lock

enum MockCloudStorageValue: Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
}

/// Mock implementation of CloudStorageService for testing
/// Provides in-memory key-value storage without iCloud dependency
final class MockCloudStorageService: CloudStorageService, @unchecked Sendable {
    // MARK: - Thread-Safe Storage
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Mock Configuration (Thread-Safe)
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var _mockIsAvailable: Bool = true
    nonisolated(unsafe) private var _mockSynchronizeResult: Bool = true
    nonisolated(unsafe) private var _mockSyncDelay: TimeInterval = 0.05
    nonisolated(unsafe) private var _synchronizeCallCount: Int = 0

    // MARK: - Storage
    nonisolated(unsafe) private var storage: [String: MockCloudStorageValue] = [:]

    // MARK: - Initialization

    init() {
        // Mock service starts with empty storage
    }

    // MARK: - Thread-Safe Configuration Accessors

    var mockIsAvailable: Bool {
        get { lock.withLock { _mockIsAvailable } }
        set { lock.withLock { _mockIsAvailable = newValue } }
    }

    var mockSynchronizeResult: Bool {
        get { lock.withLock { _mockSynchronizeResult } }
        set { lock.withLock { _mockSynchronizeResult = newValue } }
    }

    var mockSyncDelay: TimeInterval {
        get { lock.withLock { _mockSyncDelay } }
        set { lock.withLock { _mockSyncDelay = newValue } }
    }

    var synchronizeCallCount: Int {
        lock.withLock { _synchronizeCallCount }
    }

    // MARK: - CloudStorageService Implementation

    func setString(_ value: String, forKey key: String) {
        lock.withLock { storage[key] = .string(value) }
    }

    func getString(forKey key: String) -> String? {
        lock.withLock {
            guard case let .string(value)? = storage[key] else { return nil }
            return value
        }
    }

    func setInteger(_ value: Int, forKey key: String) {
        lock.withLock { storage[key] = .int(value) }
    }

    func getInteger(forKey key: String) -> Int {
        lock.withLock {
            guard case let .int(value)? = storage[key] else { return 0 }
            return value
        }
    }

    func setBoolean(_ value: Bool, forKey key: String) {
        lock.withLock { storage[key] = .bool(value) }
    }

    func getBoolean(forKey key: String) -> Bool {
        lock.withLock {
            guard case let .bool(value)? = storage[key] else { return false }
            return value
        }
    }

    func setDouble(_ value: Double, forKey key: String) {
        lock.withLock { storage[key] = .double(value) }
    }

    func getDouble(forKey key: String) -> Double {
        lock.withLock {
            guard case let .double(value)? = storage[key] else { return 0.0 }
            return value
        }
    }

    func removeValue(forKey key: String) {
        _ = lock.withLock { storage.removeValue(forKey: key) }
    }

    @discardableResult
    func synchronize() -> Bool {
        // Simulate sync delay if configured
        if mockSyncDelay > 0 {
            Thread.sleep(forTimeInterval: mockSyncDelay)
        }

        // Track call count
        lock.withLock { _synchronizeCallCount += 1 }

        return mockSynchronizeResult
    }

    var isAvailable: Bool {
        lock.withLock { _mockIsAvailable }
    }

    // MARK: - Mock Control Methods

    /// Configure mock to simulate available cloud storage
    func configureAvailable() {
        mockIsAvailable = true
        mockSynchronizeResult = true
    }

    /// Configure mock to simulate unavailable cloud storage
    func configureUnavailable() {
        mockIsAvailable = false
        mockSynchronizeResult = false
    }

    /// Configure mock to simulate sync failures
    func configureSyncFailure() {
        mockIsAvailable = true
        mockSynchronizeResult = false
    }

    /// Reset mock to clean state for next test
    func resetForTesting() {
        lock.withLock {
            storage.removeAll()
            _synchronizeCallCount = 0
        }
        lock.withLock {
            _mockIsAvailable = true
            _mockSynchronizeResult = true
            _mockSyncDelay = 0.05
        }
    }

    /// Get all stored keys (for test verification)
    func getAllKeys() -> [String] {
        lock.withLock { Array(storage.keys) }
    }

    /// Get all stored values (for test verification)
    func getAllValues() -> [String: MockCloudStorageValue] {
        lock.withLock { storage }
    }

    /// Check if a key exists (for test verification)
    func hasKey(_ key: String) -> Bool {
        lock.withLock { storage[key] != nil }
    }

    /// Get the number of stored items (for test verification)
    var itemCount: Int {
        lock.withLock { storage.count }
    }

    /// Manually trigger a change notification (for testing external change scenarios)
    func simulateExternalChange(changedKeys: [String], reason: CloudStorageChangeReason = .serverChange) {
        let userInfo: [String: Any] = [
            CloudStorageNotificationKey.changedKeys: changedKeys,
            CloudStorageNotificationKey.reasonForChange: reason,
        ]

        NotificationCenter.default.post(
            name: .cloudStorageDidChangeExternally,
            object: self,
            userInfo: userInfo
        )
    }
}

// MARK: - Test Helper Extensions

extension MockCloudStorageService {
    /// Create a pre-configured mock for available cloud storage scenarios
    static func available() -> MockCloudStorageService {
        let mock = MockCloudStorageService()
        mock.configureAvailable()
        return mock
    }

    /// Create a pre-configured mock for unavailable cloud storage scenarios
    static func unavailable() -> MockCloudStorageService {
        let mock = MockCloudStorageService()
        mock.configureUnavailable()
        return mock
    }

    /// Create a pre-configured mock for sync failure scenarios
    static func syncFailure() -> MockCloudStorageService {
        let mock = MockCloudStorageService()
        mock.configureSyncFailure()
        return mock
    }

    /// Create a mock with pre-populated data for testing
    static func withData(_ data: [String: MockCloudStorageValue]) -> MockCloudStorageService {
        let mock = MockCloudStorageService()
        for (key, value) in data {
            switch value {
            case let .string(stringValue):
                mock.setString(stringValue, forKey: key)
            case let .int(intValue):
                mock.setInteger(intValue, forKey: key)
            case let .bool(boolValue):
                mock.setBoolean(boolValue, forKey: key)
            case let .double(doubleValue):
                mock.setDouble(doubleValue, forKey: key)
            }
        }
        return mock
    }
}
