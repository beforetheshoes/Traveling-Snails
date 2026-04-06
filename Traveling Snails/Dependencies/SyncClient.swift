import Dependencies
import Foundation
import SQLiteData

struct SyncStatusSnapshot: Sendable, Equatable {
    var isSyncing: Bool
    var lastSyncDate: Date?
    var pendingChangesCount: Int
    var networkStatus: NetworkStatus
    var syncProtectedTrips: Bool
    var hasSyncError: Bool
}

struct SyncClient {
    var status: @Sendable () async -> SyncStatusSnapshot
    var triggerSync: @Sendable () async -> Void
    var triggerSyncWithRetry: @Sendable () async -> Void
    var setSyncProtectedTrips: @Sendable (Bool) async -> Void
    var setNetworkStatus: @Sendable (NetworkStatus) async -> Void
    var simulateNetworkError: @Sendable () async -> Void
}

extension SyncClient: DependencyKey {
    static let liveValue: SyncClient = {
        // Use a simple actor to track sync status without creating a second SyncEngine.
        // The actual sync operations go through defaultSyncEngine (the single shared instance).
        let tracker = SyncStatusTracker()

        return SyncClient(
            status: {
                await tracker.snapshot()
            },
            triggerSync: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                await tracker.setIsSyncing(true)
                do {
                    try await syncEngine.sendChanges()
                    await tracker.recordSuccess()
                } catch {
                    await tracker.recordFailure()
                }
            },
            triggerSyncWithRetry: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                await tracker.setIsSyncing(true)
                var attempt = 0
                while attempt < 3 {
                    do {
                        try await syncEngine.sendChanges()
                        await tracker.recordSuccess()
                        return
                    } catch {
                        attempt += 1
                        if attempt >= 3 {
                            await tracker.recordFailure()
                            return
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                }
            },
            setSyncProtectedTrips: { enabled in
                await tracker.setSyncProtectedTrips(enabled)
            },
            setNetworkStatus: { status in
                await tracker.setNetworkStatus(status)
            },
            simulateNetworkError: {
                await tracker.recordFailure()
            }
        )
    }()

    static let testValue = SyncClient(
        status: {
            SyncStatusSnapshot(
                isSyncing: false,
                lastSyncDate: nil,
                pendingChangesCount: 0,
                networkStatus: .online,
                syncProtectedTrips: true,
                hasSyncError: false
            )
        },
        triggerSync: {},
        triggerSyncWithRetry: {},
        setSyncProtectedTrips: { _ in },
        setNetworkStatus: { _ in },
        simulateNetworkError: {}
    )
}

private actor SyncStatusTracker {
    var isSyncing = false
    var lastSyncDate: Date?
    var hasSyncError = false
    var networkStatus: NetworkStatus = .online
    var syncProtectedTrips = true

    func snapshot() -> SyncStatusSnapshot {
        SyncStatusSnapshot(
            isSyncing: isSyncing,
            lastSyncDate: lastSyncDate,
            pendingChangesCount: 0,
            networkStatus: networkStatus,
            syncProtectedTrips: syncProtectedTrips,
            hasSyncError: hasSyncError
        )
    }

    func setIsSyncing(_ value: Bool) { isSyncing = value }
    func setSyncProtectedTrips(_ value: Bool) { syncProtectedTrips = value }
    func setNetworkStatus(_ value: NetworkStatus) { networkStatus = value }

    func recordSuccess() {
        isSyncing = false
        lastSyncDate = Date()
        hasSyncError = false
    }

    func recordFailure() {
        isSyncing = false
        hasSyncError = true
    }
}

extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
