import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("Add and Edit Trip Feature Tests")
@MainActor
struct AddAndEditTripFeatureTests {
    @Test("AddTripFeature saves new trip and dismisses", .tags(.unit, .medium, .parallel, .database))
    func addTripSaves() async throws {
        let database = try makeTestDatabase()

        let store = TestStore(initialState: AddTripFeature.State()) {
            AddTripFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.binding(.set(\.name, "Paris"))) {
            $0.name = "Paris"
        }
        await store.send(.binding(.set(\.notes, "Vacation"))) {
            $0.notes = "Vacation"
        }
        await store.send(.binding(.set(\.hasStartDate, true))) {
            $0.hasStartDate = true
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.errorMessage = nil
        }

        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
            $0.shouldDismiss = true
        }

        let trips = try await database.read { db in
            try Trip.fetchAll(db)
        }
        #expect(trips.count == 1)
        #expect(trips[0].name == "Paris")
    }

    @Test("EditTripFeature updates existing trip", .tags(.unit, .medium, .parallel, .database))
    func editTripUpdates() async throws {
        let database = try makeTestDatabase()
        let trip = Trip(name: "Old Name", notes: "Old")
        let tripID = trip.id

        try await database.write { db in
            try Trip.insert { trip }.execute(db)
        }

        let syncCallCount = SyncCallCounter()

        let store = TestStore(initialState: EditTripFeature.State(trip: trip)) {
            EditTripFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.syncClient = .init(
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
                triggerSync: {
                    await syncCallCount.increment()
                },
                triggerSyncWithRetry: {},
                setSyncProtectedTrips: { _ in },
                setNetworkStatus: { _ in },
                simulateNetworkError: {}
            )
        }

        await store.send(.binding(.set(\.name, "New Name"))) {
            $0.name = "New Name"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.errorMessage = nil
        }

        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
            $0.shouldDismiss = true
        }

        let savedTrip = try await database.read { db in
            try Trip.find(tripID).fetchOne(db)
        }

        #expect(savedTrip?.name == "New Name")
        #expect(await syncCallCount.value == 1)
    }

    @Test("EditTripFeature deletes trip", .tags(.unit, .medium, .parallel, .database))
    func editTripDeletes() async throws {
        let database = try makeTestDatabase()
        let trip = Trip(name: "Delete Me")

        try await database.write { db in
            try Trip.insert { trip }.execute(db)
        }

        let store = TestStore(initialState: EditTripFeature.State(trip: trip)) {
            EditTripFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.syncClient = .init(
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

        await store.send(.deleteTapped) {
            $0.showDeleteConfirmation = true
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
            $0.isSaving = true
        }

        await store.receive(\.deleteSucceeded) {
            $0.isSaving = false
            $0.shouldDismiss = true
        }

        let fetched = try await database.read { db in
            try Trip.find(trip.id).fetchOne(db)
        }
        #expect(fetched == nil)
    }
}

private func makeTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}

private actor SyncCallCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
