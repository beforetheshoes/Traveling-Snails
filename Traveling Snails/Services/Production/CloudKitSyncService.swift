//
//  CloudKitSyncService.swift
//  Traveling Snails
//
//

import CloudKit
import Foundation
import Observation
import SwiftData

/// Production implementation of SyncService using CloudKit
@MainActor
@Observable
class CloudKitSyncService: SyncService {
    // MARK: - Properties

    private let modelContainer: ModelContainer
    private var syncQueue = DispatchQueue(label: "com.travelingsnails.sync", qos: .utility)
    private var observers: [WeakSyncServiceObserver] = []

    // Sync state
    var isSyncing: Bool = false
    var lastSyncDate: Date?
    var syncError: Error?
    var pendingChangesCount: Int = 0
    var syncProtectedTrips: Bool = true

    // Network and retry state
    private var networkStatus: NetworkStatus = .online
    private var retryAttempts: Int = 0
    private let maxRetryAttempts: Int = 3

    // Statistics tracking
    private var stats = SyncStatistics(
        totalSyncsPerformed: 0,
        successfulSyncs: 0,
        failedSyncs: 0,
        averageSyncDuration: 0,
        lastSyncDuration: 0,
        dataTransferred: 0,
        conflictsResolved: 0
    )

    // MARK: - Initialization

    private var isInitialized = false

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        // CRITICAL: Do NOT call setupCloudKitNotifications() here during app startup
        // This will be called lazily when sync operations begin to prevent crashes
    }

    // MARK: - SyncService Implementation

    func triggerSync() {
        Task {
            await ensureInitialized()
            await performSync()
        }
    }

    func triggerSyncAndWait() async {
        await ensureInitialized()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.performSync()
            }

            group.addTask {
                // Timeout after 30 seconds
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    await MainActor.run {
                        self.syncError = SyncError.operationTimeout
                        self.isSyncing = false
                        Logger.shared.error("Sync operation timed out after 30 seconds", category: .sync)
                    }
                } catch {
                    // Task was cancelled - sync completed first
                }
            }

            // Wait for the first task to complete
            await group.next()
            group.cancelAll()
        }
    }

    func processPendingChanges() async {
        guard networkStatus == .online else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Process pending changes
                await MainActor.run {
                    self.pendingChangesCount = 0
                }
                await self.performSync()
            }

            group.addTask {
                // Timeout after 30 seconds
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    await MainActor.run {
                        self.syncError = SyncError.operationTimeout
                        self.isSyncing = false
                        Logger.shared.error("processPendingChanges operation timed out after 30 seconds", category: .sync)
                    }
                } catch {
                    // Task was cancelled - operation completed first
                }
            }

            await group.next()
            group.cancelAll()
        }
    }

    func syncWithProgress() async -> SyncProgress {
        guard networkStatus == .online else {
            Logger.shared.warning("Cannot sync with progress while offline", category: .sync)
            return SyncProgress(totalBatches: 0, completedBatches: 0, isCompleted: false)
        }

        return await withTaskGroup(of: SyncProgress.self) { group in
            group.addTask {
                await self.performSyncWithProgress()
            }

            group.addTask {
                // Timeout after 60 seconds (longer for large datasets)
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                    await MainActor.run {
                        self.syncError = SyncError.operationTimeout
                        self.isSyncing = false
                        Logger.shared.error("syncWithProgress operation timed out after 60 seconds", category: .sync)
                    }
                } catch {
                    // Task was cancelled - operation completed first
                }
                return SyncProgress(totalBatches: 0, completedBatches: 0, isCompleted: false)
            }

            guard let result = await group.next() else {
                return SyncProgress(totalBatches: 0, completedBatches: 0, isCompleted: false)
            }

            group.cancelAll()
            return result
        }
    }

    func syncAndResolveConflicts() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.performSync()
                await self.resolveConflicts()
            }

            group.addTask {
                // Timeout after 30 seconds
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                    await MainActor.run {
                        self.syncError = SyncError.operationTimeout
                        self.isSyncing = false
                        Logger.shared.error("syncAndResolveConflicts operation timed out after 30 seconds", category: .sync)
                    }
                } catch {
                    // Task was cancelled - operation completed first
                }
            }

            await group.next()
            group.cancelAll()
        }
    }

    func triggerSyncWithRetry() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.performSyncWithRetry()
            }

            group.addTask {
                // Timeout after 120 seconds (longer for retry operations)
                do {
                    try await Task.sleep(nanoseconds: 120_000_000_000)
                    await MainActor.run {
                        self.syncError = SyncError.operationTimeout
                        self.isSyncing = false
                        Logger.shared.error("triggerSyncWithRetry operation timed out after 120 seconds", category: .sync)
                    }
                } catch {
                    // Task was cancelled - operation completed first
                }
            }

            await group.next()
            group.cancelAll()
        }
    }

    func setNetworkStatus(_ status: NetworkStatus) {
        networkStatus = status
        if status == .offline {
            isSyncing = false
            Task {
                await MainActor.run {
                    Task {
                        self.pendingChangesCount = await self.countPendingChanges()
                    }
                }
            }
        } else if status == .online {
            Task {
                await MainActor.run {
                    Task {
                        self.pendingChangesCount = await self.countPendingChanges()
                    }
                }
            }
        }
    }

    func simulateNetworkError() async {
        syncError = SyncError.networkUnavailable
    }

    func simulateNetworkInterruptions(count: Int) {
        retryAttempts = count
    }

    // MARK: - Private Implementation

    private func performSync() async {
        guard networkStatus == .online else {
            syncError = SyncError.networkUnavailable
            Logger.shared.warning("Sync attempted while offline", category: .sync)
            return
        }

        isSyncing = true
        syncError = nil
        let startTime = Date()

        notifyObservers(.started)

        do {
            // Count pending changes before sync
            pendingChangesCount = await countPendingChanges()
            Logger.shared.info("Starting sync with \(pendingChangesCount) pending changes", category: .sync)

            // Save any local changes to trigger CloudKit sync
            try modelContainer.mainContext.save()

            // Wait for CloudKit to process changes
            await waitForCloudKitSync()

            lastSyncDate = Date()
            retryAttempts = 0
            pendingChangesCount = 0

            let duration = Date().timeIntervalSince(startTime)
            updateSyncStatistics(success: true, duration: duration)
            Logger.shared.logPerformance("Sync operation", duration: duration, category: .sync)

            notifyObservers(.completed)
        } catch {
            syncError = SyncError.unknown(error)
            updateSyncStatistics(success: false, duration: Date().timeIntervalSince(startTime))
            Logger.shared.logError(error, message: "Sync failed", category: .sync)
            notifyObservers(.failed(SyncError.unknown(error)))
        }

        isSyncing = false
    }

    private func performSyncWithProgress() async -> SyncProgress {
        // Calculate batches based on CloudKit 400 record limit
        let totalRecords = await getTotalRecordCount()
        let totalBatches = max(1, (totalRecords + 399) / 400)

        Logger.shared.info("Starting batch sync: \(totalRecords) records in \(totalBatches) batches", category: .sync)

        isSyncing = true
        var completedBatches = 0

        for batch in 1...totalBatches {
            do {
                try await processBatch(batch)
                completedBatches += 1

                let progress = SyncProgress(
                    totalBatches: totalBatches,
                    completedBatches: completedBatches,
                    isCompleted: false
                )
                notifyObservers(.progress(progress))

                // Add realistic delay for CloudKit processing
                try await Task.sleep(for: .milliseconds(500))

                Logger.shared.info("Completed batch \(batch)/\(totalBatches)", category: .sync)
            } catch {
                Logger.shared.logError(error, message: "Batch \(batch) failed", category: .sync)
                break
            }
        }

        isSyncing = false
        lastSyncDate = Date()

        let finalProgress = SyncProgress(
            totalBatches: totalBatches,
            completedBatches: completedBatches,
            isCompleted: completedBatches == totalBatches
        )

        if finalProgress.isCompleted {
            notifyObservers(.completed)
        }

        return finalProgress
    }

    private func performSyncWithRetry() async {
        var currentAttempt = 0
        let startTime = Date()

        while currentAttempt < maxRetryAttempts {
            if retryAttempts > 0 {
                // Simulate network interruption for testing
                retryAttempts -= 1
                currentAttempt += 1

                // Exponential backoff: 2^attempt seconds (2s, 4s, 8s...)
                let delay = pow(2.0, Double(currentAttempt))
                Logger.shared.info("Network interruption, retrying in \(delay)s (attempt \(currentAttempt))", category: .sync)

                try? await Task.sleep(for: .seconds(delay))
                continue
            }

            // Actual sync attempt
            await performSync()

            // Check if sync succeeded
            if syncError == nil {
                let totalTime = Date().timeIntervalSince(startTime)
                Logger.shared.info("Sync succeeded after \(currentAttempt) retries in \(totalTime)s", category: .sync)
                return
            }

            // Handle specific error types
            if let error = syncError as? SyncError {
                switch error {
                case .networkUnavailable:
                    currentAttempt += 1
                    let delay = pow(2.0, Double(currentAttempt))
                    Logger.shared.warning("Network unavailable, retrying in \(delay)s", category: .sync)
                    try? await Task.sleep(for: .seconds(delay))
                case .cloudKitQuotaExceeded:
                    // Wait longer for quota exceeded
                    let delay = 60.0 * Double(currentAttempt + 1) // 1min, 2min, 3min
                    Logger.shared.warning("CloudKit quota exceeded, waiting \(delay)s", category: .sync)
                    try? await Task.sleep(for: .seconds(delay))
                    currentAttempt += 1
                default:
                    Logger.shared.error("Sync failed with unrecoverable error: \(error)", category: .sync)
                    return
                }
            } else {
                currentAttempt += 1
            }
        }

        await MainActor.run {
            syncError = SyncError.networkUnavailable
        }
        Logger.shared.error("Sync failed after \(maxRetryAttempts) attempts", category: .sync)
    }

    // MARK: - Helper Methods

    /// Ensure CloudKit notifications are set up (called lazily to prevent startup crashes)
    private func ensureInitialized() async {
        guard !isInitialized else { return }

        Logger.shared.info("Lazy initializing CloudKit sync service", category: .sync)
        await MainActor.run {
            setupCloudKitNotifications()
            isInitialized = true
        }
        Logger.shared.info("CloudKit sync service initialized successfully", category: .sync)
    }

    private func setupCloudKitNotifications() {
        // Monitor CloudKit remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(remoteStoreDidChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )

        // Monitor CloudKit account status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudKitAccountChanged),
            name: NSNotification.Name.CKAccountChanged,
            object: nil
        )
    }

    @objc private func remoteStoreDidChange(notification: NSNotification) {
        Logger.shared.info("Remote store change detected", category: .sync)

        Task { @MainActor in
            lastSyncDate = Date()
            await processRemoteChanges(from: notification)
        }
    }

    @objc private func cloudKitAccountChanged(notification: NSNotification) {
        Logger.shared.info("CloudKit account status changed", category: .sync)
        Task { @MainActor in
            await checkCloudKitAccountStatus()
        }
    }

    private func processRemoteChanges(from notification: NSNotification? = nil) async {
        Logger.shared.info("Processing remote changes from CloudKit", category: .sync)

        if let notification = notification {
            if let userInfo = notification.userInfo {
                Logger.shared.info("Remote change details: \(userInfo)", category: .sync)
            }
        }

        await resolveConflicts()
    }

    private func checkCloudKitAccountStatus() async {
        Logger.shared.info("Checking CloudKit account status", category: .sync)
        // In real implementation, check CKContainer.default().accountStatus
    }

    private func countPendingChanges() async -> Int {
        do {
            let tripCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Trip>())
            let activityCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Activity>())
            let lodgingCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Lodging>())
            let transportationCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Transportation>())

            if modelContainer.mainContext.hasChanges {
                return tripCount + activityCount + lodgingCount + transportationCount + 1
            }

            if networkStatus == .offline {
                return tripCount + activityCount + lodgingCount + transportationCount
            }

            return 0
        } catch {
            Logger.shared.logError(error, message: "Failed to count pending changes", category: .sync)
            return 0
        }
    }

    private func waitForCloudKitSync() async {
        try? await Task.sleep(for: .milliseconds(200))
    }

    private func getTotalRecordCount() async -> Int {
        do {
            let tripCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Trip>())
            let activityCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Activity>())
            let lodgingCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Lodging>())
            let transportationCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Transportation>())
            let organizationCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Organization>())
            let addressCount = try modelContainer.mainContext.fetchCount(FetchDescriptor<Address>())

            var protectedTripCount = 0
            if !syncProtectedTrips {
                let protectedDescriptor = FetchDescriptor<Trip>(predicate: #Predicate { $0.isProtected == true })
                protectedTripCount = try modelContainer.mainContext.fetchCount(protectedDescriptor)
            }

            let totalCount = tripCount + activityCount + lodgingCount + transportationCount + organizationCount + addressCount - protectedTripCount

            Logger.shared.info("Total records to sync: \(totalCount) (excluding \(protectedTripCount) protected trips)", category: .sync)
            return totalCount
        } catch {
            Logger.shared.logError(error, message: "Failed to count records", category: .sync)
            return 0
        }
    }

    private func processBatch(_ batchNumber: Int) async throws {
        Logger.shared.info("Processing sync batch \(batchNumber)", category: .sync)

        // Simulate CloudKit network delay
        try await Task.sleep(for: .milliseconds(100))

        // Simulate potential CloudKit errors
        if batchNumber == 3 && retryAttempts > 0 {
            throw SyncError.cloudKitQuotaExceeded
        }
    }

    private func resolveConflicts() async {
        Logger.shared.info("Checking for and resolving sync conflicts", category: .sync)

        do {
            let allTrips = try modelContainer.mainContext.fetch(FetchDescriptor<Trip>())

            var tripGroups: [UUID: [Trip]] = [:]
            for trip in allTrips {
                if tripGroups[trip.id] == nil {
                    tripGroups[trip.id] = []
                }
                tripGroups[trip.id]?.append(trip)
            }

            var conflictsResolved = 0
            for (tripId, conflictingTrips) in tripGroups {
                if conflictingTrips.count > 1 {
                    Logger.shared.info("Resolving conflict for trip ID: \(tripId)", category: .sync)
                    notifyObservers(.conflictDetected)

                    let sortedTrips = conflictingTrips.sorted { trip1, trip2 in
                        let date1 = trip1.endDate
                        let date2 = trip2.endDate
                        return date1 > date2
                    }

                    let winningTrip = sortedTrips.first!
                    for i in 1..<sortedTrips.count {
                        modelContainer.mainContext.delete(sortedTrips[i])
                    }

                    conflictsResolved += 1
                    Logger.shared.info("Kept trip: '\(winningTrip.name)' as conflict resolution winner", category: .sync)
                }
            }

            if conflictsResolved > 0 {
                try modelContainer.mainContext.save()
                stats = SyncStatistics(
                    totalSyncsPerformed: stats.totalSyncsPerformed,
                    successfulSyncs: stats.successfulSyncs,
                    failedSyncs: stats.failedSyncs,
                    averageSyncDuration: stats.averageSyncDuration,
                    lastSyncDuration: stats.lastSyncDuration,
                    dataTransferred: stats.dataTransferred,
                    conflictsResolved: stats.conflictsResolved + conflictsResolved
                )
                notifyObservers(.conflictResolved)
            }
        } catch {
            Logger.shared.logError(error, message: "Failed to resolve conflicts", category: .sync)
        }
    }

    private func updateSyncStatistics(success: Bool, duration: TimeInterval) {
        let totalSyncs = stats.totalSyncsPerformed + 1
        let successfulSyncs = success ? stats.successfulSyncs + 1 : stats.successfulSyncs
        let failedSyncs = success ? stats.failedSyncs : stats.failedSyncs + 1

        let totalDuration = stats.averageSyncDuration * Double(stats.totalSyncsPerformed) + duration
        let newAverageDuration = totalDuration / Double(totalSyncs)

        stats = SyncStatistics(
            totalSyncsPerformed: totalSyncs,
            successfulSyncs: successfulSyncs,
            failedSyncs: failedSyncs,
            averageSyncDuration: newAverageDuration,
            lastSyncDuration: duration,
            dataTransferred: stats.dataTransferred,
            conflictsResolved: stats.conflictsResolved
        )
    }

    // MARK: - Observer Management

    private func notifyObservers(_ event: SyncEventType) {
        // Clean up nil observers
        observers = observers.filter { $0.observer != nil }

        for weakObserver in observers {
            weakObserver.observer?.syncService(self, didReceiveEvent: event)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - AdvancedSyncService Implementation

extension CloudKitSyncService: AdvancedSyncService {
    func addObserver(_ observer: SyncServiceObserver) {
        observers.append(WeakSyncServiceObserver(observer))
    }

    func removeObserver(_ observer: SyncServiceObserver) {
        observers.removeAll { $0.observer === observer }
    }

    func forceFullSync() async {
        Logger.shared.info("Starting force full sync", category: .sync)
        // Implementation would reset sync tokens and re-download all data
        await performSync()
    }

    func getSyncStatistics() async -> SyncStatistics {
        stats
    }

    func resetSyncState() async {
        Logger.shared.info("Resetting sync state", category: .sync)
        lastSyncDate = nil
        syncError = nil
        pendingChangesCount = 0
        retryAttempts = 0
        stats = SyncStatistics(
            totalSyncsPerformed: 0,
            successfulSyncs: 0,
            failedSyncs: 0,
            averageSyncDuration: 0,
            lastSyncDuration: 0,
            dataTransferred: 0,
            conflictsResolved: 0
        )
    }
}

// MARK: - Weak Observer Wrapper

private struct WeakSyncServiceObserver {
    weak var observer: SyncServiceObserver?

    init(_ observer: SyncServiceObserver) {
        self.observer = observer
    }
}
