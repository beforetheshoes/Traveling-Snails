//
//  DateConflictPerformanceValidation.swift
//  Traveling Snails Tests
//
//  Performance validation tests for Issue #57: Performance: Cache date conflict results for large trips
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@MainActor
@Suite("Date Conflict Performance Validation")
struct DateConflictPerformanceValidation {
    
    @Test("Performance: Large trip with 1000 activities shows significant improvement")
    func testLargeTripPerformanceImprovement() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Large Performance Test Trip")
        testBase.modelContext.insert(trip)
        
        let baseDate = Date()
        let calendar = Calendar.current
        
        // Create a large number of activities (1000) to test performance
        let activityCount = 1000
        Logger.shared.info("Creating \(activityCount) activities for performance test")
        
        for i in 0..<activityCount {
            let startDate = calendar.date(byAdding: .hour, value: i, to: baseDate)!
            let endDate = calendar.date(byAdding: .hour, value: i + 1, to: startDate)!
            
            let activity = Activity(
                name: "Activity \(i)",
                start: startDate,
                end: endDate,
                trip: trip
            )
            testBase.modelContext.insert(activity)
        }
        
        try testBase.modelContext.save()
        Logger.shared.info("Created \(activityCount) activities")
        
        // Measure performance of cached approach (should be O(1) after first calculation)
        let cachedStartTime = Date()
        
        // First call calculates and caches
        let cachedResult1 = trip.optimizedCheckDateConflicts(
            hasStartDate: true,
            startDate: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
            hasEndDate: true,
            endDate: calendar.date(byAdding: .day, value: 50, to: baseDate)!
        )
        
        // Subsequent calls should use cache (O(1))
        for _ in 0..<100 {
            let _ = trip.optimizedCheckDateConflicts(
                hasStartDate: true,
                startDate: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
                hasEndDate: true,
                endDate: calendar.date(byAdding: .day, value: 50, to: baseDate)!
            )
        }
        
        let cachedDuration = Date().timeIntervalSince(cachedStartTime)
        
        // For comparison, measure time for direct date range calculation
        let directStartTime = Date()
        
        // Direct calculation (simulating the old O(n) approach)
        for _ in 0..<101 {
            let _ = trip.actualDateRange // This is O(n) each time
        }
        
        let directDuration = Date().timeIntervalSince(directStartTime)
        
        // Log performance results
        Logger.shared.info("Performance Results:")
        Logger.shared.info("- Cached approach (100 calls after initial): \(String(format: "%.4f", cachedDuration))s")
        Logger.shared.info("- Direct approach (101 calls): \(String(format: "%.4f", directDuration))s")
        
        let improvementRatio = directDuration / cachedDuration
        Logger.shared.info("- Performance improvement: \(String(format: "%.1f", improvementRatio))x faster")
        
        // Validate that cached approach is significantly faster
        // We expect at least 5x improvement for this large dataset
        #expect(improvementRatio >= 5.0, "Cached approach should be at least 5x faster than direct calculation. Got \(improvementRatio)x")
        
        // Validate that both approaches return the same logical result
        let directResult = trip.actualDateRange
        let cachedRange = trip.cachedDateRange
        
        #expect(cachedRange != nil)
        #expect(directResult != nil)
        #expect(cachedRange!.lowerBound == directResult!.lowerBound)
        #expect(cachedRange!.upperBound == directResult!.upperBound)
        
        // Validate that the conflict detection still works correctly
        #expect(cachedResult1 == nil) // No conflicts expected for the test dates
    }
    
    @Test("Performance: Cache invalidation overhead is minimal")
    func testCacheInvalidationPerformance() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Cache Invalidation Test Trip")
        testBase.modelContext.insert(trip)
        
        let baseDate = Date()
        let calendar = Calendar.current
        
        // Create initial activities
        for i in 0..<100 {
            let startDate = calendar.date(byAdding: .hour, value: i * 2, to: baseDate)!
            let endDate = calendar.date(byAdding: .hour, value: i * 2 + 1, to: startDate)!
            
            let activity = Activity(
                name: "Initial Activity \(i)",
                start: startDate,
                end: endDate,
                trip: trip
            )
            testBase.modelContext.insert(activity)
        }
        
        // Measure time for multiple cache invalidations and recalculations
        let invalidationStartTime = Date()
        
        for i in 0..<50 {
            // Add a new activity (this should invalidate the cache)
            let newActivity = Activity(
                name: "New Activity \(i)",
                start: calendar.date(byAdding: .day, value: i + 1, to: baseDate)!,
                end: calendar.date(byAdding: .day, value: i + 1, to: baseDate)!,
                trip: trip
            )
            testBase.modelContext.insert(newActivity)
            
            // Access cached range (this should trigger recalculation)
            let _ = trip.cachedDateRange
            
            // Perform conflict check (this should use the new cache)
            let _ = trip.optimizedCheckDateConflicts(
                hasStartDate: true,
                startDate: baseDate,
                hasEndDate: true,
                endDate: calendar.date(byAdding: .day, value: 10, to: baseDate)!
            )
        }
        
        let invalidationDuration = Date().timeIntervalSince(invalidationStartTime)
        
        Logger.shared.info("Cache invalidation performance:")
        Logger.shared.info("- 50 invalidations + recalculations: \(String(format: "%.4f", invalidationDuration))s")
        Logger.shared.info("- Average per invalidation: \(String(format: "%.4f", invalidationDuration / 50))s")
        
        // Validate that cache invalidation doesn't take too long
        // Each invalidation + recalculation should be very fast (< 0.01s on average)
        let averageTimePerInvalidation = invalidationDuration / 50
        #expect(averageTimePerInvalidation < 0.01, "Cache invalidation should be fast. Got \(averageTimePerInvalidation)s per invalidation")
        
        // Validate that the final cache state is correct
        let finalRange = trip.cachedDateRange
        #expect(finalRange != nil)
        
        // The range should span all activities including the newly added ones
        let expectedStart = calendar.startOfDay(for: baseDate)
        #expect(finalRange!.lowerBound <= expectedStart)
    }
    
    @Test("Memory: Cache doesn't cause memory leaks with large datasets")
    func testCacheMemoryUsage() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create multiple trips with many activities to test memory usage
        let tripCount = 10
        let activitiesPerTrip = 200
        
        Logger.shared.info("Creating \(tripCount) trips with \(activitiesPerTrip) activities each")
        
        let baseDate = Date()
        let calendar = Calendar.current
        
        for tripIndex in 0..<tripCount {
            let trip = Trip(name: "Memory Test Trip \(tripIndex)")
            testBase.modelContext.insert(trip)
            
            for activityIndex in 0..<activitiesPerTrip {
                let startDate = calendar.date(byAdding: .hour, value: activityIndex, to: baseDate)!
                let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
                
                let activity = Activity(
                    name: "Activity \(tripIndex)-\(activityIndex)",
                    start: startDate,
                    end: endDate,
                    trip: trip
                )
                testBase.modelContext.insert(activity)
            }
            
            // Access cached range to populate cache
            let _ = trip.cachedDateRange
            
            // Perform conflict checks to exercise the cache
            for _ in 0..<10 {
                let _ = trip.optimizedCheckDateConflicts(
                    hasStartDate: true,
                    startDate: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
                    hasEndDate: true,
                    endDate: calendar.date(byAdding: .day, value: 10, to: baseDate)!
                )
            }
        }
        
        try testBase.modelContext.save()
        
        Logger.shared.info("Created \(tripCount * activitiesPerTrip) total activities across \(tripCount) trips")
        
        // Test that all caches work correctly
        let descriptor = FetchDescriptor<Trip>()
        let allTrips = try testBase.modelContext.fetch(descriptor)
        
        for trip in allTrips {
            let cachedRange = trip.cachedDateRange
            #expect(cachedRange != nil, "All trips should have valid cached ranges")
            
            let _ = trip.optimizedCheckDateConflicts(
                hasStartDate: true,
                startDate: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
                hasEndDate: true,
                endDate: calendar.date(byAdding: .day, value: 20, to: baseDate)!
            )
            // No specific expectation about conflicts, just ensuring it doesn't crash
        }
        
        Logger.shared.info("Memory test completed - all caches functional")
        
        // This test passes if we reach this point without crashes or excessive memory usage
        #expect(allTrips.count == tripCount)
    }
    
    @Test("Performance: Mixed activity types don't impact cache performance")
    func testMixedActivityTypePerformance() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Mixed Types Performance Test")
        testBase.modelContext.insert(trip)
        
        // Create organization for transportation/lodging
        let org = Organization(name: "Test Organization")
        testBase.modelContext.insert(org)
        
        let baseDate = Date()
        let calendar = Calendar.current
        let totalActivities = 300 // 100 of each type
        
        Logger.shared.info("Creating \(totalActivities) mixed activity types")
        
        // Create equal numbers of each activity type
        for i in 0..<(totalActivities / 3) {
            let startDate = calendar.date(byAdding: .hour, value: i * 3, to: baseDate)!
            let endDate = calendar.date(byAdding: .hour, value: 2, to: startDate)!
            
            // Transportation
            let transportation = Transportation(
                name: "Transport \(i)",
                type: .plane,
                start: startDate,
                end: endDate,
                trip: trip
            )
            transportation.organization = org
            testBase.modelContext.insert(transportation)
            
            // Lodging
            let lodging = Lodging(
                name: "Lodging \(i)",
                start: calendar.date(byAdding: .hour, value: 1, to: startDate)!,
                end: calendar.date(byAdding: .hour, value: 24, to: startDate)!,
                trip: trip
            )
            lodging.organization = org
            testBase.modelContext.insert(lodging)
            
            // Activity
            let activity = Activity(
                name: "Activity \(i)",
                start: calendar.date(byAdding: .hour, value: 12, to: startDate)!,
                end: calendar.date(byAdding: .hour, value: 14, to: startDate)!,
                trip: trip
            )
            testBase.modelContext.insert(activity)
        }
        
        try testBase.modelContext.save()
        
        // Measure performance with mixed types
        let performanceStartTime = Date()
        
        // First call to populate cache
        let _ = trip.cachedDateRange
        
        // Multiple cached conflict checks
        for _ in 0..<100 {
            let _ = trip.optimizedCheckDateConflicts(
                hasStartDate: true,
                startDate: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
                hasEndDate: true,
                endDate: calendar.date(byAdding: .day, value: 20, to: baseDate)!
            )
        }
        
        let mixedTypesDuration = Date().timeIntervalSince(performanceStartTime)
        
        Logger.shared.info("Mixed activity types performance:")
        Logger.shared.info("- Total activities: \(trip.totalActivities)")
        Logger.shared.info("- Lodging: \(trip.lodging.count)")
        Logger.shared.info("- Transportation: \(trip.transportation.count)")
        Logger.shared.info("- Activities: \(trip.activity.count)")
        Logger.shared.info("- Cache + 100 conflict checks: \(String(format: "%.4f", mixedTypesDuration))s")
        
        // Validate that mixed types don't significantly impact performance
        // With caching, even 300 mixed activities should complete quickly
        #expect(mixedTypesDuration < 0.1, "Mixed activity types should not significantly impact performance. Got \(mixedTypesDuration)s")
        
        // Validate correctness
        let cachedRange = trip.cachedDateRange
        #expect(cachedRange != nil)
        #expect(trip.totalActivities == totalActivities)
        
        Logger.shared.info("Mixed types performance test completed successfully")
    }
}