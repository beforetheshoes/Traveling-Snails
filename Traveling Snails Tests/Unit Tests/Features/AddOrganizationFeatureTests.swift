import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("AddOrganizationFeature Tests")
@MainActor
struct AddOrganizationFeatureTests {
    @Test("save creates organization")
    func saveCreatesOrganization() async throws {
        let database = try makeAddOrganizationTestDatabase()

        let store = TestStore(initialState: AddOrganizationFeature.State(prefilledName: "Cafe")) {
            AddOrganizationFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.name = "Cafe"
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
        }

        await store.receive(\.saveSucceeded) {
            $0.isSaving = false
            #expect($0.createdOrganizationID != nil)
            $0.shouldDismiss = true
        }

        let saved = try await database.read { db in
            try Organization.fetchOne(db)
        }
        #expect(saved?.name == "Cafe")
    }

    @Test("blocked logo URL shows alert and skips write")
    func blockedURLShowsAlert() async throws {
        let database = try makeAddOrganizationTestDatabase()

        let store = TestStore(initialState: AddOrganizationFeature.State()) {
            AddOrganizationFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.binding(.set(\.name, "Org"))) {
            $0.name = "Org"
        }
        await store.send(.binding(.set(\.logoURL, "javascript:alert(1)"))) {
            $0.logoURL = "javascript:alert(1)"
        }
        await store.send(.saveTapped) {
            $0.errorMessage = SecureURLHandler.alertMessage(for: .blocked, action: .cache, url: "javascript:alert(1)")
            $0.showBlockedURLAlert = true
        }

        let count = try await database.read { db in
            try Organization.fetchCount(db)
        }
        #expect(count == 0)
    }
}

private func makeAddOrganizationTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
