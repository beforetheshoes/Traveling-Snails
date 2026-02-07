import ComposableArchitecture
import Foundation
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
            }
        }
    }
}
