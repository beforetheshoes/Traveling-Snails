import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("SyncDiagnosticFeature Tests")
@MainActor
struct SyncDiagnosticFeatureTests {
    @Test("refresh loads sync status")
    func refreshLoadsSyncStatus() async {
        let expected = SyncStatusSnapshot(
            isSyncing: true,
            lastSyncDate: Date(timeIntervalSince1970: 1_700_000_000),
            pendingChangesCount: 3,
            networkStatus: .offline,
            syncProtectedTrips: false,
            hasSyncError: true
        )

        let store = TestStore(initialState: SyncDiagnosticFeature.State()) {
            SyncDiagnosticFeature()
        } withDependencies: {
            $0.syncClient.status = { expected }
        }

        await store.send(.refreshTapped) {
            $0.isRefreshing = true
        }
        await store.receive(.statusLoaded(expected)) {
            $0.status = expected
            $0.isRefreshing = false
        }
    }

    @Test("toggle sync protected trips sends update and refreshes status")
    func toggleSyncProtectedTrips() async {
        let expected = SyncStatusSnapshot(
            isSyncing: false,
            lastSyncDate: nil,
            pendingChangesCount: 0,
            networkStatus: .online,
            syncProtectedTrips: false,
            hasSyncError: false
        )

        let store = TestStore(initialState: SyncDiagnosticFeature.State()) {
            SyncDiagnosticFeature()
        } withDependencies: {
            $0.syncClient.setSyncProtectedTrips = { _ in }
            $0.syncClient.status = { expected }
        }

        await store.send(.syncProtectedTripsChanged(false)) {
            $0.status.syncProtectedTrips = false
            $0.isRefreshing = true
        }
        await store.receive(.statusLoaded(expected)) {
            $0.status = expected
            $0.isRefreshing = false
        }
    }
}
