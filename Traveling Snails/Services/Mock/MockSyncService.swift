//
//  MockSyncService.swift
//  Traveling Snails
//
//

import Foundation
import os.lock
import SwiftData

/// Mock implementation of SyncService for testing
/// Provides controllable sync behavior without CloudKit dependency
final class MockSyncService: SyncService, Sendable {
    // MARK: - Thread-Safe Storage
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Mock Configuration (Thread-Safe)
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var _mockSyncResult: Bool = true
    nonisolated(unsafe) private var _mockSyncProgress: Double = 1.0
    nonisolated(unsafe) private var _mockSyncDelay: TimeInterval = 0.0
    nonisolated(unsafe) private var _mockSyncError: Error?
    nonisolated(unsafe) private var _mockLastSyncDate: Date?
    nonisolated(unsafe) private var _mockPendingChangesCount: Int = 0
    nonisolated(unsafe) private var _mockNetworkStatus: NetworkStatus = .online
    nonisolated(unsafe) private var _syncCallCount: Int = 0
    nonisolated(unsafe) private var _triggerSyncCallCount: Int = 0
    nonisolated(unsafe) private var _triggerSyncAndWaitCallCount: Int = 0
    nonisolated(unsafe) private var _processPendingChangesCallCount: Int = 0
    nonisolated(unsafe) private var _networkInterruptionSimulationCount: Int = 0
    nonisolated(unsafe) private var _progressUpdates: [SyncProgress] = []
    nonisolated(unsafe) private var _isSyncing: Bool = false
    nonisolated(unsafe) private var _syncProtectedTrips: Bool = false

    // MARK: - Initialization

    init() {
        // Mock service starts in ready state
    }

    // MARK: - Thread-Safe Configuration Accessors

    var mockSyncResult: Bool {
        get { lock.withLock { _mockSyncResult } }
        set { lock.withLock { _mockSyncResult = newValue } }
    }

    var mockSyncProgress: Double {
        get { lock.withLock { _mockSyncProgress } }
        set { lock.withLock { _mockSyncProgress = newValue } }
    }

    var mockSyncDelay: TimeInterval {
        get { lock.withLock { _mockSyncDelay } }
        set { lock.withLock { _mockSyncDelay = newValue } }
    }

    var mockSyncError: Error? {
        get { lock.withLock { _mockSyncError } }
        set { lock.withLock { _mockSyncError = newValue } }
    }

    var mockLastSyncDate: Date? {
        get { lock.withLock { _mockLastSyncDate } }
        set { lock.withLock { _mockLastSyncDate = newValue } }
    }

    var mockPendingChangesCount: Int {
        get { lock.withLock { _mockPendingChangesCount } }
        set { lock.withLock { _mockPendingChangesCount = newValue } }
    }

    var mockNetworkStatus: NetworkStatus {
        get { lock.withLock { _mockNetworkStatus } }
        set { lock.withLock { _mockNetworkStatus = newValue } }
    }

    var syncCallCount: Int {
        lock.withLock { _syncCallCount }
    }

    var triggerSyncCallCount: Int {
        lock.withLock { _triggerSyncCallCount }
    }

    var triggerSyncAndWaitCallCount: Int {
        lock.withLock { _triggerSyncAndWaitCallCount }
    }

    var processPendingChangesCallCount: Int {
        lock.withLock { _processPendingChangesCallCount }
    }

    var networkInterruptionSimulationCount: Int {
        lock.withLock { _networkInterruptionSimulationCount }
    }

    var progressUpdates: [SyncProgress] {
        lock.withLock { _progressUpdates }
    }

    // MARK: - SyncService Implementation

    var isSyncing: Bool {
        lock.withLock { _isSyncing }
    }

    var lastSyncDate: Date? {
        lock.withLock { _mockLastSyncDate }
    }

    var syncError: Error? {
        lock.withLock { _mockSyncError }
    }

    var pendingChangesCount: Int {
        lock.withLock { _mockPendingChangesCount }
    }

    var syncProtectedTrips: Bool {
        get {
            lock.withLock { _syncProtectedTrips }
        }
        set {
            lock.withLock { _syncProtectedTrips = newValue }
        }
    }

    func triggerSync() {
        lock.withLock { _triggerSyncCallCount += 1 }
        lock.withLock { _isSyncing = true }

        // Simulate async sync operation
        Task {
            defer {
                lock.withLock { _isSyncing = false }
            }

            await simulateSyncProgress()

            let result = lock.withLock { _mockSyncResult }
            if result {
                lock.withLock {
                    _mockLastSyncDate = Date()
                    _mockSyncError = nil
                }
            } else {
                lock.withLock { _mockSyncError = SyncError.networkUnavailable }
            }
        }
    }

    func triggerSyncAndWait() async {
        // Track call count
        lock.withLock { _triggerSyncAndWaitCallCount += 1 }
        lock.withLock { _isSyncing = true }

        defer {
            lock.withLock { _isSyncing = false }
        }

        // Simulate sync process with progress updates
        await simulateSyncProgress()

        // Update mock state based on result
        let result = lock.withLock { _mockSyncResult }
        if result {
            lock.withLock {
                _mockLastSyncDate = Date()
                _mockSyncError = nil
            }
        } else {
            // Use the configured error if one was set, otherwise default to networkUnavailable
            lock.withLock {
                if _mockSyncError == nil {
                    _mockSyncError = SyncError.networkUnavailable
                }
                // Otherwise keep the configured error
            }
        }
    }

    func processPendingChanges() async {
        lock.withLock { _processPendingChangesCallCount += 1 }

        // Simulate processing pending changes
        let delay = lock.withLock { _mockSyncDelay }
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 0.5 * 1_000_000_000))
        }

        // Reset pending changes count if successful
        let result = lock.withLock { _mockSyncResult }
        if result {
            lock.withLock { _mockPendingChangesCount = 0 }
        }
    }

    func syncWithProgress() async -> SyncProgress {
        // Track call count
        lock.withLock { _syncCallCount += 1 }
        lock.withLock { _isSyncing = true }

        defer {
            lock.withLock { _isSyncing = false }
        }

        // Simulate sync with progress tracking
        let totalBatches = 5
        var completedBatches = 0
        let delay = lock.withLock { _mockSyncDelay }

        for batch in 0...totalBatches {
            completedBatches = batch
            let progress = SyncProgress(
                totalBatches: totalBatches,
                completedBatches: completedBatches,
                isCompleted: batch == totalBatches
            )

            lock.withLock { _progressUpdates.append(progress) }

            if batch < totalBatches && delay > 0 {
                let stepDelay = delay / Double(totalBatches)
                try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
            }
        }

        let finalProgress = SyncProgress(
            totalBatches: totalBatches,
            completedBatches: completedBatches,
            isCompleted: true
        )

        // Update mock state
        let result = lock.withLock { _mockSyncResult }
        if result {
            lock.withLock {
                _mockLastSyncDate = Date()
                _mockSyncError = nil
            }
        } else {
            // Use the configured error if one was set, otherwise default to networkUnavailable
            lock.withLock {
                if _mockSyncError == nil {
                    _mockSyncError = SyncError.networkUnavailable
                }
                // Otherwise keep the configured error
            }
        }

        return finalProgress
    }

    func syncAndResolveConflicts() async {
        await triggerSyncAndWait()
        // In a real implementation, this would handle conflict resolution
    }

    func triggerSyncWithRetry() async {
        await triggerSyncAndWait()
        // In a real implementation, this would implement retry logic
    }

    func setNetworkStatus(_ status: NetworkStatus) {
        lock.withLock { _mockNetworkStatus = status }

        // Update sync behavior based on network status
        if status == .offline {
            lock.withLock {
                _mockSyncResult = false
                _mockSyncError = SyncError.networkUnavailable
            }
        } else {
            lock.withLock {
                _mockSyncResult = true
                _mockSyncError = nil
            }
        }
    }

    func simulateNetworkError() async {
        lock.withLock {
            _mockSyncError = SyncError.networkUnavailable
            _mockSyncResult = false
        }
    }

    func simulateNetworkInterruptions(count: Int) {
        lock.withLock { _networkInterruptionSimulationCount = count }
    }

    // MARK: - Private Helper Methods

    private func simulateSyncProgress() async {
        let totalBatches = 3
        let delay = lock.withLock { _mockSyncDelay }
        let stepDelay = delay / Double(totalBatches)

        for batch in 0...totalBatches {
            let progress = SyncProgress(
                totalBatches: totalBatches,
                completedBatches: batch,
                isCompleted: batch == totalBatches
            )

            lock.withLock { _progressUpdates.append(progress) }

            if batch < totalBatches && stepDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(stepDelay * 1_000_000_000))
            }
        }
    }

    // MARK: - Mock Control Methods

    /// Configure mock to simulate successful sync operations
    func configureSuccessfulSync() {
        lock.withLock {
            _mockSyncResult = true
            _mockSyncError = nil
            _mockLastSyncDate = nil // Don't set date until sync actually happens
            _mockPendingChangesCount = 0
            _mockNetworkStatus = .online
        }
    }

    /// Configure mock to simulate sync failures
    func configureSyncFailure(_ error: Error = SyncError.networkUnavailable) {
        lock.withLock {
            _mockSyncResult = false
            _mockSyncError = error
            _mockNetworkStatus = .offline
        }
    }

    /// Configure mock to simulate network offline scenario
    func configureOfflineSync() {
        lock.withLock {
            _mockNetworkStatus = .offline
            _mockSyncResult = false
            _mockSyncError = SyncError.networkUnavailable
        }
    }

    /// Configure mock to simulate slow sync operations
    func configureSlowSync(delay: TimeInterval = 1.0) {
        lock.withLock {
            _mockSyncDelay = delay
            _mockSyncResult = true
            _mockSyncError = nil
        }
    }

    /// Configure mock to simulate pending changes
    func configurePendingChanges(count: Int = 5) {
        lock.withLock {
            _mockPendingChangesCount = count
            _mockSyncResult = true
        }
    }

    /// Reset mock to clean state for next test
    func resetForTesting() {
        lock.withLock {
            _syncCallCount = 0
            _triggerSyncCallCount = 0
            _triggerSyncAndWaitCallCount = 0
            _processPendingChangesCallCount = 0
            _networkInterruptionSimulationCount = 0
            _progressUpdates.removeAll()
            _isSyncing = false
            _syncProtectedTrips = false

            _mockSyncResult = true
            _mockSyncError = nil
            _mockLastSyncDate = nil // Reset to nil for clean state
            _mockPendingChangesCount = 0
            _mockNetworkStatus = .online
            _mockSyncDelay = 0.2
        }
    }

    /// Get all recorded progress updates (for test verification)
    func getProgressUpdates() -> [SyncProgress] {
        lock.withLock { _progressUpdates }
    }

    /// Get the last recorded progress (for test verification)
    func getLastProgress() -> SyncProgress? {
        lock.withLock { _progressUpdates.last }
    }

    /// Check if sync reached completion (for test verification)
    func didReachCompletion() -> Bool {
        lock.withLock { _progressUpdates.contains { $0.isCompleted } }
    }

    /// Get the final progress percentage (for test verification)
    func getFinalProgressPercentage() -> Double {
        lock.withLock { _progressUpdates.last?.progressPercentage ?? 0.0 }
    }

    /// Manually set sync status (for testing sync state scenarios)
    func setSyncingStatus(_ isSyncing: Bool) {
        lock.withLock { _isSyncing = isSyncing }
    }

    /// Simulate a sync operation starting without completing (for testing interruption scenarios)
    func simulateSyncStart() {
        lock.withLock {
            _isSyncing = true
            _syncCallCount += 1
        }
    }

    /// Get various call counts for test verification
    func getTriggerSyncCallCount() -> Int {
        lock.withLock { _triggerSyncCallCount }
    }

    func getTriggerSyncAndWaitCallCount() -> Int {
        lock.withLock { _triggerSyncAndWaitCallCount }
    }

    func getProcessPendingChangesCallCount() -> Int {
        lock.withLock { _processPendingChangesCallCount }
    }

    func getNetworkInterruptionSimulationCount() -> Int {
        lock.withLock { _networkInterruptionSimulationCount }
    }
}

// MARK: - Mock Sync Error Helper

extension MockSyncService {
    /// Common sync errors for testing
    static let commonSyncErrors: [SyncError] = [
        .networkUnavailable,
        .cloudKitQuotaExceeded,
        .conflictResolutionFailed,
        .operationTimeout,
        .accountNotAvailable,
        .permissionDenied,
        .dataCorruption,
    ]
}

// MARK: - Test Helper Extensions

extension MockSyncService {
    /// Create a pre-configured mock for successful sync scenarios
    static func successful() -> MockSyncService {
        let mock = MockSyncService()
        mock.configureSuccessfulSync()
        return mock
    }

    /// Create a pre-configured mock for sync failure scenarios
    static func failed(_ error: Error = SyncError.networkUnavailable) -> MockSyncService {
        let mock = MockSyncService()
        mock.configureSyncFailure(error)
        return mock
    }

    /// Create a pre-configured mock for offline sync scenarios
    static func offline() -> MockSyncService {
        let mock = MockSyncService()
        mock.configureOfflineSync()
        return mock
    }

    /// Create a pre-configured mock for slow sync scenarios
    static func slow(delay: TimeInterval = 1.0) -> MockSyncService {
        let mock = MockSyncService()
        mock.configureSlowSync(delay: delay)
        return mock
    }

    /// Create a pre-configured mock with pending changes
    static func withPendingChanges(count: Int = 5) -> MockSyncService {
        let mock = MockSyncService()
        mock.configurePendingChanges(count: count)
        return mock
    }

    /// Create a pre-configured mock for quota exceeded scenarios
    static func quotaExceeded() -> MockSyncService {
        let mock = MockSyncService()
        mock.configureSyncFailure(SyncError.cloudKitQuotaExceeded)
        return mock
    }

    /// Create a pre-configured mock for account unavailable scenarios
    static func accountUnavailable() -> MockSyncService {
        let mock = MockSyncService()
        mock.configureSyncFailure(SyncError.accountNotAvailable)
        return mock
    }
}
