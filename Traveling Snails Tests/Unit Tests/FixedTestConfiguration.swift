//
//  FixedTestConfiguration.swift
//  Traveling Snails
//
//

import Foundation
import Testing

@testable import Traveling_Snails

/// Simplified test helper that avoids SwiftData containers entirely
struct FixedTestConfiguration {
    /// Test basic model creation without SwiftData
    static func testBasicModelCreation() -> Bool {
        let trip = Trip(name: "Test Trip")
        let org = Organization(name: "Test Org")
        let address = Address(street: "123 Test St")

        return trip.name == "Test Trip" &&
               org.name == "Test Org" &&
               address.street == "123 Test St"
    }

    /// Test relationship handling without persistence
    static func testRelationshipHandling() -> Bool {
        let trip = Trip(name: "Relationship Test")
        let org = Organization(name: "Test Org")

        let lodging = Lodging(
            name: "Hotel",
            start: Date(),
            end: Date(),
            cost: Decimal(100),
            paid: .none,
            trip: trip,
            organization: org
        )

        return lodging.tripID == trip.id &&
               lodging.organizationID == org.id &&
               lodging.cost == Decimal(100)
    }

    /// Test protocol conformance
    static func testProtocolConformance() -> Bool {
        let trip = Trip(name: "Protocol Test")
        let org = Organization(name: "Test Org")

        let activity = Activity(
            name: "Test Activity",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )

        return activity.activityType == .activity &&
               activity.icon == "ticket.fill" &&
               activity.confirmationLabel == "Reservation"
    }

    /// Run all non-SwiftData tests
    static func runAllTests() -> (success: Bool, results: [String: Bool]) {
        let results: [String: Bool] = [
            "basicModelCreation": testBasicModelCreation(),
            "relationshipHandling": testRelationshipHandling(),
            "protocolConformance": testProtocolConformance(),
        ]

        let success = results.values.allSatisfy { $0 }
        return (success, results)
    }
}
