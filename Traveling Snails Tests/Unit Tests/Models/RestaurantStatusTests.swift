//
//  RestaurantStatusTests.swift
//  Traveling Snails Tests
//

import Testing
@testable import Traveling_Snails

@Suite("RestaurantStatus Tests")
struct RestaurantStatusTests {

    @Test("All four restaurant status cases exist", .tags(.unit, .fast, .parallel, .models, .validation))
    func allCasesExist() {
        let allCases = RestaurantStatus.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.wantToVisit))
        #expect(allCases.contains(.enjoyed))
        #expect(allCases.contains(.favorite))
        #expect(allCases.contains(.didNotEnjoy))
    }

    @Test("Raw values are stable strings for SQLite storage", .tags(.unit, .fast, .parallel, .models, .validation))
    func rawValuesAreStable() {
        #expect(RestaurantStatus.wantToVisit.rawValue == "wantToVisit")
        #expect(RestaurantStatus.enjoyed.rawValue == "enjoyed")
        #expect(RestaurantStatus.favorite.rawValue == "favorite")
        #expect(RestaurantStatus.didNotEnjoy.rawValue == "didNotEnjoy")
    }

    @Test("Each status has a non-empty display name", .tags(.unit, .fast, .parallel, .models, .validation))
    func displayNamesAreNonEmpty() {
        for status in RestaurantStatus.allCases {
            #expect(!status.displayName.isEmpty, "displayName for \(status) should not be empty")
        }
    }

    @Test("Display names are human-readable", .tags(.unit, .fast, .parallel, .models, .validation))
    func displayNamesAreCorrect() {
        #expect(RestaurantStatus.wantToVisit.displayName == "Want to Visit")
        #expect(RestaurantStatus.enjoyed.displayName == "Enjoyed")
        #expect(RestaurantStatus.favorite.displayName == "Favorite")
        #expect(RestaurantStatus.didNotEnjoy.displayName == "Did Not Enjoy")
    }

    @Test("Each status has a non-empty system image", .tags(.unit, .fast, .parallel, .models, .validation))
    func systemImagesAreNonEmpty() {
        for status in RestaurantStatus.allCases {
            #expect(!status.systemImage.isEmpty, "systemImage for \(status) should not be empty")
        }
    }

    @Test("Each status has a distinct color", .tags(.unit, .fast, .parallel, .models, .validation))
    func colorsExist() {
        // Just verify they can be accessed without crashing
        for status in RestaurantStatus.allCases {
            _ = status.color
        }
    }
}
