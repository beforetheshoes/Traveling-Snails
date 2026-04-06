//
//  MapKitSearchClientTests.swift
//  Traveling Snails Tests
//

import Foundation
import Testing
@testable import Traveling_Snails

@Suite("MapKitSearchClient Tests")
struct MapKitSearchClientTests {

    @Test("RestaurantSearchResult converts to RestaurantItem correctly", .tags(.unit, .fast, .parallel))
    func searchResultConvertsToItem() {
        let collectionID = UUID()
        let result = RestaurantSearchResult(
            id: "mapkit-123",
            name: "Joe's Pizza",
            address: "7 Carmine St, New York, NY",
            city: "New York",
            state: "NY",
            postalCode: "10014",
            country: "United States",
            phone: "+1-212-366-1182",
            websiteURL: "https://joespizzanyc.com",
            latitude: 40.7306,
            longitude: -74.0021,
            category: "Restaurant",
            timeZoneIdentifier: "America/New_York",
            priceLevel: 2
        )

        let item = result.toRestaurantItem(collectionID: collectionID)

        #expect(item.collectionID == collectionID)
        #expect(item.title == "Joe's Pizza")
        #expect(item.address == "7 Carmine St, New York, NY")
        #expect(item.city == "New York")
        #expect(item.state == "NY")
        #expect(item.postalCode == "10014")
        #expect(item.country == "United States")
        #expect(item.phone == "+1-212-366-1182")
        #expect(item.websiteURL == "https://joespizzanyc.com")
        #expect(item.latitude == 40.7306)
        #expect(item.longitude == -74.0021)
        #expect(item.category == "Restaurant")
        #expect(item.timeZoneIdentifier == "America/New_York")
        #expect(item.priceLevel == 2)
        #expect(item.externalID == "mapkit-123")
        #expect(item.status == .wantToVisit)
        #expect(item.rating == 0)
    }

    @Test("POICategoryLabel maps known categories", .tags(.unit, .fast, .parallel))
    func poiCategoryMapping() {
        #expect(POICategoryLabel(from: .restaurant).rawValue == "Restaurant")
        #expect(POICategoryLabel(from: .cafe).rawValue == "Café")
        #expect(POICategoryLabel(from: .bakery).rawValue == "Bakery")
        #expect(POICategoryLabel(from: .brewery).rawValue == "Brewery")
        #expect(POICategoryLabel(from: .winery).rawValue == "Winery")
        #expect(POICategoryLabel(from: .distillery).rawValue == "Distillery")
        #expect(POICategoryLabel(from: .foodMarket).rawValue == "Food Market")
        #expect(POICategoryLabel(from: nil).rawValue == "")
        #expect(POICategoryLabel(from: .airport).rawValue == "")
    }

    @Test("testValue returns empty results", .tags(.unit, .fast, .parallel))
    func testValueReturnsEmpty() async throws {
        let client = MapKitSearchClient.testValue
        let results = try await client.search("pizza")
        #expect(results.isEmpty)
    }

    @Test("testValue snapshot returns nil", .tags(.unit, .fast, .parallel))
    func testValueSnapshotReturnsNil() async {
        let client = MapKitSearchClient.testValue
        let data = await client.generateSnapshot(40.0, -74.0, "Test")
        #expect(data == nil)
    }
}
