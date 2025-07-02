//
//  DateConflictPerformanceValidation.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

/// Performance validation tests to verify cache effectiveness for date conflict checking
@Suite("Date Conflict Performance Validation")
@MainActor
struct DateConflictPerformanceValidation {
    
    @Test("Cache provides significant performance improvement for repeated access")
    func testCachePerformanceImprovement() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create a trip with a moderate number of activities
        let trip = Trip(
            name: "Performance Validation Trip",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add 100 activities to create meaningful computation load
        for i in 0..<100 {
            let activity = Activity()
            activity.name = "Performance Activity \(i)"
            activity.start = Calendar.current.date(byAdding: .hour, value: i, to: Date()) ?? Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.trip = trip
            testBase.modelContext.insert(activity)
        }
        
        try testBase.modelContext.save()
        
        // Measure first access (should populate cache)
        let firstAccessStart = CFAbsoluteTimeGetCurrent()
        let firstResult = trip.cachedDateRange
        let firstAccessTime = CFAbsoluteTimeGetCurrent() - firstAccessStart
        
        #expect(firstResult != nil)
        #expect(trip.isCacheValid)
        
        // Measure second access (should use cache)
        let secondAccessStart = CFAbsoluteTimeGetCurrent()
        let secondResult = trip.cachedDateRange
        let secondAccessTime = CFAbsoluteTimeGetCurrent() - secondAccessStart
        
        #expect(secondResult != nil)
        #expect(firstResult == secondResult) // Should be identical
        #expect(trip.isCacheValid) // Cache should still be valid
        
        // Second access should be significantly faster (at least 5x)
        #expect(secondAccessTime < firstAccessTime / 5)
        
        Logger.shared.info("Cache Performance Test - First: \(String(format: "%.6f", firstAccessTime))s, Second: \(String(format: "%.6f", secondAccessTime))s, Improvement: \(String(format: "%.1f", firstAccessTime / secondAccessTime))x", category: .debug)
    }
    
    @Test("Cache invalidation works correctly and recalculates when needed")
    func testCacheInvalidationAndRecalculation() async throws {
        let testBase = SwiftDataTestBase()
        
        let trip = Trip(
            name: "Cache Invalidation Test",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add initial activity
        let activity1 = Activity()
        activity1.name = "Initial Activity"
        activity1.start = Date()
        activity1.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity1.start) ?? activity1.start
        activity1.trip = trip
        testBase.modelContext.insert(activity1)
        
        try testBase.modelContext.save()
        
        // Get initial cached result
        let initialRange = trip.cachedDateRange
        #expect(initialRange != nil)
        #expect(trip.isCacheValid)
        
        // Add new activity that changes the date range
        let activity2 = Activity()
        activity2.name = "Extended Activity"
        activity2.start = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
        activity2.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity2.start) ?? activity2.start
        activity2.trip = trip
        testBase.modelContext.insert(activity2)
        
        try testBase.modelContext.save()
        
        // Cache should be invalidated (different activity fingerprint)
        #expect(!trip.isCacheValid)
        
        // New access should recalculate and return different result
        let newRange = trip.cachedDateRange
        #expect(newRange != nil)
        #expect(newRange != initialRange) // Should be different due to new activity
        #expect(trip.isCacheValid) // Should be valid again after recalculation
    }
    
    @Test("Optimized checkDateConflicts uses caching and is performant")
    func testOptimizedCheckDateConflictsPerformance() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create trip with dates that will conflict with activities
        let tripStart = Date()
        let tripEnd = Calendar.current.date(byAdding: .day, value: 5, to: tripStart) ?? tripStart
        
        let trip = Trip(
            name: "Conflict Performance Test",
            startDate: tripStart,
            endDate: tripEnd,
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add activities that extend beyond trip dates
        for i in 0..<50 {
            let activity = Activity()
            activity.name = "Conflict Activity \(i)"
            activity.start = Calendar.current.date(byAdding: .day, value: i + 10, to: Date()) ?? Date() // Beyond trip end
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.trip = trip
            testBase.modelContext.insert(activity)
        }
        
        try testBase.modelContext.save()
        
        // Measure performance of optimized conflict checking
        let metrics = try await PerformanceTestFramework.measureSwiftDataOperation(
            name: "Optimized Date Conflict Check",
            iterations: 50,
            operation: { _ in
                let result = trip.optimizedCheckDateConflicts()
                #expect(result != nil) // Should detect conflicts
            },
            baseline: 0.001 // Should be very fast with caching
        )
        
        // Should be consistently fast
        #expect(metrics.averageDuration < 0.002)
        #expect(metrics.maxDuration < 0.005)
        
        Logger.shared.info("Optimized conflict checking performance: avg \(String(format: "%.6f", metrics.averageDuration))s, max \(String(format: "%.6f", metrics.maxDuration))s", category: .debug)
    }
    
    @Test("Cache memory usage is reasonable for large datasets")
    func testCacheMemoryUsage() async throws {
        let metrics = try await PerformanceTestFramework.measureMemoryUsage(
            name: "Date Conflict Cache Memory Usage"
        ) {
            let testBase = SwiftDataTestBase()
            
            // Create multiple trips with caching to test memory usage
            for i in 0..<50 {
                let trip = Trip(
                    name: "Memory Test Trip \(i)",
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    isProtected: false
                )
                testBase.modelContext.insert(trip)
                
                // Add activities to each trip
                for j in 0..<30 {
                    let activity = Activity()
                    activity.name = "Activity \(j)"
                    activity.start = Calendar.current.date(byAdding: .hour, value: j, to: Date()) ?? Date()
                    activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
                    activity.trip = trip
                    testBase.modelContext.insert(activity)
                }
                
                try testBase.modelContext.save()
                
                // Access cached date range to populate cache
                _ = trip.cachedDateRange
                #expect(trip.isCacheValid)
            }
        }
        
        // Memory usage should be reasonable (under 20MB for 50 trips with cache)
        #expect(metrics.memoryDelta < 20)
        
        Logger.shared.info("Cache memory usage: \(metrics.memoryDelta)MB for 50 trips with 30 activities each", category: .debug)
    }
    
    @Test("Cache correctness verified against manual calculation")
    func testCacheCorrectness() async throws {
        let testBase = SwiftDataTestBase()
        
        let baseDate = Date()
        let calendar = Calendar.current
        
        let trip = Trip(
            name: "Correctness Test Trip",
            startDate: baseDate,
            endDate: calendar.date(byAdding: .day, value: 7, to: baseDate) ?? baseDate,
            isProtected: false
        )
        testBase.modelContext.insert(trip)
        
        // Add activities with known, specific dates
        let activity1Start = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        let activity1End = calendar.date(byAdding: .hour, value: 2, to: activity1Start) ?? activity1Start
        
        let activity1 = Activity()
        activity1.name = "Test Activity 1"
        activity1.start = activity1Start
        activity1.end = activity1End
        activity1.trip = trip
        testBase.modelContext.insert(activity1)
        
        let activity2Start = calendar.date(byAdding: .day, value: 5, to: baseDate) ?? baseDate
        let activity2End = calendar.date(byAdding: .hour, value: 3, to: activity2Start) ?? activity2Start
        
        let activity2 = Activity()
        activity2.name = "Test Activity 2"
        activity2.start = activity2Start
        activity2.end = activity2End
        activity2.trip = trip
        testBase.modelContext.insert(activity2)
        
        try testBase.modelContext.save()
        
        // Calculate expected range manually (matching the cache implementation)
        let expectedStart = calendar.startOfDay(for: activity1Start)
        let expectedEnd = calendar.startOfDay(for: activity2End)
        let expectedRange = expectedStart...expectedEnd
        
        // Get cached result
        let cachedRange = trip.cachedDateRange
        
        #expect(cachedRange != nil)
        #expect(cachedRange?.lowerBound == expectedRange.lowerBound)
        #expect(cachedRange?.upperBound == expectedRange.upperBound)
        
        Logger.shared.info("Cache correctness verified - Expected: \(expectedRange), Cached: \(cachedRange?.description ?? "nil")", category: .debug)
    }
}