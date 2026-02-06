//
//  SQLiteDataSyncService.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@MainActor
final class SQLiteDataSyncService: SyncService, AdvancedSyncService {
    private let syncEngine: SyncEngine?

    init(database: DatabaseWriter? = DatabaseAccess.database) {
        guard let database else {
            Logger.shared.error("SQLiteDataSyncService initialized without a database", category: .database)
            self.syncEngine = nil
            return
        }

        do {
            self.syncEngine = try SyncEngine(
                for: database,
                tables: Address.self,
                Organization.self,
                Trip.self,
                Activity.self,
                Lodging.self,
                Transportation.self,
                EmbeddedFileAttachment.self
            )
        } catch {
            Logger.shared.error("Failed to initialize SyncEngine: \(error.localizedDescription)", category: .database)
            self.syncEngine = nil
        }
    }

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var syncError: Error?
    private(set) var pendingChangesCount: Int = 0
    var syncProtectedTrips: Bool = true
    private(set) var networkStatus: NetworkStatus = .online

    private var observers: [WeakSyncServiceObserver] = []
    private var statistics = SyncStatistics(
        totalSyncsPerformed: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        averageSyncDuration: 0,
        lastSyncDuration: 0,
        dataTransferred: 0,
        conflictsResolved: 0
    )

    func triggerSync() {
        Task { await triggerSyncAndWait() }
    }

    func triggerSyncAndWait() async {
        guard networkStatus == .online else {
            syncError = SyncError.networkUnavailable
            notify(.failed(.networkUnavailable))
            return
        }

        let start = Date()
        isSyncing = true
        notify(.started)
        defer {
            isSyncing = false
            statistics.totalSyncsPerformed += 1
            statistics.lastSyncDuration = Date().timeIntervalSince(start)
        }

        guard let syncEngine else {
            syncError = SyncError.networkUnavailable
            statistics.failedSyncs += 1
            notify(.failed(.networkUnavailable))
            return
        }

        do {
            try await syncEngine.sendChanges()
            lastSyncDate = Date()
            syncError = nil
            statistics.successfulSyncs += 1
            notify(.completed)
        } catch {
            syncError = error
            statistics.failedSyncs += 1
            notify(.failed(.unknown(error)))
        }
    }

    func processPendingChanges() async {
        await triggerSyncAndWait()
    }

    func syncWithProgress() async -> SyncProgress {
        await triggerSyncAndWait()
        return SyncProgress(totalBatches: 1, completedBatches: 1, isCompleted: true)
    }

    func syncAndResolveConflicts() async {
        await triggerSyncAndWait()
    }

    func triggerSyncWithRetry() async {
        let maxRetries = 3
        var attempt = 0
        while attempt < maxRetries {
            await triggerSyncAndWait()
            if syncError == nil { return }
            attempt += 1
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    func setNetworkStatus(_ status: NetworkStatus) {
        networkStatus = status
    }

    func simulateNetworkError() async {
        syncError = SyncError.networkUnavailable
        notify(.failed(.networkUnavailable))
    }

    func simulateNetworkInterruptions(count: Int) {
        networkStatus = count > 0 ? .offline : .online
    }

    func addObserver(_ observer: SyncServiceObserver) {
        observers.append(WeakSyncServiceObserver(observer))
    }

    func removeObserver(_ observer: SyncServiceObserver) {
        observers.removeAll { $0.observer === observer }
    }

    func forceFullSync() async {
        await triggerSyncAndWait()
    }

    func getSyncStatistics() async -> SyncStatistics {
        statistics
    }

    func resetSyncState() async {
        statistics = SyncStatistics(
            totalSyncsPerformed: 0,
            successfulSyncs: 0,
            failedSyncs: 0,
            averageSyncDuration: 0,
            lastSyncDuration: 0,
            dataTransferred: 0,
            conflictsResolved: 0
        )
        lastSyncDate = nil
        syncError = nil
    }

    private func notify(_ event: SyncEventType) {
        observers = observers.filter { $0.observer != nil }
        observers.forEach { $0.observer?.syncService(self, didReceiveEvent: event) }
    }
}

private struct WeakSyncServiceObserver {
    weak var observer: SyncServiceObserver?
    init(_ observer: SyncServiceObserver) { self.observer = observer }
}
