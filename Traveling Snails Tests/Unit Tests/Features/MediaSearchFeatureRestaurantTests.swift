//
//  MediaSearchFeatureRestaurantTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("MediaSearchFeature Restaurant Tests")
@MainActor
struct MediaSearchFeatureRestaurantTests {

    private func makeResult(
        id: String = "test-123",
        name: String = "Test Restaurant",
        address: String = "123 Main St",
        category: String = "Restaurant"
    ) -> RestaurantSearchResult {
        RestaurantSearchResult(
            id: id,
            name: name,
            address: address,
            city: "Test City",
            state: "TS",
            postalCode: "12345",
            country: "United States",
            phone: "555-1234",
            websiteURL: "https://test.com",
            latitude: 40.7,
            longitude: -74.0,
            category: category,
            timeZoneIdentifier: "America/New_York",
            priceLevel: 2
        )
    }

    // MARK: - MediaSearchResultItem.restaurant

    @Test("Restaurant search result item has correct properties", .tags(.unit, .fast, .parallel))
    func restaurantResultItem() {
        let result = makeResult()
        let item = MediaSearchResultItem.restaurant(result)

        #expect(item.id == "restaurant-test-123")
        #expect(item.title == "Test Restaurant")
        #expect(item.subtitle == "123 Main St")
        #expect(item.thumbnailURL == "")
        #expect(item.detail == "Restaurant")
    }

    // MARK: - Search dispatch

    @Test("Search dispatches to MapKit client for restaurant type", .tags(.unit, .fast, .parallel))
    func searchDispatchesForRestaurant() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let expectedResult = makeResult(id: "pizza-1", name: "Great Pizza", category: "Café")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .restaurant,
                searchText: "pizza"
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.mapKitSearchClient.search = { _ in [expectedResult] }
            $0.defaultDatabase = dbq
        }

        await store.send(.searchSubmitted) {
            $0.isSearching = true
            $0.hasSearched = true
        }

        await store.receive(.searchResults([.restaurant(expectedResult)])) {
            $0.isSearching = false
            $0.results = [.restaurant(expectedResult)]
        }
    }

    // MARK: - Save selected result

    @Test("Selecting a restaurant result saves to database", .tags(.unit, .fast, .parallel))
    func saveSelectedRestaurant() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .restaurant)
        try await dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let result = makeResult(id: "save-test", name: "Saved Restaurant")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .restaurant
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.defaultDatabase = dbq
            $0.mapKitSearchClient.generateSnapshot = { _, _, _ in nil }
        }
        store.exhaustivity = .off

        await store.send(.resultSelected(.restaurant(result)))
        await store.receive(.itemSaved)

        let items = try await dbq.read { db in
            try RestaurantItem.fetchAll(db)
        }
        #expect(items.count == 1)
        #expect(items.first?.title == "Saved Restaurant")
        #expect(items.first?.city == "Test City")
        #expect(items.first?.category == "Restaurant")
        #expect(items.first?.timeZoneIdentifier == "America/New_York")
    }

    // MARK: - Search placeholder and sheet title

    @Test("Restaurant search has correct placeholder and title", .tags(.unit, .fast, .parallel))
    func searchPlaceholderAndTitle() {
        let state = MediaSearchFeature.State(
            collectionID: UUID(),
            collectionType: .restaurant
        )

        #expect(state.searchPlaceholder == "Search restaurants by name or cuisine")
        #expect(state.sheetTitle == "Add Restaurant")
    }
}
