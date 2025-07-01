//
//  SyncService.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData

/// Service protocol for data synchronization
/// Abstracts CloudKit sync operations for testability
/// Sendable for safe concurrent access
protocol SyncService: Sendable {
    /// Current sync status
    @MainActor var isSyncing: Bool { get }

    /// Date of last successful sync
    @MainActor var lastSyncDate: Date? { get }

    /// Current sync error, if any
    @MainActor var syncError: Error? { get }

    /// Number of pending changes waiting to sync
    @MainActor var pendingChangesCount: Int { get }

    /// Whether protected trips should be synced
    @MainActor var syncProtectedTrips: Bool { get set }

    /// Current network status
    @MainActor var networkStatus: NetworkStatus { get }

    /// Trigger a sync operation
    @MainActor func triggerSync()

    /// Trigger a sync operation and wait for completion
    func triggerSyncAndWait() async

    /// Process pending changes when coming back online
    func processPendingChanges() async

    /// Sync with progress tracking for large datasets
    /// - Returns: Progress information about the sync operation
    func syncWithProgress() async -> SyncProgress

    /// Sync and resolve any conflicts that arise
    func syncAndResolveConflicts() async

    /// Trigger sync with retry logic for network interruptions
    func triggerSyncWithRetry() async

    /// Set the network status for testing offline scenarios
    /// - Parameter status: The network status to simulate
    @MainActor func setNetworkStatus(_ status: NetworkStatus)

    /// Simulate network error for testing
    func simulateNetworkError() async

    /// Simulate network interruptions for testing
    /// - Parameter count: Number of interruptions to simulate
    @MainActor func simulateNetworkInterruptions(count: Int)
}

/// Network status for sync operations
enum NetworkStatus: Sendable {
    case online
    case offline
}

/// Sync progress tracking for large datasets
struct SyncProgress: Sendable {
    let totalBatches: Int
    let completedBatches: Int
    let isCompleted: Bool

    var progressPercentage: Double {
        guard totalBatches > 0 else { return 1.0 }
        return Double(completedBatches) / Double(totalBatches)
    }
}

/// Errors that can occur during sync operations
enum SyncError: Error, LocalizedError, Sendable {
    case networkUnavailable
    case cloudKitQuotaExceeded
    case conflictResolutionFailed
    case operationTimeout
    case accountNotAvailable
    case permissionDenied
    case dataCorruption
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network is unavailable"
        case .cloudKitQuotaExceeded:
            return "CloudKit quota exceeded"
        case .conflictResolutionFailed:
            return "Failed to resolve data conflicts"
        case .operationTimeout:
            return "Sync operation timed out"
        case .accountNotAvailable:
            return "iCloud account is not available"
        case .permissionDenied:
            return "Permission denied for sync operation"
        case .dataCorruption:
            return "Data corruption detected during sync"
        case .unknown(let error):
            return "Unknown sync error: \(error.localizedDescription)"
        }
    }
}

/// Sync event types for monitoring
enum SyncEventType: Sendable {
    case started
    case progress(SyncProgress)
    case completed
    case failed(SyncError)
    case conflictDetected
    case conflictResolved
}

/// Protocol for observing sync events
protocol SyncServiceObserver: AnyObject {
    func syncService(_ service: SyncService, didReceiveEvent event: SyncEventType)
}

/// Extended sync service protocol for advanced features
protocol AdvancedSyncService: SyncService {
    /// Add an observer for sync events
    /// - Parameter observer: The observer to add
    @MainActor func addObserver(_ observer: SyncServiceObserver)

    /// Remove an observer for sync events
    /// - Parameter observer: The observer to remove
    @MainActor func removeObserver(_ observer: SyncServiceObserver)

    /// Force a full sync (re-download all data)
    func forceFullSync() async

    /// Get detailed sync statistics
    /// - Returns: Statistics about sync operations
    func getSyncStatistics() async -> SyncStatistics

    /// Reset sync state (for testing or troubleshooting)
    func resetSyncState() async
}

/// Statistics about sync operations
struct SyncStatistics: Sendable {
    let totalSyncsPerformed: Int
    let successfulSyncs: Int
    let failedSyncs: Int
    let averageSyncDuration: TimeInterval
    let lastSyncDuration: TimeInterval
    let dataTransferred: Int // bytes
    let conflictsResolved: Int

    var successRate: Double {
        guard totalSyncsPerformed > 0 else { return 0.0 }
        return Double(successfulSyncs) / Double(totalSyncsPerformed)
    }
}
