//
//  QuickVerificationTest.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@MainActor
@Suite("Quick Verification Tests")
struct QuickVerificationTests {
    // FIXED: Remove static initialization to prevent hanging during test bundle loading
    @MainActor
    private func createTestContainer() -> ModelContainer {
        let schema = Schema([Trip.self, Lodging.self, Transportation.self, Activity.self, Organization.self, Address.self, EmbeddedFileAttachment.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    private func createTestEnvironment() -> (container: ModelContainer, context: ModelContext) {
        let container = createTestContainer()
        let context = container.mainContext
        return (container, context)
    }

    @Test("Basic SwiftData functionality works", .tags(.integration, .fast, .parallel, .swiftdata, .validation, .smoke))
    func testBasicSwiftDataFunctionality() throws {
        let env = createTestEnvironment()
        let modelContext = env.context

        // Create a trip
        let trip = Trip(name: "Test Trip")
        modelContext.insert(trip)
        try modelContext.save()

        // Verify it was saved
        let trips = try modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.contains { $0.name == "Test Trip" })

        // Add a lodging
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        modelContext.insert(lodging)
        try modelContext.save()

        // Verify relationship works
        #expect(trip.totalActivities >= 1)
        #expect(trip.lodging.contains { $0.name == "Test Hotel" })
    }

    @Test("Test framework setup works", .tags(.integration, .fast, .parallel, .utility, .validation, .sanity))
    func testFrameworkSetup() {
        let env = createTestEnvironment()

        // Test that our test setup is working correctly
        #expect(!env.container.configurations.isEmpty)
        #expect(env.context.container === env.container)
    }

    @Test("SwiftData patterns prevent infinite recreation", .tags(.integration, .medium, .parallel, .swiftdata, .regression, .validation, .critical))
    func testInfiniteRecreationPrevention() throws {
        let env = createTestEnvironment()
        let modelContext = env.context

        // Create test data
        let trip = Trip(name: "Infinite Recreation Test")
        modelContext.insert(trip)
        try modelContext.save()

        let startTime = Date()

        // Access trip properties repeatedly (this would hang if infinite recreation occurred)
        for _ in 0..<100 {
            _ = trip.totalActivities
            _ = trip.lodging.count
            _ = trip.transportation.count
            _ = trip.activity.count
        }

        let duration = Date().timeIntervalSince(startTime)

        // Should complete very quickly without infinite recreation
        #expect(duration < 1.0, "Property access should be fast, not infinite")
    }
}
