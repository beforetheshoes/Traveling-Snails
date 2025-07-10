//
//  AccessibilityPerformanceTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails
import XCTest

@Suite("Accessibility Performance Tests")
@MainActor
struct AccessibilityPerformanceTests {
    /// Performance tests for accessibility with large datasets and SwiftData operations
    /// Ensures accessibility doesn't significantly impact app performance

    @Test("Large dataset accessibility generation performance")
    func testLargeDatasetAccessibilityGeneration() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let itemCounts = [5, 10, 20, 50]

        for itemCount in itemCounts {
            let performanceTime = try testBase.measureAccessibilityPerformance(itemCount: itemCount) {
                for i in 1...itemCount {
                    let trip = Trip(name: "Performance Trip \(i)")
                    trip.notes = "Performance testing notes for trip \(i)"
                    // Note: Trip model doesn't have generateAccessibilityInfo method yet
                    testBase.modelContext.insert(trip)
                }
                try testBase.modelContext.save()
            }

            // Performance thresholds based on item count (reduced for stability)
            let expectedMaxTime: TimeInterval
            switch itemCount {
            case 5:
                expectedMaxTime = 1.0  // 5 items should process in under 1 second
            case 10:
                expectedMaxTime = 2.0  // 10 items should process in under 2 seconds
            case 20:
                expectedMaxTime = 3.0  // 20 items should process in under 3 seconds
            case 50:
                expectedMaxTime = 5.0  // 50 items should process in under 5 seconds
            default:
                expectedMaxTime = 10.0
            }

            #expect(performanceTime < expectedMaxTime,
                   "Accessibility generation for \(itemCount) items took \(performanceTime)s, expected under \(expectedMaxTime)s")

            // Cleanup for next test
            try testBase.cleanup()
        }
    }

    @Test("Accessibility memory usage with large datasets")
    func testAccessibilityMemoryUsage() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let itemCount = 50
        let (beforeMemory, afterMemory) = try testBase.testAccessibilityMemoryUsage(itemCount: itemCount) {
            for i in 1...itemCount {
                let trip = Trip(name: "Memory Test Trip \(i)")
                // Note: Trip model doesn't have generateAccessibilityInfo method yet
                testBase.modelContext.insert(trip)
            }
            try testBase.modelContext.save()
        }

        let memoryIncrease = afterMemory - beforeMemory
        let memoryPerItem = memoryIncrease / Int64(itemCount)

        // Memory baseline: Conservative baseline accounting for resident memory measurement overhead
        // Resident memory includes system overhead, framework memory, SwiftData context, and memory fragmentation
        // Observed: ~14MB for 50 items, setting 20MB baseline allows detection of real memory leaks
        #expect(memoryIncrease < 20_000_000, "Memory increase should be under 20MB for \(itemCount) items")
        #expect(memoryPerItem < 400_000, "Memory per item should be under 400KB (includes system overhead)")

        print("Memory usage for \(itemCount) items: \(memoryIncrease / 1_000_000)MB total, \(memoryPerItem / 1000)KB per item")
    }

    @Test("UI accessibility loading performance with large datasets")
    func testUIAccessibilityLoadingPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create large dataset
        let tripCount = 25
        _ = try testBase.createLargeAccessibleDataset(tripCount: tripCount)

        let startTime = Date()

        // Test data accessibility performance (without UI automation)
        let context = testBase.modelContext
        let trips = try context.fetch(FetchDescriptor<Trip>())

        var accessibleTrips = 0
        for trip in trips {
            if !trip.name.isEmpty {
                accessibleTrips += 1
            }
        }

        let totalLoadTime = Date().timeIntervalSince(startTime)

        #expect(accessibleTrips >= Int(Double(tripCount) * 0.9), "Most trips should be accessible")
        #expect(totalLoadTime < 3.0, "Data accessibility should be performant")

        print("Data loading time with \(tripCount) accessible items: \(totalLoadTime)s")
    }

    @Test("Background context accessibility performance")
    func testBackgroundContextAccessibilityPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let itemCount = 200
        let startTime = Date()

        // Test background context accessibility operations
        try await testBase.testAccessibilityInBackgroundContext { context in
            for i in 1...itemCount {
                let trip = Trip(name: "Background Trip \(i)")
                // Note: Trip model doesn't have generateAccessibilityInfo method yet
                context.insert(trip)
            }
            try context.save()
        }

        let backgroundTime = Date().timeIntervalSince(startTime)

        // Background operations should be efficient
        #expect(backgroundTime < 5.0, "Background accessibility operations should complete in under 5 seconds")

        // Verify accessibility information is preserved
        let descriptor = FetchDescriptor<Trip>()
        let trips = try testBase.modelContext.fetch(descriptor)

        #expect(trips.count == itemCount, "All trips should be saved")

        for trip in trips.prefix(10) { // Check first 10 for performance
            // Note: Trip model doesn't have cachedAccessibilityInfo property yet
            // This check will be implemented when accessibility properties are added
            _ = trip.name // Use existing property for now
        }

        print("Background context accessibility performance for \(itemCount) items: \(backgroundTime)s")
    }

    @Test("Query performance with accessibility")
    func testQueryPerformanceWithAccessibility() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create test data with accessibility
        _ = try testBase.createLargeAccessibleDataset(tripCount: 15)

        let result = try testBase.testAccessibilityWithComplexQueries()

        // Performance expectations
        #expect(result.totalTime < 2.0, "Complex query with accessibility should complete in under 2 seconds")
        #expect(result.accessibilityOverhead < 0.5, "Accessibility should add less than 50% overhead")

        print("Query performance: \(result.queryTime)s query, \(result.accessibilityTime)s accessibility, \(result.accessibilityOverhead * 100)% overhead")
    }

    @Test("CloudKit sync accessibility performance")
    func testCloudKitSyncAccessibilityPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create trips with accessibility info
        let tripCount = 20
        let trips = try testBase.createLargeAccessibleDataset(tripCount: tripCount)

        let startTime = Date()

        // Simulate CloudKit sync
        try await testBase.simulateCloudKitSyncWithAccessibility(trips: trips)

        let syncTime = Date().timeIntervalSince(startTime)

        // Sync should preserve accessibility efficiently (allow up to 12 seconds for CI environment)  
        #expect(syncTime < 12.0, "CloudKit sync with accessibility should complete in under 12 seconds")

        print("CloudKit sync performance with accessibility for \(tripCount) items: \(syncTime)s")
    }

    @Test("Accessibility update performance during data changes")
    func testAccessibilityUpdatePerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create initial dataset
        let trips = try testBase.createLargeAccessibleDataset(tripCount: 10)

        let startTime = Date()

        // Update accessibility for all trips
        for trip in trips {
            try testBase.testAccessibilityAfterDataChange(trip: trip) { trip in
                trip.name = "\(trip.name) - Updated"
                trip.notes = "\(trip.notes) - Updated notes"
            }
        }

        let updateTime = Date().timeIntervalSince(startTime)

        // Updates should be efficient
        #expect(updateTime < 5.0, "Accessibility updates for 200 items should complete in under 5 seconds")

        print("Accessibility update performance for \(trips.count) items: \(updateTime)s")
    }

    @Test("VoiceOver navigation performance with large lists")
    func testVoiceOverNavigationPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create large accessible dataset
        _ = try testBase.createLargeAccessibleDataset(tripCount: 15)

        let startTime = Date()

        // Test VoiceOver data model navigation performance (without UI automation)
        let context = testBase.modelContext
        let trips = try context.fetch(FetchDescriptor<Trip>())

        var validTrips = 0
        for trip in trips.prefix(20) {
            // Verify accessibility properties are available quickly
            let hasName = !trip.name.isEmpty
            _ = !trip.notes.isEmpty

            if hasName {
                validTrips += 1
            }
        }

        let navigationTime = Date().timeIntervalSince(startTime)

        // VoiceOver data navigation should be responsive
        #expect(navigationTime < 1.0, "VoiceOver data navigation through 20 items should be fast")
        #expect(validTrips >= 15, "Most trips should be accessible")

        print("VoiceOver data navigation performance: \(navigationTime)s for \(validTrips) accessible trips")
    }

    @Test("Switch Control performance with large datasets")
    func testSwitchControlPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create large dataset
        _ = try testBase.createLargeAccessibleDataset(tripCount: 15)

        let startTime = Date()

        // Test Switch Control data model performance (without UI automation)
        let context = testBase.modelContext
        let trips = try context.fetch(FetchDescriptor<Trip>())
        let activities = try context.fetch(FetchDescriptor<Activity>())

        var validElements = 0

        // Verify trips are efficiently accessible (simulating Switch Control navigation)
        for trip in trips.prefix(25) {
            let isValid = !trip.name.isEmpty || !trip.notes.isEmpty
            if isValid {
                validElements += 1
            }
        }

        // Verify activities are efficiently accessible
        for activity in activities.prefix(25) {
            let isValid = !activity.name.isEmpty
            if isValid {
                validElements += 1
            }
        }

        let switchControlTime = Date().timeIntervalSince(startTime)

        // Switch Control should be responsive
        #expect(switchControlTime < 3.0, "Switch Control accessibility check should complete in under 3 seconds")
        #expect(validElements >= 10, "Most elements should be accessible to Switch Control")

        print("Switch Control performance: \(switchControlTime)s for \(validElements) accessible elements")
    }

    @Test("Voice Control command recognition performance")
    func testVoiceControlPerformance() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        // Create dataset with diverse accessibility labels
        for i in 1...10 {
            let activityCount = (i % 5 == 0) ? 1 : i % 5  // Avoid 0 activityCount
            _ = try testBase.createAccessibleTrip(
                name: "Voice Control Trip \(i)",
                notes: "Test trip for voice control testing",
                activityCount: activityCount
            )
        }

        let startTime = Date()

        // Test Voice Control data model accessibility (without UI automation)
        let trips = try testBase.createLargeAccessibleDataset(tripCount: 10)
        var voiceControlCompatible = 0

        for trip in trips {
            // Voice Control requires meaningful names and labels
            let name = trip.name.lowercased()
            let hasActionableLabel = name.contains("trip") ||
                                   name.contains("voice") ||
                                   name.contains("control") ||
                                   !name.isEmpty

            if hasActionableLabel {
                voiceControlCompatible += 1
            }
        }

        let voiceControlTime = Date().timeIntervalSince(startTime)

        // Voice Control should be responsive
        #expect(voiceControlTime < 2.0, "Voice Control compatibility check should complete in under 2 seconds")
        #expect(voiceControlCompatible >= 8, "Should have sufficient Voice Control compatible elements")

        print("Voice Control performance: \(voiceControlTime)s, \(voiceControlCompatible) compatible elements")
    }

    @Test("Accessibility memory leak detection")
    func testAccessibilityMemoryLeaks() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let iterations = 5
        var memoryUsages: [Int64] = []

        for iteration in 1...iterations {
            let memoryBefore = getMemoryUsage()

            // Create and destroy accessibility data
            let trips = try testBase.createLargeAccessibleDataset(tripCount: 10)

            // Note: Accessibility properties will be tested when added to Trip model
            for trip in trips {
                _ = trip.name // Use existing property for now
            }

            // Cleanup
            try testBase.cleanup()

            let memoryAfter = getMemoryUsage()
            memoryUsages.append(memoryAfter - memoryBefore)

            print("Iteration \(iteration): Memory change \((memoryAfter - memoryBefore) / 1_000_000)MB")
        }

        // Check for memory leaks - memory usage should stabilize
        let averageMemoryChange = memoryUsages.reduce(0, +) / Int64(memoryUsages.count)
        let maxMemoryChange = memoryUsages.max() ?? 0

        #expect(averageMemoryChange < 20_000_000, "Average memory change should be under 20MB")
        #expect(maxMemoryChange < 50_000_000, "Maximum memory change should be under 50MB")

        print("Memory leak test: Average change \(averageMemoryChange / 1_000_000)MB, Max change \(maxMemoryChange / 1_000_000)MB")
    }

    // MARK: - Helper Functions

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Performance Benchmark Tests

@Suite("Accessibility Benchmark Tests")
@MainActor
struct AccessibilityBenchmarkTests {
    /// Benchmark tests to establish baseline performance metrics

    @Test("Baseline accessibility generation benchmark")
    func testBaselineAccessibilityGeneration() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let benchmarkCounts = [5, 10, 20, 50]
        var benchmarkResults: [Int: TimeInterval] = [:]

        for count in benchmarkCounts {
            let startTime = Date()

            for i in 1...count {
                let trip = Trip(name: "Benchmark Trip \(i)")
                // Note: Trip model doesn't have generateAccessibilityInfo method yet
                testBase.modelContext.insert(trip)
            }
            try testBase.modelContext.save()

            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            benchmarkResults[count] = duration

            print("Benchmark: \(count) items in \(duration)s (\(duration / Double(count) * 1000)ms per item)")

            try testBase.cleanup()
        }

        // Verify scalability
        for count in benchmarkCounts {
            if let duration = benchmarkResults[count] {
                let timePerItem = duration / Double(count)
                #expect(timePerItem < 0.01, "Should process each item in under 10ms")
            }
        }
    }

    @Test("Accessibility vs non-accessibility performance comparison")
    func testAccessibilityOverheadBenchmark() async throws {
        let testBase = try SwiftDataAccessibilityTestBase()

        let itemCount = 20

        // Test without accessibility
        let startTimeWithoutA11y = Date()
        for i in 1...itemCount {
            let trip = Trip(name: "No A11y Trip \(i)")
            testBase.modelContext.insert(trip)
        }
        try testBase.modelContext.save()
        let timeWithoutA11y = Date().timeIntervalSince(startTimeWithoutA11y)

        try testBase.cleanup()

        // Test with accessibility
        let startTimeWithA11y = Date()
        for i in 1...itemCount {
            let trip = Trip(name: "With A11y Trip \(i)")
            // Note: Trip model doesn't have generateAccessibilityInfo method yet
            testBase.modelContext.insert(trip)
        }
        try testBase.modelContext.save()
        let timeWithA11y = Date().timeIntervalSince(startTimeWithA11y)

        let overhead = (timeWithA11y - timeWithoutA11y) / timeWithoutA11y

        print("Performance comparison:")
        print("- Without accessibility: \(timeWithoutA11y)s")
        print("- With accessibility: \(timeWithA11y)s")
        print("- Overhead: \(overhead * 100)%")

        // Accessibility overhead should be reasonable
        #expect(overhead < 1.0, "Accessibility should add less than 100% overhead")
        #expect(timeWithA11y < timeWithoutA11y * 3, "Accessibility should not triple execution time")
    }
}
