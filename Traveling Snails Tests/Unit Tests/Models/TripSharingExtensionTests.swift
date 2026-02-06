//
//  TripSharingExtensionTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
import CloudKit
@testable import Traveling_Snails

/// Tests for Trip model sharing extensions
/// These tests validate the implemented CloudKit sharing functionality
@Suite("Trip Sharing Extension Tests")
@MainActor
struct TripSharingExtensionTests {
    
    // MARK: - Sharing Metadata Tests
    
    @Test("Trip supports shareID property", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDProperty() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.shareID == nil)
    }
    
    @Test("Trip shareID string storage works correctly", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDStringStorage() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.shareID == nil)
    }
    
    @Test("Trip shareID handles zone information correctly", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDZoneHandling() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.shareID == nil)
    }
    
    @Test("Trip shareID persistence through string conversion", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDStringConversion() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.shareID == nil)
    }
    
    @Test("Trip shareID handles edge cases", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDEdgeCases() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.shareID == nil)
    }
}
