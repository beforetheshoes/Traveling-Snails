import Dependencies
import Foundation

struct SyncStatusSnapshot: Sendable, Equatable {
    var isSyncing: Bool
    var lastSyncDate: Date?
    var pendingChangesCount: Int
    var networkStatus: NetworkStatus
    var syncProtectedTrips: Bool
    var hasSyncError: Bool
}

struct SyncClient: Sendable {
    var status: @Sendable () async -> SyncStatusSnapshot
    var triggerSync: @Sendable () async -> Void
    var triggerSyncWithRetry: @Sendable () async -> Void
    var setSyncProtectedTrips: @Sendable (Bool) async -> Void
    var setNetworkStatus: @Sendable (NetworkStatus) async -> Void
    var simulateNetworkError: @Sendable () async -> Void
}

extension SyncClient: DependencyKey {
    static let liveValue = Self(
        status: {
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            return await MainActor.run {
                SyncStatusSnapshot(
                    isSyncing: manager.isSyncing,
                    lastSyncDate: manager.lastSyncDate,
                    pendingChangesCount: manager.pendingChangesCount,
                    networkStatus: manager.networkStatus,
                    syncProtectedTrips: manager.syncProtectedTrips,
                    hasSyncError: manager.syncError != nil
                )
            }
        },
        triggerSync: {
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            await MainActor.run {
                manager.triggerSync()
            }
        },
        triggerSyncWithRetry: {
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            await manager.triggerSyncWithRetry()
        },
        setSyncProtectedTrips: { enabled in
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            await MainActor.run {
                manager.syncProtectedTrips = enabled
            }
        },
        setNetworkStatus: { status in
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            await MainActor.run {
                manager.setNetworkStatus(status)
            }
        },
        simulateNetworkError: {
            let manager = await MainActor.run {
                ModernSyncManager.shared ?? ModernSyncManager.production()
            }
            await manager.simulateNetworkError()
        }
    )

    static let testValue = Self(
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

extension DependencyValues {
    var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
