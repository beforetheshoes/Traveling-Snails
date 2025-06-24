//
//  QuickVerificationTest.swift
//  Traveling Snails
//
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@MainActor
@Suite("Quick Verification Tests")
struct QuickVerificationTests {
    
    static let modelContainer: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Trip.self, Lodging.self, Transportation.self, Activity.self, configurations: config)
    }()
    
    static var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    @Test("Basic SwiftData functionality works")
    func testBasicSwiftDataFunctionality() throws {
        // Create a trip
        let trip = Trip(name: "Test Trip")
        Self.modelContext.insert(trip)
        try Self.modelContext.save()
        
        // Verify it was saved
        let trips = try Self.modelContext.fetch(FetchDescriptor<Trip>())
        #expect(trips.contains { $0.name == "Test Trip" })
        
        // Add a lodging
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        Self.modelContext.insert(lodging)
        try Self.modelContext.save()
        
        // Verify relationship works
        #expect(trip.totalActivities >= 1)
        #expect(trip.lodging.contains { $0.name == "Test Hotel" })
    }
    
    @Test("Test framework setup works")
    func testFrameworkSetup() {
        // Test that our test setup is working correctly
        #expect(Self.modelContainer.configurations.count > 0)
        #expect(Self.modelContext.container === Self.modelContainer)
    }
    
    @Test("SwiftData patterns prevent infinite recreation")
    func testInfiniteRecreationPrevention() throws {
        // Create test data
        let trip = Trip(name: "Infinite Recreation Test")
        Self.modelContext.insert(trip)
        try Self.modelContext.save()
        
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
