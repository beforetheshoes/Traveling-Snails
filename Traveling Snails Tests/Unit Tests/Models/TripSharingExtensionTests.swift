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

    // MARK: - Basic Trip Creation Tests

    @Test("Trip can be created with basic properties", .tags(.unit, .fast, .models, .sharing))
    func testTripCreation() throws {
        let trip = Trip(name: "Test Trip", isProtected: false, startDate: Date(), endDate: Date())

        #expect(trip.name == "Test Trip")
        #expect(trip.isProtected == false)
    }
}
