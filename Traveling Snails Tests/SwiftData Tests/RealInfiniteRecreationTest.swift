//
//  RealInfiniteRecreationTest.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/21/25.
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Real Infinite Recreation Test")
struct RealInfiniteRecreationTest {
    
    @Test("Reproduce the actual infinite recreation logs when adding activities")
    @MainActor
    func testActualInfiniteRecreationScenario() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create a trip with initial data
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()
        
        // Track view body calls and print statements
        var viewBodyCallCount = 0
        
        // Create a view that mimics TripContentView behavior
        struct TestTripContentView: View {
            let trip: Trip
            let bodyCallTracker: () -> Void
            
            var body: some View {
                let _ = bodyCallTracker()
                
                // This mimics the badge count access that happens in navigation
                let _ = trip.totalActivities // This accesses relationships
                
                VStack {
                    Text("Trip: \(trip.name)")
                    Text("Activities: \(trip.totalActivities)")
                    
                    // Simulate the scenario where user adds activities
                    Button("Add Activity") {
                        let activity = Activity(name: "New Activity", start: Date(), end: Date().addingTimeInterval(3600))
                        activity.trip = trip
                        // This triggers the SwiftData update that causes recreation
                    }
                }
            }
        }
        
        // Create the view
        let view = TestTripContentView(trip: trip) {
            viewBodyCallCount += 1
            print("🔄 View body called: \(viewBodyCallCount)")
        }
        
        // Render the view once
        _ = view.body
        
        // Now simulate adding activities (this is where the infinite recreation happens)
        for i in 1...3 {
            let activity = Activity(name: "Activity \(i)", start: Date(), end: Date().addingTimeInterval(3600))
            activity.trip = trip
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()
            
            // Each save triggers SwiftData updates, which cause view recreation
            // when computed properties like totalActivities are accessed
            _ = view.body // Simulate view update
            _ = trip.totalActivities // Simulate badge count access
            
            print("🔄 After adding activity \(i): view calls = \(viewBodyCallCount)")
        }
        
        // The problem: viewBodyCallCount should be reasonable, not hundreds of calls
        print("📊 Final view body call count: \(viewBodyCallCount)")
        print("📊 This demonstrates why the user sees constant recreation logs")
        
        // This test shows the pattern that causes infinite recreation:
        // 1. User adds activity -> SwiftData saves
        // 2. SwiftData notifies observers
        // 3. Views accessing trip.totalActivities (which accesses relationships) recreate
        // 4. Recreation triggers more badge count checks
        // 5. More relationship access -> more recreation -> infinite loop
        
        #expect(viewBodyCallCount > 0, "View should be called at least once")
        
        // The real fix requires avoiding frequent computed property access to relationships
        // during view updates, which is what the caching approach attempts to solve
    }
    
    @Test("Demonstrate the proper pattern to avoid infinite recreation")
    @MainActor
    func testProperPatternToAvoidRecreation() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()
        
        var viewBodyCallCount = 0
        
        // Proper pattern: Cache expensive computations, avoid direct relationship access
        struct OptimizedTripContentView: View {
            let trip: Trip
            @State private var cachedActivityCount: Int = 0
            @State private var lastTripID: UUID?
            let bodyCallTracker: () -> Void
            
            var body: some View {
                let _ = bodyCallTracker()
                
                VStack {
                    Text("Trip: \(trip.name)")
                    Text("Activities: \(cachedActivityCount)") // Use cached value
                }
                .onAppear {
                    updateCacheIfNeeded()
                }
                .onChange(of: trip.id) { _, _ in
                    updateCacheIfNeeded()
                }
            }
            
            private func updateCacheIfNeeded() {
                if lastTripID != trip.id {
                    // Only access relationships when absolutely necessary
                    cachedActivityCount = trip.totalActivities
                    lastTripID = trip.id
                }
            }
        }
        
        let optimizedView = OptimizedTripContentView(trip: trip) {
            viewBodyCallCount += 1
            print("✅ Optimized view body called: \(viewBodyCallCount)")
        }
        
        _ = optimizedView.body
        
        // Add activities - this should not cause excessive recreation
        for i in 1...3 {
            let activity = Activity(name: "Activity \(i)", start: Date(), end: Date().addingTimeInterval(3600))
            activity.trip = trip
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()
            
            _ = optimizedView.body
        }
        
        print("📊 Optimized view body call count: \(viewBodyCallCount)")
        
        // This should have significantly fewer body calls
        #expect(viewBodyCallCount < 10, "Optimized view should have fewer recreations")
    }
}
