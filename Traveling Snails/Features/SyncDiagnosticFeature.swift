import CloudKit
import ComposableArchitecture
import Foundation
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import SQLiteData

@Reducer
struct SyncDiagnosticFeature {
    @ObservableState
    struct State: Equatable {
        var showingAdvancedMetrics = false
        var isRefreshing = false
        var status = SyncStatusSnapshot(
            isSyncing: false,
            lastSyncDate: nil,
            pendingChangesCount: 0,
            networkStatus: .online,
            syncProtectedTrips: true,
            hasSyncError: false
        )
        var recordCounts: [String: Int] = [:]
        var isLoadingRecordCounts = false

        var showingDeletionLog = false
        var deletionLogEntries: [DeletionLogEntry] = []
        var isLoadingDeletionLog = false

        var showingSyncEventLog = false
        var syncEventLogEntries: [SyncEventEntry] = []
        var isLoadingSyncEventLog = false

        var showingRecordTypeProbe = false
        var recordTypeProbeResults: [String: RecordTypeProbeResult] = [:]
        var isRunningProbe = false

        var isForceResyncing = false
        var forceResyncResult: String?
    }

    enum RecordTypeProbeResult: Equatable {
        case success
        case failed(String)
        case pending
    }

    enum Action: Equatable {
        case onAppear
        case statusLoaded(SyncStatusSnapshot)

        case triggerSyncTapped
        case triggerSyncWithRetryTapped
        case refreshTapped
        case syncProtectedTripsChanged(Bool)
        case testOfflineTapped
        case testOnlineTapped
        case simulateNetworkErrorTapped

        case advancedMetricsToggled
        case loadRecordCounts
        case recordCountsLoaded([String: Int])

        case deletionLogToggled
        case loadDeletionLog
        case deletionLogLoaded([DeletionLogEntry])

        case syncEventLogToggled
        case loadSyncEventLog
        case syncEventLogLoaded([SyncEventEntry])

        case clearLogsTapped
        case logsCleared
        case copyLogsTapped

        case recordTypeProbeToggled
        case runRecordTypeProbe
        case recordTypeProbeCompleted([String: RecordTypeProbeResult])

        case forceResyncTapped
        case forceResyncCompleted(String)
    }

    @Dependency(\.syncClient) private var syncClient
    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshTapped)

            case .statusLoaded(let snapshot):
                state.status = snapshot
                state.isRefreshing = false
                return .none

            case .triggerSyncTapped:
                state.isRefreshing = true
                return .run { send in
                    await syncClient.triggerSync()
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .triggerSyncWithRetryTapped:
                state.isRefreshing = true
                return .run { send in
                    await syncClient.triggerSyncWithRetry()
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .refreshTapped:
                state.isRefreshing = true
                return .run { send in
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .syncProtectedTripsChanged(let enabled):
                state.status.syncProtectedTrips = enabled
                state.isRefreshing = true
                return .run { send in
                    await syncClient.setSyncProtectedTrips(enabled)
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .testOfflineTapped:
                state.isRefreshing = true
                return .run { send in
                    await syncClient.setNetworkStatus(.offline)
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .testOnlineTapped:
                state.isRefreshing = true
                return .run { send in
                    await syncClient.setNetworkStatus(.online)
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .simulateNetworkErrorTapped:
                state.isRefreshing = true
                return .run { send in
                    await syncClient.simulateNetworkError()
                    let snapshot = await syncClient.status()
                    await send(.statusLoaded(snapshot))
                }

            case .advancedMetricsToggled:
                state.showingAdvancedMetrics.toggle()
                if state.showingAdvancedMetrics, state.recordCounts.isEmpty {
                    return .send(.loadRecordCounts)
                }
                return .none

            case .loadRecordCounts:
                state.isLoadingRecordCounts = true
                return .run { send in
                    do {
                        let counts = try await database.read { db in
                            [
                                "Trips": try Trip.fetchCount(db),
                                "Activities": try Activity.fetchCount(db),
                                "Transportation": try Transportation.fetchCount(db),
                                "Lodging": try Lodging.fetchCount(db),
                                "Organizations": try Organization.fetchCount(db),
                                "Addresses": try Address.fetchCount(db),
                                "Collections": try Collection.fetchCount(db),
                                "Book Items": try BookItem.fetchCount(db),
                                "Movie Items": try MovieItem.fetchCount(db),
                                "TV Show Items": try TVShowItem.fetchCount(db),
                                "Restaurant Items": try RestaurantItem.fetchCount(db),
                            ]
                        }
                        await send(.recordCountsLoaded(counts))
                    } catch {
                        await send(.recordCountsLoaded([:]))
                    }
                }

            case .recordCountsLoaded(let counts):
                state.recordCounts = counts
                state.isLoadingRecordCounts = false
                return .none

            // MARK: - Deletion Log

            case .deletionLogToggled:
                state.showingDeletionLog.toggle()
                return .none

            case .loadDeletionLog:
                state.isLoadingDeletionLog = true
                return .run { send in
                    let entries = (try? CollectionItemDeletionLogger.recentDeletions(from: database)) ?? []
                    await send(.deletionLogLoaded(entries))
                }

            case .deletionLogLoaded(let entries):
                state.deletionLogEntries = entries
                state.isLoadingDeletionLog = false
                return .none

            // MARK: - Sync Event Log

            case .syncEventLogToggled:
                state.showingSyncEventLog.toggle()
                return .none

            case .loadSyncEventLog:
                state.isLoadingSyncEventLog = true
                return .run { send in
                    let entries = (try? SyncEventLogger.recentEvents(from: database)) ?? []
                    await send(.syncEventLogLoaded(entries))
                }

            case .syncEventLogLoaded(let entries):
                state.syncEventLogEntries = entries
                state.isLoadingSyncEventLog = false
                return .none

            // MARK: - Log Management

            case .clearLogsTapped:
                return .run { send in
                    try? CollectionItemDeletionLogger.clear(on: database)
                    try? SyncEventLogger.clear(on: database)
                    await send(.logsCleared)
                }

            case .logsCleared:
                state.deletionLogEntries = []
                state.syncEventLogEntries = []
                return .none

            case .copyLogsTapped:
                return .run { _ in
                    var output = "=== Deletion Log ===\n"
                    if let deletions = try? CollectionItemDeletionLogger.recentDeletions(from: database, limit: 100) {
                        for entry in deletions {
                            output += "[\(entry.timestamp)] \(entry.tableName) - \(entry.recordTitle) (id: \(entry.recordID), collection: \(entry.collectionID))\n"
                        }
                    }
                    output += "\n=== Sync Event Log ===\n"
                    if let events = try? SyncEventLogger.recentEvents(from: database, limit: 100) {
                        for entry in events {
                            output += "[\(entry.timestamp)] \(entry.eventType)"
                            if !entry.recordType.isEmpty { output += " [\(entry.recordType)]" }
                            if !entry.errorCode.isEmpty { output += " error=\(entry.errorCode)" }
                            if !entry.details.isEmpty { output += " \(entry.details)" }
                            output += "\n"
                        }
                    }
                    #if os(iOS)
                    await MainActor.run {
                        UIPasteboard.general.string = output
                    }
                    #elseif os(macOS)
                    await MainActor.run {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(output, forType: .string)
                    }
                    #endif
                }

            // MARK: - CloudKit Record Type Probe

            case .recordTypeProbeToggled:
                state.showingRecordTypeProbe.toggle()
                return .none

            case .runRecordTypeProbe:
                state.isRunningProbe = true
                let recordTypes = ["collections", "bookItems", "movieItems", "tVShowItems", "restaurantItems"]
                state.recordTypeProbeResults = Dictionary(uniqueKeysWithValues: recordTypes.map { ($0, RecordTypeProbeResult.pending) })
                return .run { send in
                    let container = CKContainer(identifier: "iCloud.TravelingSnails")
                    let db = container.privateCloudDatabase
                    let zoneID = CKRecordZone.ID(
                        zoneName: "co.pointfree.SQLiteData.defaultZone",
                        ownerName: CKCurrentUserDefaultName
                    )
                    var results: [String: RecordTypeProbeResult] = [:]

                    for recordType in recordTypes {
                        let testRecordID = CKRecord.ID(
                            recordName: "probe-\(UUID().uuidString)",
                            zoneID: zoneID
                        )
                        let testRecord = CKRecord(recordType: recordType, recordID: testRecordID)

                        do {
                            let saved = try await db.save(testRecord)
                            // Clean up the test record
                            try await db.deleteRecord(withID: saved.recordID)
                            results[recordType] = .success
                        } catch let error as CKError {
                            results[recordType] = .failed("\(error.code.rawValue): \(error.localizedDescription)")
                        } catch {
                            results[recordType] = .failed(error.localizedDescription)
                        }
                    }

                    await send(.recordTypeProbeCompleted(results))
                }

            case .recordTypeProbeCompleted(let results):
                state.recordTypeProbeResults = results
                state.isRunningProbe = false
                return .none

            // MARK: - Force Re-sync

            case .forceResyncTapped:
                state.isForceResyncing = true
                state.forceResyncResult = nil
                return .run { send in
                    do {
                        let result = try await database.write { db -> String in
                            // Step 1: Clear the SyncEngine's cached server records and state
                            // so it treats all local records as new and pushes them fresh.
                            let metaSchema = "sqlitedata_icloud"

                            // Clear server record cache — SyncEngine will create new CKRecords
                            try db.execute(sql: """
                                UPDATE "\(metaSchema)"."sqlitedata_icloud_metadata"
                                SET "lastKnownServerRecord" = NULL,
                                    "_lastKnownServerRecordAllFields" = NULL
                                """)

                            // Clear state serialization — CKSyncEngine will start fresh
                            try db.execute(sql: """
                                DELETE FROM "\(metaSchema)"."sqlitedata_icloud_stateSerialization"
                                """)

                            // Step 2: Touch every record in every synced table to trigger
                            // the afterUpdate trigger, which queues records for CloudKit push.
                            let syncedTables = [
                                "collections", "bookItems", "movieItems", "tVShowItems", "restaurantItems",
                                "trips", "activities", "lodgings", "transportations", "transportationLegs",
                                "addresses", "organizations", "embeddedFileAttachments",
                            ]
                            var touchedCounts: [String: Int] = [:]
                            for table in syncedTables {
                                try db.execute(sql: """
                                    UPDATE "\(table)" SET "id" = "id"
                                    """)
                                let count = db.changesCount
                                touchedCounts[table] = count
                            }

                            let totalTouched = touchedCounts.values.reduce(0, +)
                            return "Cleared server state, touched \(totalTouched) records across \(syncedTables.count) tables. Restart app to complete re-sync."
                        }

                        SyncEventLogger.log(
                            on: database,
                            type: "FORCE_RESYNC",
                            details: result
                        )

                        await send(.forceResyncCompleted(result))
                    } catch {
                        await send(.forceResyncCompleted("Error: \(error.localizedDescription)"))
                    }
                }

            case .forceResyncCompleted(let result):
                state.isForceResyncing = false
                state.forceResyncResult = result
                return .none
            }
        }
    }
}
