import ComposableArchitecture
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("DatabaseCleanupFeature Tests")
@MainActor
struct DatabaseCleanupFeatureTests {
    @Test("remove test data deletes matching trips and organizations")
    func removeTestDataDeletesMatches() async throws {
        let database = try makeDatabaseCleanupTestDatabase()

        let testTrip = Trip(name: "Test Trip")
        let keepTrip = Trip(name: "Summer Vacation")
        let testOrg = Organization(name: "Demo Org")
        let keepOrg = Organization(name: "Real Org")

        try await database.write { db in
            try Trip.upsert { testTrip }.execute(db)
            try Trip.upsert { keepTrip }.execute(db)
            try Organization.upsert { testOrg }.execute(db)
            try Organization.upsert { keepOrg }.execute(db)
        }

        let store = TestStore(initialState: DatabaseCleanupFeature.State()) {
            DatabaseCleanupFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.testDataConfirmed)
        await store.receive(\.cleanupCompleted) {
            $0.isDeleting = false
            #expect($0.deleteResult.contains("Removed 1 test trips and 1 test organizations"))
        }
        await store.receive(.onAppear)
        await store.receive(.countsLoaded(trips: 1, organizations: 1, addresses: 0)) {
            $0.tripCount = 1
            $0.organizationCount = 1
            $0.addressCount = 0
        }

        let counts = try await database.read { db in
            (try Trip.fetchCount(db), try Organization.fetchCount(db))
        }
        #expect(counts.0 == 1)
        #expect(counts.1 == 1)
    }
}

private func makeDatabaseCleanupTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
