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
        let tracker = SyncStatusTracker()

        return SyncClient(
            status: {
                await tracker.snapshot()
            },
            triggerSync: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                @Dependency(\.defaultDatabase) var database
                await tracker.setIsSyncing(true)

                let snapshot: SyncRecoveryGuard.Snapshot?
                do {
                    snapshot = try await SyncRecoveryGuard.takeSnapshot(database: database)
                } catch {
                    snapshot = nil
                }

                let preCounts = snapshot?.countsByTable ?? [:]
                SyncEventLogger.log(
                    on: database,
                    type: "syncStarted",
                    details: "counts: \(preCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
                )

                do {
                    try await syncEngine.sendChanges()

                    let postCounts = (try? await SyncRecoveryGuard.currentCounts(database: database)) ?? [:]
                    let lostTables = preCounts.filter { key, pre in
                        (postCounts[key] ?? 0) < pre
                    }

                    if !lostTables.isEmpty {
                        let lostDetails = lostTables.map { key, pre in
                            "\(key): \(pre) -> \(postCounts[key] ?? 0)"
                        }.joined(separator: ", ")

                        SyncEventLogger.log(
                            on: database,
                            type: "ITEMS_LOST_DURING_SYNC",
                            details: lostDetails
                        )
                        Logger.shared.critical(
                            "Items lost during sync: \(lostDetails)",
                            category: .sync
                        )

                        if let snapshot {
                            let recovered = (try? await SyncRecoveryGuard.recoverIfNeeded(
                                database: database,
                                snapshot: snapshot
                            )) ?? 0
                            if recovered > 0 {
                                SyncEventLogger.log(
                                    on: database,
                                    type: "ITEMS_RECOVERED",
                                    details: "recovered \(recovered) items"
                                )
                            }
                        }
                    }

                    SyncEventLogger.log(
                        on: database,
                        type: "syncCompleted",
                        details: "counts: \(postCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
                    )
                    await tracker.recordSuccess()
                } catch {
                    SyncEventLogger.log(
                        on: database,
                        type: "syncFailed",
                        errorCode: String(describing: type(of: error)),
                        details: error.localizedDescription
                    )
                    await tracker.recordFailure()
                }
            },
            triggerSyncWithRetry: {
                @Dependency(\.defaultSyncEngine) var syncEngine
                @Dependency(\.defaultDatabase) var database
                await tracker.setIsSyncing(true)

                let snapshot: SyncRecoveryGuard.Snapshot?
                do {
                    snapshot = try await SyncRecoveryGuard.takeSnapshot(database: database)
                } catch {
                    snapshot = nil
                }

                let preCounts = snapshot?.countsByTable ?? [:]
                SyncEventLogger.log(
                    on: database,
                    type: "syncWithRetryStarted",
                    details: "counts: \(preCounts.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
                )

                var attempt = 0
                while attempt < 3 {
                    do {
                        try await syncEngine.sendChanges()

                        let postCounts = (try? await SyncRecoveryGuard.currentCounts(database: database)) ?? [:]
                        let lostTables = preCounts.filter { key, pre in
                            (postCounts[key] ?? 0) < pre
                        }

                        if !lostTables.isEmpty {
                            let lostDetails = lostTables.map { key, pre in
                                "\(key): \(pre) -> \(postCounts[key] ?? 0)"
                            }.joined(separator: ", ")

                            SyncEventLogger.log(
                                on: database,
                                type: "ITEMS_LOST_DURING_SYNC",
                                details: "attempt \(attempt + 1): \(lostDetails)"
                            )

                            if let snapshot {
                                let recovered = (try? await SyncRecoveryGuard.recoverIfNeeded(
                                    database: database,
                                    snapshot: snapshot
                                )) ?? 0
                                if recovered > 0 {
                                    SyncEventLogger.log(
                                        on: database,
                                        type: "ITEMS_RECOVERED",
                                        details: "recovered \(recovered) items on attempt \(attempt + 1)"
                                    )
                                }
                            }
                        }

                        SyncEventLogger.log(
                            on: database,
                            type: "syncWithRetryCompleted",
                            details: "attempt \(attempt + 1)"
                        )
                        await tracker.recordSuccess()
                        return
                    } catch {
                        attempt += 1
                        SyncEventLogger.log(
                            on: database,
                            type: "syncRetryAttempt",
                            errorCode: String(describing: type(of: error)),
                            details: "attempt \(attempt): \(error.localizedDescription)"
                        )
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
