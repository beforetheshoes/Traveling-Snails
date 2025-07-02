//
//  DateConflictCachingTests.swift
//  Traveling Snails Tests
//
//  Tests for Issue #57: Performance: Cache date conflict results for large trips
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@MainActor
@Suite("Date Conflict Caching Tests")
struct DateConflictCachingTests {
    @Test("Empty trip returns nil cached date range")
    func testEmptyTripCacheReturnsNil() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Empty Trip")
        testBase.modelContext.insert(trip)

        // Empty trip should return nil for cached date range
        #expect(trip.cachedDateRange == nil)
    }

    @Test("Cache correctly stores and retrieves single activity date range")
    func testSingleActivityCaching() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)!

        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)

        // First access should calculate and cache
        let cachedRange = trip.cachedDateRange
        #expect(cachedRange != nil)

        // Verify the cached range matches activity dates (converted to start of day)
        let calendar = Calendar.current
        let expectedStart = calendar.startOfDay(for: startDate)
        let expectedEnd = calendar.startOfDay(for: endDate)

        #expect(cachedRange?.lowerBound == expectedStart)
        #expect(cachedRange?.upperBound == expectedEnd)
    }

    @Test("Cache correctly handles multiple activities spanning different dates")
    func testMultipleActivitiesCaching() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Multi-Activity Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Create activities spanning 10 days
        let earliestDate = calendar.date(byAdding: .day, value: -2, to: baseDate)!
        let latestDate = calendar.date(byAdding: .day, value: 8, to: baseDate)!

        // Add activities at different times
        let activities = [
            Activity(name: "Early Activity", start: earliestDate, end: baseDate, trip: trip),
            Activity(name: "Middle Activity", start: baseDate, end: calendar.date(byAdding: .day, value: 5, to: baseDate)!, trip: trip),
            Activity(name: "Late Activity", start: calendar.date(byAdding: .day, value: 6, to: baseDate)!, end: latestDate, trip: trip),
        ]

        for activity in activities {
            testBase.modelContext.insert(activity)
        }

        // Get cached range
        let cachedRange = trip.cachedDateRange
        #expect(cachedRange != nil)

        // Verify the range spans from earliest to latest (start of day)
        let expectedStart = calendar.startOfDay(for: earliestDate)
        let expectedEnd = calendar.startOfDay(for: latestDate)

        #expect(cachedRange?.lowerBound == expectedStart)
        #expect(cachedRange?.upperBound == expectedEnd)
    }

    @Test("Cache invalidates when activities are added")
    func testCacheInvalidationOnActivityAddition() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Add initial activity
        let initialActivity = Activity(
            name: "Initial Activity",
            start: baseDate,
            end: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
            trip: trip
        )
        testBase.modelContext.insert(initialActivity)

        // Get initial cached range
        let initialRange = trip.cachedDateRange
        #expect(initialRange != nil)
        let initialEndDate = initialRange!.upperBound

        // Add activity that extends the range
        let extendedDate = calendar.date(byAdding: .day, value: 5, to: baseDate)!
        let newActivity = Activity(
            name: "Extended Activity",
            start: calendar.date(byAdding: .day, value: 3, to: baseDate)!,
            end: extendedDate,
            trip: trip
        )
        testBase.modelContext.insert(newActivity)

        // Get new cached range (should be recalculated)
        let newRange = trip.cachedDateRange
        #expect(newRange != nil)

        // Verify the range has been extended
        let expectedNewEnd = calendar.startOfDay(for: extendedDate)
        #expect(newRange!.upperBound == expectedNewEnd)
        #expect(newRange!.upperBound > initialEndDate)
    }

    @Test("Cache invalidates when activities are removed")
    func testCacheInvalidationOnActivityRemoval() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Add multiple activities
        let activities = [
            Activity(name: "Activity 1", start: baseDate, end: calendar.date(byAdding: .day, value: 1, to: baseDate)!, trip: trip),
            Activity(name: "Activity 2", start: calendar.date(byAdding: .day, value: 2, to: baseDate)!, end: calendar.date(byAdding: .day, value: 5, to: baseDate)!, trip: trip),
        ]

        for activity in activities {
            testBase.modelContext.insert(activity)
        }

        // Get initial cached range
        let initialRange = trip.cachedDateRange
        #expect(initialRange != nil)

        // Remove the activity that extends the range
        testBase.modelContext.delete(activities[1])

        // Save context to ensure SwiftData relationships are updated
        try testBase.modelContext.save()

        // Get new cached range (should be recalculated)
        let newRange = trip.cachedDateRange
        #expect(newRange != nil)

        // Verify the range has been reduced
        let expectedNewEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: baseDate)!)
        #expect(newRange!.upperBound == expectedNewEnd)
        #expect(newRange!.upperBound < initialRange!.upperBound)
    }

    @Test("Cache handles transportation and lodging activities correctly")
    func testMixedActivityTypesCaching() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Mixed Activities Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Create organization for transportation and lodging
        let airline = Organization(name: "Test Airline")
        testBase.modelContext.insert(airline)

        // Add different types of activities
        let transportation = Transportation(
            name: "Flight",
            type: .plane,
            start: baseDate,
            end: calendar.date(byAdding: .hour, value: 3, to: baseDate)!,
            trip: trip
        )
        transportation.organization = airline
        testBase.modelContext.insert(transportation)

        let lodging = Lodging(
            name: "Hotel Stay",
            start: calendar.date(byAdding: .day, value: 1, to: baseDate)!,
            end: calendar.date(byAdding: .day, value: 4, to: baseDate)!,
            trip: trip
        )
        lodging.organization = airline
        testBase.modelContext.insert(lodging)

        let activity = Activity(
            name: "Tour",
            start: calendar.date(byAdding: .day, value: 2, to: baseDate)!,
            end: calendar.date(byAdding: .day, value: 2, to: baseDate)!,
            trip: trip
        )
        testBase.modelContext.insert(activity)

        // Get cached range
        let cachedRange = trip.cachedDateRange
        #expect(cachedRange != nil)

        // Verify the range spans all activity types
        let expectedStart = calendar.startOfDay(for: baseDate)
        let expectedEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 4, to: baseDate)!)

        #expect(cachedRange?.lowerBound == expectedStart)
        #expect(cachedRange?.upperBound == expectedEnd)
    }

    @Test("Optimized conflict checking returns correct conflicts")
    func testOptimizedConflictChecking() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Conflict Test Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Add activity from day 2 to day 5
        let activity = Activity(
            name: "Test Activity",
            start: calendar.date(byAdding: .day, value: 2, to: baseDate)!,
            end: calendar.date(byAdding: .day, value: 5, to: baseDate)!,
            trip: trip
        )
        testBase.modelContext.insert(activity)

        // Test case 1: Trip start date after activity start (should conflict)
        let conflictingStartDate = calendar.date(byAdding: .day, value: 3, to: baseDate)!
        let conflict1 = trip.optimizedCheckDateConflicts(
            hasStartDate: true,
            startDate: conflictingStartDate,
            hasEndDate: false,
            endDate: Date()
        )
        #expect(conflict1 != nil)
        #expect(conflict1!.contains("Trip start date"))
        #expect(conflict1!.contains("is after activities starting"))

        // Test case 2: Trip end date before activity end (should conflict)
        let conflictingEndDate = calendar.date(byAdding: .day, value: 4, to: baseDate)!
        let conflict2 = trip.optimizedCheckDateConflicts(
            hasStartDate: false,
            startDate: Date(),
            hasEndDate: true,
            endDate: conflictingEndDate
        )
        #expect(conflict2 != nil)
        #expect(conflict2!.contains("Trip end date"))
        #expect(conflict2!.contains("is before activities ending"))

        // Test case 3: Valid trip dates (should not conflict)
        let validStartDate = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        let validEndDate = calendar.date(byAdding: .day, value: 6, to: baseDate)!
        let noConflict = trip.optimizedCheckDateConflicts(
            hasStartDate: true,
            startDate: validStartDate,
            hasEndDate: true,
            endDate: validEndDate
        )
        #expect(noConflict == nil)
    }

    @Test("Cache persists correctly across multiple accesses")
    func testCachePersistence() async throws {
        let testBase = SwiftDataTestBase()
        let trip = Trip(name: "Persistence Test Trip")
        testBase.modelContext.insert(trip)

        let baseDate = Date()
        let calendar = Calendar.current

        // Add activity
        let activity = Activity(
            name: "Persistent Activity",
            start: baseDate,
            end: calendar.date(byAdding: .day, value: 3, to: baseDate)!,
            trip: trip
        )
        testBase.modelContext.insert(activity)

        // First access - should calculate and cache
        let range1 = trip.cachedDateRange
        #expect(range1 != nil)

        // Second access - should use cache
        let range2 = trip.cachedDateRange
        #expect(range2 != nil)

        // Verify both accesses return identical results
        #expect(range1!.lowerBound == range2!.lowerBound)
        #expect(range1!.upperBound == range2!.upperBound)

        // Multiple optimized conflict checks should use cache
        let conflict1 = trip.optimizedCheckDateConflicts(
            hasStartDate: true,
            startDate: calendar.date(byAdding: .day, value: 5, to: baseDate)!,
            hasEndDate: false,
            endDate: Date()
        )

        let conflict2 = trip.optimizedCheckDateConflicts(
            hasStartDate: true,
            startDate: calendar.date(byAdding: .day, value: 5, to: baseDate)!,
            hasEndDate: false,
            endDate: Date()
        )

        // Both should return the same result
        #expect(conflict1 == conflict2)
        #expect(conflict1 != nil) // Should detect conflict
    }
}
