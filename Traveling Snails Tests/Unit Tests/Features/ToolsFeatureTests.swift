import ComposableArchitecture
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("ToolsFeature Tests")
@MainActor
struct ToolsFeatureTests {
    @Test("create test data inserts trip organization transportation")
    func createTestDataInsertsRecords() async throws {
        let database = try makeToolsTestDatabase()

        let store = TestStore(initialState: ToolsFeature.State()) {
            ToolsFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.createTestDataTapped)

        await store.receive(\.operationCompleted) {
            $0.isPerformingOperation = false
            $0.operationStatus = "Test data created successfully"
        }

        let counts = try await database.read { db in
            (try Trip.fetchCount(db), try Organization.fetchCount(db), try Transportation.fetchCount(db))
        }
        #expect(counts.0 == 1)
        #expect(counts.1 == 1)
        #expect(counts.2 == 1)
    }

    @Test("confirm reset removes non-None organizations and related rows")
    func confirmResetRemovesRows() async throws {
        let database = try makeToolsTestDatabase()
        let trip = Trip(name: "Trip")
        let org = Organization(name: "Org")
        let noneOrg = Organization(name: "None")
        let address = Address(street: "1 Main", city: "Town", state: "CA", country: "USA", postalCode: "90210")

        try await database.write { db in
            try Trip.upsert { trip }.execute(db)
            try Organization.upsert { org }.execute(db)
            try Organization.upsert { noneOrg }.execute(db)
            try Address.upsert { address }.execute(db)
        }

        let store = TestStore(initialState: ToolsFeature.State()) {
            ToolsFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.confirmReset)
        await store.receive(\.operationCompleted) {
            $0.isPerformingOperation = false
            #expect($0.operationStatus.contains("Reset complete"))
        }

        let counts = try await database.read { db in
            (
                try Trip.fetchCount(db),
                try Organization.fetchCount(db),
                try Address.fetchCount(db)
            )
        }
        #expect(counts.0 == 0)
        #expect(counts.1 == 1) // Preserve None organization.
        #expect(counts.2 == 0)
    }
}

private func makeToolsTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
