//
//  PerformanceTestSuite.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

/// Performance tests using the advanced testing framework
@Suite("Performance Tests")
@MainActor
struct PerformanceTestSuite {
    @Test("SwiftData trip insertion performance")
    func testTripInsertionPerformance() async throws {
        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Trip Insertion",
            iterations: 100,
            operation: { modelContext in
            let trip = Trip(
                name: "Performance Test Trip \(UUID().uuidString)",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: false
            )
            modelContext.insert(trip)
            try modelContext.save()
            }, baseline: 0.01)

        // Verify performance is within acceptable bounds
        #expect(metrics.averageDuration < 0.02) // Average should be under 20ms
        #expect(metrics.maxDuration < 0.1) // Max should be under 100ms

        if let withinBaseline = metrics.isWithinBaseline {
            #expect(withinBaseline) // Should meet baseline performance
        }
    }

    @Test("SwiftData batch trip query performance")
    func testBatchTripQueryPerformance() async throws {
        // Setup: Create test data
        let testBase = SwiftDataTestBase()
        try TestDataGenerator.generateLargeDataset(
            tripCount: 500,
            activitiesPerTrip: 5,
            in: testBase.modelContext
        )

        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Batch Trip Query",
            iterations: 50,
            operation: { modelContext in
            let descriptor = FetchDescriptor<Trip>(
                sortBy: [SortDescriptor<Trip>(\.startDate, order: .reverse)]
            )
            let trips = try modelContext.fetch(descriptor)

            // Ensure we actually fetch the data
            _ = trips.count
            _ = trips.first?.name
            }, baseline: 0.05)

        #expect(metrics.averageDuration < 0.1) // Should query 500 trips in under 100ms

        if let withinBaseline = metrics.isWithinBaseline {
            #expect(withinBaseline)
        }
    }

    @Test("SwiftData relationship traversal performance")
    func testRelationshipTraversalPerformance() async throws {
        // Setup: Create trip with many activities
        let testBase = SwiftDataTestBase()
        let trip = Trip(
            name: "Performance Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)

        // Add 100 activities to test relationship performance
        for i in 0..<100 {
            let activity = Activity()
            activity.name = "Activity \(i)"
            activity.start = Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.notes = "Performance test activity"
            activity.trip = trip
            testBase.modelContext.insert(activity)
        }
        try testBase.modelContext.save()

        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Relationship Traversal",
            iterations: 100,
            operation: { modelContext in
            let descriptor = FetchDescriptor<Trip>()
            let trips = try modelContext.fetch(descriptor)

            for trip in trips {
                // Access relationship - this should be fast
                _ = trip.activity.count
                _ = trip.activity.first?.name
            }
            }, baseline: 0.005)

        #expect(metrics.averageDuration < 0.01) // Relationship access should be very fast

        if let withinBaseline = metrics.isWithinBaseline {
            #expect(withinBaseline)
        }
    }

    @Test("Memory usage during large dataset operations")
    func testLargeDatasetMemoryUsage() async throws {
        let metrics = try await PerformanceTestFramework.measureMemoryUsage(
            name: "Large Dataset Memory"
        ) {
            let testBase = SwiftDataTestBase()

            // Create large dataset
            try TestDataGenerator.generateLargeDataset(
                tripCount: 200,
                activitiesPerTrip: 10,
                in: testBase.modelContext
            )

            // Query all data
            let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
            let activities = try testBase.modelContext.fetch(FetchDescriptor<Activity>())

            // Access relationships to ensure data is loaded
            for trip in trips {
                _ = trip.activity.count
            }

            // Ensure data isn't optimized away
            _ = trips.count
            _ = activities.count
        }

        // Memory delta should be reasonable (under 50MB for test dataset)
        #expect(metrics.memoryDelta < 50)

        Logger.shared.info("Memory test completed - Initial: \(metrics.initialMemory)MB, Final: \(metrics.finalMemory)MB, Delta: \(metrics.memoryDelta)MB", category: .debug)
    }

    @Test("Sync service performance under load")
    func testSyncServicePerformance() async throws {
        let container = TestServiceContainer.create { mocks in
            mocks.sync.configureSuccessfulSync()
        }

        let syncService = container.resolve(SyncService.self)

        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Sync Service Performance",
            iterations: 20,
            operation: { _ in
            await syncService.triggerSyncAndWait()
            }, baseline: 0.5)

        #expect(metrics.averageDuration < 0.5) // Sync should complete in under 500ms with mocks

        if let withinBaseline = metrics.isWithinBaseline {
            #expect(withinBaseline)
        }
    }

    @Test("Authentication service performance")
    func testAuthenticationPerformance() async throws {
        let container = TestServiceContainer.create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
        }

        let authService = container.resolve(AuthenticationService.self)

        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Authentication Service Performance",
            iterations: 100,
            operation: { _ in
            // Test authentication state queries  
            _ = authService.allTripsLocked

            // Create a test trip for authentication testing
            let testTrip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: true)
            _ = authService.isAuthenticated(for: testTrip)
            _ = authService.isProtected(testTrip)

            // Test lock operations
            authService.lockAllTrips()
            authService.lockTrip(testTrip)
            }, baseline: 0.001)

        #expect(metrics.averageDuration < 0.005) // Auth operations should be very fast

        if let withinBaseline = metrics.isWithinBaseline {
            #expect(withinBaseline)
        }
    }
}
