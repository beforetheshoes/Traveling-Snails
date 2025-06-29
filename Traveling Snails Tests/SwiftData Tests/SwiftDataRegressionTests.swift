//
//  SwiftDataRegressionTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

/// Focused tests to prevent SwiftData infinite recreation regression
@MainActor
@Suite("SwiftData Regression Prevention Tests")
struct SwiftDataRegressionTests {
    @Test("Basic SwiftData CRUD operations work")
    func testBasicSwiftDataOperations() throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()

        // Create a trip
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        // Verify it was saved
        let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Test Trip")

        // Add a lodging
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        testBase.modelContext.insert(lodging)
        try testBase.modelContext.save()

        // Verify relationship works
        #expect(trip.totalActivities == 1)
        #expect(trip.lodging.count == 1)
        #expect(trip.lodging.first?.name == "Test Hotel")
    }

    @Test("Trip property access is fast and stable")
    func testTripPropertyAccessPerformance() throws {
        let testBase = SwiftDataTestBase()

        // Create test data
        let trip = Trip(name: "Performance Test Trip")
        testBase.modelContext.insert(trip)

        // Add some activities
        for i in 0..<5 {
            let lodging = Lodging(name: "Hotel \(i)", trip: trip)
            testBase.modelContext.insert(lodging)
        }

        try testBase.modelContext.save()

        let startTime = Date()

        // Access trip properties repeatedly - this would hang if infinite recreation occurred
        for _ in 0..<100 {
            _ = trip.totalActivities
            _ = trip.lodging.count
            _ = trip.transportation.count
            _ = trip.activity.count
        }

        let duration = Date().timeIntervalSince(startTime)

        // Should complete very quickly without infinite recreation
        #expect(duration < 1.0, "Property access should be fast, not infinite")
        #expect(trip.totalActivities == 5)
    }

    @Test("SwiftData relationships prevent infinite recreation")
    func testSwiftDataRelationshipsPreventInfiniteRecreation() throws {
        let testBase = SwiftDataTestBase()

        // Create test data that would trigger the bug
        let trip = Trip(name: "Relationship Test Trip")
        testBase.modelContext.insert(trip)

        let lodging = Lodging(name: "Test Hotel", trip: trip)
        testBase.modelContext.insert(lodging)

        try testBase.modelContext.save()

        let startTime = Date()

        // Access relationships multiple times - this used to cause infinite recreation
        for i in 0..<50 {
            _ = trip.lodging
            _ = trip.totalActivities
            _ = !trip.lodging.isEmpty

            // Modify data to trigger SwiftData updates
            if i % 10 == 0 {
                let newLodging = Lodging(name: "Dynamic Hotel \(i)", trip: trip)
                testBase.modelContext.insert(newLodging)
                try testBase.modelContext.save()
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        #expect(duration < 2.0, "Relationship access should not cause infinite recreation")
        #expect(trip.totalActivities >= 6) // Original + 5 new ones
    }

    @Test("Model context environment pattern works")
    func testModelContextEnvironmentPattern() throws {
        let testBase = SwiftDataTestBase()

        // Test that model context is available and functional
        #expect(testBase.modelContext.container === testBase.modelContainer)

        // Test basic operations that views would perform
        let trip = Trip(name: "Environment Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        // Test query operations that @Query would perform
        let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Environment Test Trip")

        // This demonstrates the correct pattern:
        // Views should use @Environment(\.modelContext) and @Query
        // rather than receive arrays of model objects as parameters
    }

    @Test("Query operations are efficient")
    func testQueryOperationsAreEfficient() throws {
        let testBase = SwiftDataTestBase()

        // Create small dataset
        for i in 0..<10 {
            let trip = Trip(name: "Query Trip \(i)")
            testBase.modelContext.insert(trip)
        }
        try testBase.modelContext.save()

        let startTime = Date()

        // Perform multiple queries
        for _ in 0..<50 {
            let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
            #expect(trips.count == 10)
        }

        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 4.0, "Query operations should be fast")
    }

    @Test("Regression prevention - anti-pattern documentation")
    func testRegressionPrevention() throws {
        let testBase = SwiftDataTestBase()

        // This test documents the CORRECT vs INCORRECT patterns

        // ❌ WRONG PATTERN (would cause infinite recreation):
        // struct BadView: View {
        //     let trips: [Trip]  // Parameter passing - BAD!
        //     init(trips: [Trip]) { self.trips = trips }
        // }

        // ✅ CORRECT PATTERN (what we implemented):
        // struct GoodView: View {
        //     @Environment(\.modelContext) private var modelContext
        //     @Query private var trips: [Trip]  // Direct querying - GOOD!
        // }

        // Test that the proper pattern works without trip parameters
        let trip = Trip(name: "Pattern Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        // Views should query directly, not receive parameters
        let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.count == 1)
        #expect(trips.first?.name == "Pattern Test Trip")

        // This is the safe pattern that prevents infinite recreation
    }
}
