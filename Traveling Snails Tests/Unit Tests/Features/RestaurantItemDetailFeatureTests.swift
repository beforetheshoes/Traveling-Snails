//
//  RestaurantItemDetailFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("RestaurantItemDetailFeature Tests", .serialized)
@MainActor
struct RestaurantItemDetailFeatureTests {

    private func makeStore(
        item: RestaurantItem? = nil,
        database: DatabaseQueue? = nil
    ) throws -> TestStore<RestaurantItemDetailFeature.State, RestaurantItemDetailFeature.Action> {
        let dbq = try database ?? {
            let q = try DatabaseQueue(path: ":memory:")
            try makeMigrator().migrate(q)
            return q
        }()

        let restaurantItem = item ?? RestaurantItem(
            collectionID: UUID(),
            title: "Test Restaurant",
            cuisine: "Italian",
            address: "123 Main St"
        )

        let store = TestStore(
            initialState: RestaurantItemDetailFeature.State(restaurantItem: restaurantItem)
        ) {
            RestaurantItemDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = dbq
        }
        store.exhaustivity = .off
        return store
    }

    @Test("Rating change updates item", .tags(.unit, .fast, .parallel))
    func ratingChanged() async throws {
        let store = try makeStore()

        await store.send(.ratingChanged(4)) {
            $0.restaurantItem.rating = 4
        }
    }

    @Test("Status change to enjoyed sets visited date", .tags(.unit, .fast, .parallel))
    func statusChangedToEnjoyedSetsDate() async throws {
        let store = try makeStore()

        await store.send(.statusChanged(.enjoyed)) {
            $0.restaurantItem.status = .enjoyed
            $0.restaurantItem.hasVisitedDate = true
            $0.restaurantItem.visitedDate = $0.restaurantItem.visitedDate
        }
        #expect(store.state.restaurantItem.hasVisitedDate == true)
        #expect(store.state.restaurantItem.visitedDate != .distantPast)
    }

    @Test("Status change to favorite does not touch visited date", .tags(.unit, .fast, .parallel))
    func statusChangedToFavoriteKeepsDate() async throws {
        let store = try makeStore()

        await store.send(.statusChanged(.favorite)) {
            $0.restaurantItem.status = .favorite
        }
        #expect(store.state.restaurantItem.hasVisitedDate == false)
    }

    @Test("Edit notes round-trip", .tags(.unit, .fast, .parallel))
    func editNotesRoundTrip() async throws {
        let store = try makeStore()

        await store.send(.editNotesTapped) {
            $0.isEditing = true
            $0.editedNotes = ""
        }

        await store.send(.editedNotesChanged("Great food!")) {
            $0.editedNotes = "Great food!"
        }

        await store.send(.saveNotesTapped) {
            $0.isEditing = false
            $0.restaurantItem.notes = "Great food!"
        }
    }

    @Test("Cancel edit notes reverts", .tags(.unit, .fast, .parallel))
    func cancelEditNotes() async throws {
        let store = try makeStore()

        await store.send(.editNotesTapped) {
            $0.isEditing = true
            $0.editedNotes = ""
        }

        await store.send(.editedNotesChanged("Temporary")) {
            $0.editedNotes = "Temporary"
        }

        await store.send(.cancelEditNotes) {
            $0.isEditing = false
        }

        #expect(store.state.restaurantItem.notes == "")
    }

    @Test("Visited date can be set", .tags(.unit, .fast, .parallel))
    func visitedDateSet() async throws {
        let store = try makeStore()
        let date = Date()

        await store.send(.visitedDateChanged(date)) {
            $0.restaurantItem.visitedDate = date
            $0.restaurantItem.hasVisitedDate = true
        }
    }

    @Test("Visited date can be cleared", .tags(.unit, .fast, .parallel))
    func visitedDateClear() async throws {
        var item = RestaurantItem(collectionID: UUID(), title: "Test")
        item.setVisitedDate(Date())
        let store = try makeStore(item: item)

        await store.send(.visitedDateChanged(nil)) {
            $0.restaurantItem.visitedDate = .distantPast
            $0.restaurantItem.hasVisitedDate = false
        }
    }

    @Test("Delete confirmation flow", .tags(.unit, .fast, .parallel))
    func deleteConfirmationFlow() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .restaurant)
        try await dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let item = RestaurantItem(collectionID: collectionID, title: "To Delete")
        try await dbq.write { db in
            try RestaurantItem.insert { item }.execute(db)
        }

        let store = try makeStore(item: item, database: dbq)

        await store.send(.deleteTapped) {
            $0.showingDeleteConfirmation = true
        }

        await store.send(.deleteCancelled) {
            $0.showingDeleteConfirmation = false
        }

        await store.send(.deleteTapped) {
            $0.showingDeleteConfirmation = true
        }

        await store.send(.deleteConfirmed) {
            $0.showingDeleteConfirmation = false
        }

        await store.receive(.deleted)
    }
}
