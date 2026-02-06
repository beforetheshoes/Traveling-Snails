//
//  UniversalActivityFormFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("UniversalActivityFormFeature Tests")
struct UniversalActivityFormFeatureTests {
    @Test("Form validation requires name and organization", .tags(.unit, .fast, .parallel, .validation))
    func formValidationRequiresFields() {
        let trip = Trip(name: "Test Trip")
        let state = UniversalActivityFormFeature.State(trip: trip, activityType: .activity)

        #expect(!state.isFormValid)
    }

    @Test("Save action succeeds with valid data", .tags(.unit, .medium, .parallel, .database))
    func saveActionSucceeds() async throws {
        let database = try makeTestDatabase()

        let trip = Trip(name: "Test Trip")
        let noneOrg = Organization(name: "None")

        try await database.write { db in
            try Trip.insert { trip }.execute(db)
            try Organization.insert { noneOrg }.execute(db)
        }

        var state = UniversalActivityFormFeature.State(trip: trip, activityType: .activity)
        state.editData.name = "Museum"

        let store = TestStore(initialState: state) {
            UniversalActivityFormFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.setOrganization(noneOrg)) {
            $0.editData.organization = noneOrg
        }

        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }

        await store.receive(\.saveFinished) {
            $0.isSaving = false
            $0.shouldDismiss = true
        }
    }

    @Test("Attachment error updates save error", .tags(.unit, .fast, .parallel, .validation))
    func attachmentErrorUpdatesSaveError() async {
        let trip = Trip(name: "Test Trip")
        let store = TestStore(initialState: UniversalActivityFormFeature.State(trip: trip, activityType: .activity)) {
            UniversalActivityFormFeature()
        }

        await store.send(.attachmentError("Failed to attach")) {
            $0.saveError = NSError(domain: "AttachmentError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to attach"])
        }
    }
}

private func makeTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
