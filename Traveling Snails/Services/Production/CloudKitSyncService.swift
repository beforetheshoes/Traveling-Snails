//
//  CloudKitSyncService.swift
//  Traveling Snails
//

import Foundation

/// Compatibility wrapper around SQLiteDataSyncService.
@MainActor
final class CloudKitSyncService: SyncService, AdvancedSyncService {
    private let underlying = SQLiteDataSyncService()

    @MainActor var isSyncing: Bool { underlying.isSyncing }
    @MainActor var lastSyncDate: Date? { underlying.lastSyncDate }
    @MainActor var syncError: Error? { underlying.syncError }
    @MainActor var pendingChangesCount: Int { underlying.pendingChangesCount }
    @MainActor var syncProtectedTrips: Bool {
        get { underlying.syncProtectedTrips }
        set { underlying.syncProtectedTrips = newValue }
    }
    @MainActor var networkStatus: NetworkStatus { underlying.networkStatus }

    @MainActor func triggerSync() {
        underlying.triggerSync()
    }

    func triggerSyncAndWait() async {
        await underlying.triggerSyncAndWait()
    }

    func processPendingChanges() async {
        await underlying.processPendingChanges()
    }

    func syncWithProgress() async -> SyncProgress {
        await underlying.syncWithProgress()
    }

    func syncAndResolveConflicts() async {
        await underlying.syncAndResolveConflicts()
    }

    func triggerSyncWithRetry() async {
        await underlying.triggerSyncWithRetry()
    }

    @MainActor func setNetworkStatus(_ status: NetworkStatus) {
        underlying.setNetworkStatus(status)
    }

    func simulateNetworkError() async {
        await underlying.simulateNetworkError()
    }

    @MainActor func simulateNetworkInterruptions(count: Int) {
        underlying.simulateNetworkInterruptions(count: count)
    }

    @MainActor func addObserver(_ observer: SyncServiceObserver) {
        underlying.addObserver(observer)
    }

    @MainActor func removeObserver(_ observer: SyncServiceObserver) {
        underlying.removeObserver(observer)
    }

    func forceFullSync() async {
        await underlying.forceFullSync()
    }

    func getSyncStatistics() async -> SyncStatistics {
        await underlying.getSyncStatistics()
    }

    func resetSyncState() async {
        await underlying.resetSyncState()
    }
}
