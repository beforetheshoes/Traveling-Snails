//
//  RestaurantItemTests.swift
//  Traveling Snails Tests
//

import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("RestaurantItem Tests")
struct RestaurantItemTests {

    // MARK: - Default Initialization

    @Test("Default initialization sets expected values", .tags(.unit, .fast, .parallel, .models))
    func defaultInitialization() {
        let collectionID = UUID()
        let item = RestaurantItem(collectionID: collectionID)

        #expect(item.collectionID == collectionID)
        #expect(item.title == "")
        #expect(item.cuisine == "")
        #expect(item.phone == "")
        #expect(item.address == "")
        #expect(item.latitude == 0)
        #expect(item.longitude == 0)
        #expect(item.priceLevel == 0)
        #expect(item.websiteURL == "")
        #expect(item.coverImageData == nil)
        #expect(item.externalID == "")
        #expect(item.rating == 0)
        #expect(item.status == .wantToVisit)
        #expect(item.hasVisitedDate == false)
        #expect(item.notes == "")
        #expect(item.sortOrder == 0)
    }

    // MARK: - CollectionItemProtocol Conformance

    @Test("Conforms to CollectionItemProtocol", .tags(.unit, .fast, .parallel, .models))
    func protocolConformance() {
        let item = RestaurantItem(collectionID: UUID())
        let protocolItem: any CollectionItemProtocol = item
        #expect(protocolItem.id == item.id)
        #expect(RestaurantItem.collectionType == .restaurant)
    }

    @Test("coverImageURL returns empty string", .tags(.unit, .fast, .parallel, .models))
    func coverImageURLIsEmpty() {
        let item = RestaurantItem(collectionID: UUID())
        #expect(item.coverImageURL == "")
    }

    @Test("displaySubtitle returns address", .tags(.unit, .fast, .parallel, .models))
    func displaySubtitleReturnsAddress() {
        var item = RestaurantItem(collectionID: UUID())
        item.address = "123 Main St"
        #expect(item.displaySubtitle == "123 Main St")
    }

    @Test("displaySubtitle returns cuisine when address is empty", .tags(.unit, .fast, .parallel, .models))
    func displaySubtitleFallsThroughToCuisine() {
        var item = RestaurantItem(collectionID: UUID())
        item.cuisine = "Italian"
        #expect(item.displaySubtitle == "Italian")
    }

    @Test("displaySubtitle falls through to category", .tags(.unit, .fast, .parallel, .models))
    func displaySubtitleFallsThroughToCategory() {
        var item = RestaurantItem(collectionID: UUID())
        item.category = "Café"
        #expect(item.displaySubtitle == "Café")
    }

    @Test("formattedLocation builds correctly", .tags(.unit, .fast, .parallel, .models))
    func formattedLocation() {
        var item = RestaurantItem(collectionID: UUID())
        item.city = "Portland"
        item.state = "OR"
        item.country = "United States"
        #expect(item.formattedLocation == "Portland, OR")

        item.country = "France"
        #expect(item.formattedLocation == "Portland, OR, France")
    }

    @Test("timeZone computed property", .tags(.unit, .fast, .parallel, .models))
    func timeZoneComputed() {
        var item = RestaurantItem(collectionID: UUID())
        #expect(item.timeZone == nil)

        item.timeZoneIdentifier = "America/New_York"
        #expect(item.timeZone?.identifier == "America/New_York")
    }

    // MARK: - Visited Date Helpers

    @Test("setVisitedDate sets both date and flag", .tags(.unit, .fast, .parallel, .models))
    func setVisitedDate() {
        var item = RestaurantItem(collectionID: UUID())
        let date = Date()
        item.setVisitedDate(date)
        #expect(item.visitedDate == date)
        #expect(item.hasVisitedDate == true)
    }

    @Test("clearVisitedDate resets date and flag", .tags(.unit, .fast, .parallel, .models))
    func clearVisitedDate() {
        var item = RestaurantItem(collectionID: UUID())
        item.setVisitedDate(Date())
        item.clearVisitedDate()
        #expect(item.visitedDate == .distantPast)
        #expect(item.hasVisitedDate == false)
    }

    @Test("effectiveVisitedDate returns nil when flag is false", .tags(.unit, .fast, .parallel, .models))
    func effectiveVisitedDateNilWhenFlagFalse() {
        let item = RestaurantItem(collectionID: UUID())
        #expect(item.effectiveVisitedDate == nil)
    }

    @Test("effectiveVisitedDate returns date when flag is true", .tags(.unit, .fast, .parallel, .models))
    func effectiveVisitedDateReturnsDate() {
        var item = RestaurantItem(collectionID: UUID())
        let date = Date()
        item.setVisitedDate(date)
        #expect(item.effectiveVisitedDate == date)
    }

    // MARK: - Coordinate Helpers

    @Test("hasCoordinate returns false when both lat/lon are 0", .tags(.unit, .fast, .parallel, .models))
    func hasCoordinateFalseWhenZero() {
        let item = RestaurantItem(collectionID: UUID())
        #expect(item.hasCoordinate == false)
    }

    @Test("hasCoordinate returns true when lat/lon are set", .tags(.unit, .fast, .parallel, .models))
    func hasCoordinateTrueWhenSet() {
        let item = RestaurantItem(collectionID: UUID(), latitude: 40.7128, longitude: -74.0060)
        #expect(item.hasCoordinate == true)
    }

    // MARK: - CollectionType.restaurant

    @Test("CollectionType.restaurant has correct properties", .tags(.unit, .fast, .parallel, .models))
    func collectionTypeRestaurant() {
        #expect(CollectionType.restaurant.displayName == "Restaurants")
        #expect(CollectionType.restaurant.singularName == "Restaurant")
        #expect(CollectionType.restaurant.systemImage == "fork.knife")
        #expect(CollectionType.restaurant.color == .teal)
        #expect(CollectionType.restaurant.rawValue == "restaurant")
    }

    // MARK: - Database Round-Trip

    @Test("RestaurantItem persists and reads back from database", .tags(.unit, .medium, .database))
    func databaseRoundTrip() throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        let migrator = makeMigrator()
        try migrator.migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .restaurant)

        try dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let itemID = UUID()
        let item = RestaurantItem(
            id: itemID,
            collectionID: collectionID,
            title: "Test Pizza Place",
            cuisine: "Italian",
            category: "Restaurant",
            phone: "555-1234",
            address: "123 Main St",
            city: "New York",
            state: "NY",
            postalCode: "10001",
            country: "United States",
            latitude: 40.7128,
            longitude: -74.0060,
            priceLevel: 2,
            websiteURL: "https://example.com",
            timeZoneIdentifier: "America/New_York",
            externalID: "ext-123",
            rating: 4,
            status: .enjoyed,
            notes: "Great pizza"
        )

        try dbq.write { db in
            try RestaurantItem.insert { item }.execute(db)
        }

        let fetched = try dbq.read { db in
            try RestaurantItem.find(itemID).fetchOne(db)
        }

        #expect(fetched != nil)
        #expect(fetched?.title == "Test Pizza Place")
        #expect(fetched?.cuisine == "Italian")
        #expect(fetched?.category == "Restaurant")
        #expect(fetched?.phone == "555-1234")
        #expect(fetched?.address == "123 Main St")
        #expect(fetched?.city == "New York")
        #expect(fetched?.state == "NY")
        #expect(fetched?.postalCode == "10001")
        #expect(fetched?.country == "United States")
        #expect(fetched?.latitude == 40.7128)
        #expect(fetched?.longitude == -74.0060)
        #expect(fetched?.priceLevel == 2)
        #expect(fetched?.websiteURL == "https://example.com")
        #expect(fetched?.timeZoneIdentifier == "America/New_York")
        #expect(fetched?.externalID == "ext-123")
        #expect(fetched?.rating == 4)
        #expect(fetched?.status == .enjoyed)
        #expect(fetched?.notes == "Great pizza")
    }
}
