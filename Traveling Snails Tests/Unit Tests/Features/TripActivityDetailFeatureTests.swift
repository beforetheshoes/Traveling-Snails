import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("TripActivityDetailFeature Tests")
@MainActor
struct TripActivityDetailFeatureTests {
    @Test("save persists edited activity")
    func savePersistsEditedActivity() async throws {
        let database = try makeTripActivityDetailTestDatabase()
        let activity = {
            var value = Activity(name: "Old Name")
            value.cost = 10
            return value
        }()
        let activityID = activity.id

        try await database.write { db in
            try Activity.upsert { activity }.execute(db)
        }

        let store = TestStore(
            initialState: TripActivityDetailFeature.State(snapshot: .activity(activity))
        ) {
            TripActivityDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.startEditing) {
            $0.isEditing = true
        }
        await store.send(.binding(.set(\.editData.name, "New Name"))) {
            $0.editData.name = "New Name"
        }
        await store.send(.saveTapped)
        await store.receive(\.saveSucceeded) {
            if case .activity(var snapshot) = $0.snapshot {
                snapshot.name = "New Name"
                $0.snapshot = .activity(snapshot)
            }
            $0.isEditing = false
            if case .activity(let saved) = $0.snapshot {
                #expect(saved.name == "New Name")
            } else {
                Issue.record("Expected activity snapshot")
            }
        }

        let saved = try await database.read { db in
            try Activity.find(activityID).fetchOne(db)
        }
        #expect(saved?.name == "New Name")
    }

    @Test("delete marks view for dismissal")
    func deleteMarksDismissal() async throws {
        let database = try makeTripActivityDetailTestDatabase()
        let transportation = Transportation(name: "Flight")

        try await database.write { db in
            try Transportation.upsert { transportation }.execute(db)
        }

        let store = TestStore(
            initialState: TripActivityDetailFeature.State(snapshot: .transportation(transportation))
        ) {
            TripActivityDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.deleteConfirmed)
        await store.receive(\.deleteSucceeded) {
            $0.shouldDismiss = true
        }

        let deleted = try await database.read { db in
            try Transportation.find(transportation.id).fetchOne(db)
        }
        #expect(deleted == nil)
    }
}

private func makeTripActivityDetailTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
