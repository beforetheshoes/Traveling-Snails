//
//  DateConflictCachingTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

/// Tests for date conflict checking performance optimization through caching
@Suite("Date Conflict Caching Tests")
@MainActor
struct DateConflictCachingTests {
    
    // MARK: - Performance Tests
    
    @Test("Date conflict checking performance with large dataset")
    func testDateConflictCheckingPerformanceBaseline() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create a trip with many activities (100+ to test performance)
        let trip = Trip(
            name: "Large Performance Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add 150 activities to stress test the conflict checking
        for i in 0..<150 {
            let activity = Activity()
            activity.name = "Activity \(i)"
            activity.start = Calendar.current.date(byAdding: .hour, value: i, to: Date()) ?? Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.notes = "Performance test activity"
            activity.trip = trip
            testBase.modelContext.insert(activity)
        }
        
        // Add some lodging and transportation too
        for i in 0..<25 {
            let lodging = Lodging()
            lodging.name = "Lodging \(i)"
            lodging.start = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
            lodging.end = Calendar.current.date(byAdding: .day, value: 1, to: lodging.start) ?? lodging.start
            lodging.trip = trip
            testBase.modelContext.insert(lodging)
            
            let transportation = Transportation()
            transportation.name = "Transport \(i)"
            transportation.start = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
            transportation.end = Calendar.current.date(byAdding: .hour, value: 2, to: transportation.start) ?? transportation.start
            transportation.trip = trip
            testBase.modelContext.insert(transportation)
        }
        
        try testBase.modelContext.save()
        
        // CURRENT IMPLEMENTATION: This will be slow (no caching)
        // Measure current checkDateConflicts performance
        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Date Conflict Checking - No Cache",
            iterations: 10, // Lower iterations due to expected slowness
            operation: { _ in
                // Simulate the current checkDateConflicts logic
                let calendar = Calendar.current
                var allActivityDates: [Date] = []
                
                // Current implementation iterates through ALL activities
                for lodging in trip.lodging {
                    let startDay = calendar.startOfDay(for: lodging.start)
                    let endDay = calendar.startOfDay(for: lodging.end)
                    allActivityDates.append(contentsOf: [startDay, endDay])
                }
                
                for transportation in trip.transportation {
                    let startDay = calendar.startOfDay(for: transportation.start)
                    let endDay = calendar.startOfDay(for: transportation.end)
                    allActivityDates.append(contentsOf: [startDay, endDay])
                }
                
                for activity in trip.activity {
                    let startDay = calendar.startOfDay(for: activity.start)
                    let endDay = calendar.startOfDay(for: activity.end)
                    allActivityDates.append(contentsOf: [startDay, endDay])
                }
                
                _ = allActivityDates.min()
                _ = allActivityDates.max()
            },
            baseline: 0.1 // Current implementation should be slow
        )
        
        // Document baseline performance (this will be improved with caching)
        #expect(metrics.averageDuration > 0.05) // Should be relatively slow without caching
        
        Logger.shared.info("Baseline performance established: \(String(format: "%.3f", metrics.averageDuration))s avg", category: .debug)
    }
    
    @Test("Date conflict caching should dramatically improve repeat access performance")
    func testDateConflictCachingPerformanceImprovement() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create trip with moderate number of activities
        let trip = Trip(
            name: "Caching Performance Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add 50 activities
        for i in 0..<50 {
            let activity = Activity()
            activity.name = "Activity \(i)"
            activity.start = Calendar.current.date(byAdding: .hour, value: i, to: Date()) ?? Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.trip = trip
            testBase.modelContext.insert(activity)
        }
        
        try testBase.modelContext.save()
        
        // DESIRED BEHAVIOR: First access should populate cache, subsequent should be fast
        
        // Measure first access (cache population) - this will fail until we implement caching
        let firstAccessMetrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Date Conflict - First Access (Cache Population)",
            iterations: 1,
            operation: { _ in
                // This should call the cached date range method (TO BE IMPLEMENTED)
                _ = trip.cachedDateRange // FAILING: Property doesn't exist yet
            }
        )
        
        // Measure subsequent access (should be cached) - this will fail until we implement caching
        let cachedAccessMetrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Date Conflict - Cached Access",
            iterations: 100,
            operation: { _ in
                // This should return cached result instantly
                _ = trip.cachedDateRange // FAILING: Property doesn't exist yet
            },
            baseline: 0.001 // Should be extremely fast when cached
        )
        
        // Cache should make subsequent access much faster
        #expect(cachedAccessMetrics.averageDuration < firstAccessMetrics.averageDuration / 10)
        #expect(cachedAccessMetrics.averageDuration < 0.001) // Sub-millisecond when cached
    }
    
    // MARK: - Cache Invalidation Tests
    
    @Test("Cache should invalidate when activities are added")
    func testCacheInvalidationOnActivityAddition() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Cache Invalidation Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add initial activity
        let initialActivity = Activity()
        initialActivity.name = "Initial Activity"
        initialActivity.start = Date()
        initialActivity.end = Calendar.current.date(byAdding: .hour, value: 1, to: initialActivity.start) ?? initialActivity.start
        initialActivity.trip = trip
        testBase.modelContext.insert(initialActivity)
        
        try testBase.modelContext.save()
        
        // Get initial cached date range - this will fail until we implement caching
        let initialRange = trip.cachedDateRange // FAILING: Property doesn't exist yet
        #expect(initialRange != nil)
        
        // Verify cache is populated
        #expect(trip.isCacheValid) // FAILING: Property doesn't exist yet
        
        // Add new activity that extends the date range
        let newActivity = Activity()
        newActivity.name = "New Activity"
        newActivity.start = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date() // Outside current range
        newActivity.end = Calendar.current.date(byAdding: .hour, value: 1, to: newActivity.start) ?? newActivity.start
        newActivity.trip = trip
        testBase.modelContext.insert(newActivity)
        
        try testBase.modelContext.save()
        
        // Cache should be invalidated
        #expect(!trip.isCacheValid) // FAILING: Cache invalidation not implemented yet
        
        // New range should be different
        let newRange = trip.cachedDateRange // Should recalculate
        #expect(newRange != initialRange) // Should include the new activity's extended date
    }
    
    @Test("Cache should invalidate when activities are modified")
    func testCacheInvalidationOnActivityModification() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Cache Modification Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        let activity = Activity()
        activity.name = "Modifiable Activity"
        activity.start = Date()
        activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
        activity.trip = trip
        testBase.modelContext.insert(activity)
        
        try testBase.modelContext.save()
        
        // Get initial cached date range
        let initialRange = trip.cachedDateRange // FAILING: Property doesn't exist yet
        #expect(initialRange != nil)
        #expect(trip.isCacheValid) // FAILING: Property doesn't exist yet
        
        // Modify activity dates
        activity.start = Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date()
        activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
        
        try testBase.modelContext.save()
        
        // Cache should be invalidated after modification
        #expect(!trip.isCacheValid) // FAILING: Cache invalidation not implemented yet
        
        // New range should reflect the modification
        let modifiedRange = trip.cachedDateRange
        #expect(modifiedRange != initialRange)
    }
    
    @Test("Cache should invalidate when activities are removed")
    func testCacheInvalidationOnActivityRemoval() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Cache Removal Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add multiple activities
        let activity1 = Activity()
        activity1.start = Date()
        activity1.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity1.start) ?? activity1.start
        activity1.trip = trip
        testBase.modelContext.insert(activity1)
        
        let activity2 = Activity()
        activity2.start = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        activity2.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity2.start) ?? activity2.start
        activity2.trip = trip
        testBase.modelContext.insert(activity2)
        
        try testBase.modelContext.save()
        
        // Get initial cached date range
        let initialRange = trip.cachedDateRange // FAILING: Property doesn't exist yet
        #expect(initialRange != nil)
        
        // Remove activity that affects the date range
        testBase.modelContext.delete(activity2)
        try testBase.modelContext.save()
        
        // Cache should be invalidated
        #expect(!trip.isCacheValid) // FAILING: Cache invalidation not implemented yet
        
        // New range should be different (smaller)
        let newRange = trip.cachedDateRange
        #expect(newRange != initialRange)
    }
    
    // MARK: - Cache Memory Tests
    
    @Test("Cache memory usage should remain reasonable")
    func testCacheMemoryUsage() async throws {
        let metrics = try await PerformanceTestFramework.measureMemoryUsage(
            name: "Date Conflict Cache Memory Usage"
        ) {
            let testBase = SwiftDataTestBase()
            
            // Create multiple trips with caching
            for i in 0..<100 {
                let trip = Trip(
                    name: "Memory Test Trip \(i)",
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    isProtected: false
                )
                testBase.modelContext.insert(trip)
                
                // Add activities to each trip
                for j in 0..<20 {
                    let activity = Activity()
                    activity.name = "Activity \(j)"
                    activity.start = Calendar.current.date(byAdding: .hour, value: j, to: Date()) ?? Date()
                    activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
                    activity.trip = trip
                    testBase.modelContext.insert(activity)
                }
                
                try testBase.modelContext.save()
                
                // Access cached date range to populate cache
                _ = trip.cachedDateRange // FAILING: Property doesn't exist yet
            }
        }
        
        // Memory usage should be reasonable (under 10MB for 100 trips with cache)
        #expect(metrics.memoryDelta < 10)
    }
    
    // MARK: - Cache Correctness Tests
    
    @Test("Cached date range should match manually calculated range")
    func testCacheCorrectness() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Cache Correctness Test Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add activities with known date ranges
        let baseDate = Date()
        let calendar = Calendar.current
        
        let activity1 = Activity()
        activity1.start = baseDate
        activity1.end = calendar.date(byAdding: .hour, value: 2, to: baseDate) ?? baseDate
        activity1.trip = trip
        testBase.modelContext.insert(activity1)
        
        let activity2 = Activity()
        activity2.start = calendar.date(byAdding: .day, value: 5, to: baseDate) ?? baseDate
        activity2.end = calendar.date(byAdding: .hour, value: 3, to: activity2.start) ?? activity2.start
        activity2.trip = trip
        testBase.modelContext.insert(activity2)
        
        try testBase.modelContext.save()
        
        // Calculate expected range manually
        let expectedStart = calendar.startOfDay(for: baseDate)
        let expectedEnd = calendar.startOfDay(for: activity2.end)
        let expectedRange = expectedStart...expectedEnd
        
        // Get cached range - this will fail until we implement caching
        let cachedRange = trip.cachedDateRange // FAILING: Property doesn't exist yet
        
        #expect(cachedRange != nil)
        #expect(cachedRange?.lowerBound == expectedRange.lowerBound)
        #expect(cachedRange?.upperBound == expectedRange.upperBound)
    }
    
    @Test("Cache should handle empty trip gracefully")
    func testCacheWithEmptyTrip() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Empty Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()
        
        // Trip with no activities should return nil for cached date range
        let cachedRange = trip.cachedDateRange // FAILING: Property doesn't exist yet
        #expect(cachedRange == nil)
        
        // Cache should still be considered valid for empty trips
        #expect(trip.isCacheValid) // FAILING: Property doesn't exist yet
    }
    
    // MARK: - Integration with Existing checkDateConflicts
    
    @Test("checkDateConflicts should use cached date ranges")
    func testCheckDateConflictsUsesCaching() async throws {
        // This test verifies that the existing checkDateConflicts method
        // will be refactored to use the new caching infrastructure
        
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Conflict Check Integration Test",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add activities that extend beyond trip dates (creating conflicts)
        let conflictActivity = Activity()
        conflictActivity.start = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        conflictActivity.end = Calendar.current.date(byAdding: .hour, value: 2, to: conflictActivity.start) ?? conflictActivity.start
        conflictActivity.trip = trip
        testBase.modelContext.insert(conflictActivity)
        
        try testBase.modelContext.save()
        
        // Measure performance of conflict checking with caching
        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Date Conflict Check with Caching",
            iterations: 50,
            operation: { _ in
                // This should use the optimized cached version
                _ = trip.optimizedCheckDateConflicts() // FAILING: Method doesn't exist yet
            },
            baseline: 0.001 // Should be very fast with caching
        )
        
        #expect(metrics.averageDuration < 0.002) // Should be sub-millisecond with caching
    }
}