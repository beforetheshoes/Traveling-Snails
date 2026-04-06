//
//  TripActivityFormFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("TripActivityFormFeature Tests")
@MainActor
struct TripActivityFormFeatureTests {
    @Test("Form validation requires name and organization", .tags(.unit, .fast, .parallel, .validation))
    func formValidationRequiresFields() {
        let trip = Trip(name: "Test Trip")
        let state = TripActivityFormFeature.State(trip: trip, activityType: .activity)

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

        var state = TripActivityFormFeature.State(trip: trip, activityType: .activity)
        state.editData.name = "Museum"

        let store = TestStore(initialState: state) {
            TripActivityFormFeature()
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
        let store = TestStore(initialState: TripActivityFormFeature.State(trip: trip, activityType: .activity)) {
            TripActivityFormFeature()
        }

        await store.send(.attachmentError("Failed to attach")) {
            $0.saveError = NSError(domain: "AttachmentError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to attach"])
        }
    }

    @Test("Transportation save persists legs and derives top-level times", .tags(.unit, .medium, .parallel, .database, .transportation))
    func transportationSavePersistsLegs() async throws {
        let database = try makeTestDatabase()

        let trip = Trip(name: "Test Trip")
        let noneOrg = Organization(name: "None")

        try await database.write { db in
            try Trip.insert { trip }.execute(db)
            try Organization.insert { noneOrg }.execute(db)
        }

        var state = TripActivityFormFeature.State(trip: trip, activityType: .transportation)
        state.editData.name = "Flights"
        // Provide a stable, valid 2-leg itinerary.
        let tid = try #require(state.transportationID)
        let leg1 = TransportationLeg(
            transportationID: tid,
            sortIndex: 0,
            type: .plane,
            departure: Date(timeIntervalSince1970: 1_700_000_000),
            departureTZId: "America/New_York",
            departureLocationName: "JFK",
            arrival: Date(timeIntervalSince1970: 1_700_003_600),
            arrivalTZId: "America/Chicago",
            arrivalLocationName: "ORD",
            serviceNumber: "AA123"
        )
        let leg2 = TransportationLeg(
            transportationID: tid,
            sortIndex: 1,
            type: .plane,
            departure: Date(timeIntervalSince1970: 1_700_004_200),
            departureTZId: "America/Chicago",
            departureLocationName: "ORD",
            arrival: Date(timeIntervalSince1970: 1_700_006_000),
            arrivalTZId: "America/Los_Angeles",
            arrivalLocationName: "LAX",
            serviceNumber: "AA456"
        )
        state.transportationLegs = [leg1, leg2]

        let store = TestStore(initialState: state) {
            TripActivityFormFeature()
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

        let savedTransportation = try await database.read { db in
            try Transportation.find(tid).fetchOne(db)
        }
        let savedLegs = try await database.read { db in
            try TransportationLeg.where { $0.transportationID.eq(tid) }
                .order { $0.sortIndex.asc() }
                .fetchAll(db)
        }

        #expect(savedTransportation != nil)
        #expect(savedLegs.count == 2)
        let t = try #require(savedTransportation)
        #expect(t.startTZId == "America/New_York")
        #expect(t.endTZId == "America/Los_Angeles")
        #expect(t.start == leg1.departure)
        #expect(t.end == leg2.arrival)
    }
}

private func makeTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
