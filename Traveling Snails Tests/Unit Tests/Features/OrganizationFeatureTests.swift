import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("OrganizationFeature Tests")
@MainActor
struct OrganizationFeatureTests {
    @Test("Save updates organization")
    func saveUpdatesOrganization() async throws {
        let database = try makeOrganizationTestDatabase()
        let organization = Organization(name: "Old Name")

        try await database.write { db in
            try Organization.insert { organization }.execute(db)
        }

        let store = TestStore(initialState: OrganizationFeature.State(organization: organization)) {
            OrganizationFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.startEditing) {
            $0.isEditing = true
            $0.editedName = "Old Name"
        }

        await store.send(.binding(.set(\.editedName, "New Name"))) {
            $0.editedName = "New Name"
        }

        await store.send(.saveTapped)
        await store.receive(\.saveSucceeded) {
            $0.isEditing = false
        }
        await store.receive(\.onAppear)
        await store.receive(\.organizationLoaded)
        #expect(store.state.organization.name == "New Name")

        let saved = try await database.read { db in
            try Organization.find(organization.id).fetchOne(db)
        }
        #expect(saved?.name == "New Name")
    }

    @Test("Delete removes organization")
    func deleteRemovesOrganization() async throws {
        let database = try makeOrganizationTestDatabase()
        let organization = Organization(name: "Delete Me")

        try await database.write { db in
            try Organization.insert { organization }.execute(db)
        }

        let store = TestStore(initialState: OrganizationFeature.State(organization: organization)) {
            OrganizationFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.deleteTapped) {
            $0.showDeleteConfirmation = true
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
        }

        await store.receive(\.deleteSucceeded) {
            $0.shouldDismiss = true
        }

        let deleted = try await database.read { db in
            try Organization.find(organization.id).fetchOne(db)
        }
        #expect(deleted == nil)
    }
}

private func makeOrganizationTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
