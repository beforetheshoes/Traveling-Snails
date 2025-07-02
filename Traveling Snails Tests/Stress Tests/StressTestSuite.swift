//
//  StressTestSuite.swift
//  Traveling Snails Tests
//
//

import Darwin
import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

/// Stress tests using the advanced testing framework
@Suite("Stress Tests")
@MainActor
struct StressTestSuite {
    @Test("Concurrent trip creation stress test")
    func testConcurrentTripCreation() async throws {
        let results = try await StressTestFramework.stressTestSwiftData(
            name: "Concurrent Trip Creation",
            concurrentOperations: 5,
            operationsPerTask: 20
        ) { modelContext, operationId in
            let trip = Trip(
                name: "Stress Test Trip \(operationId)",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: operationId % 3 == 0 // Every third trip is protected
            )
            modelContext.insert(trip)
            try modelContext.save()
        }

        // Verify stress test results
        #expect(results.successRate >= 0.95) // At least 95% success rate
        #expect(results.totalErrors <= 5) // No more than 5 errors total
        #expect(results.operationsPerSecond > 10) // At least 10 operations per second
        #expect(results.totalDuration < 20.0) // Complete within 20 seconds

        Logger.shared.info("Stress test results: \(results.successfulOperations)/\(results.totalOperations) operations succeeded", category: .debug)
    }

    @Test("Concurrent relationship creation stress test")
    func testConcurrentRelationshipCreation() async throws {
        let results = try await StressTestFramework.stressTestSwiftData(
            name: "Concurrent Relationship Creation",
            concurrentOperations: 4,
            operationsPerTask: 10
        ) { modelContext, operationId in
            // Create a trip and activity for each operation to avoid concurrency conflicts
            let trip = Trip(
                name: "Stress Test Trip \(operationId)",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: false
            )
            modelContext.insert(trip)

            let activity = Activity()
            activity.name = "Stress Test Activity \(operationId)"
            activity.start = Calendar.current.date(byAdding: .hour, value: operationId, to: Date()) ?? Date()
            activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
            activity.notes = "Created by stress test operation \(operationId)"
            activity.trip = trip
            modelContext.insert(activity)
            try modelContext.save()
        }

        #expect(results.successRate >= 0.70) // At least 70% success rate for relationship operations
        #expect(results.totalErrors <= 12) // Allow some errors for concurrent operations
        #expect(results.operationsPerSecond > 1) // At least 1 operation per second

        Logger.shared.info("Relationship stress test completed: \(results.successRate * 100)% success rate", category: .debug)
    }

    @Test("High-frequency sync operations stress test")
    func testHighFrequencySyncStress() async throws {
        let container = TestServiceContainer.create { mocks in
            mocks.sync.configureSuccessfulSync()
        }

        let syncService = container.resolve(SyncService.self)

        // Test rapid sync operations
        let startTime = CFAbsoluteTimeGetCurrent()
        var successfulSyncs = 0

        // Run 50 sync operations as fast as possible
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    await syncService.triggerSyncAndWait()
                    await MainActor.run {
                        successfulSyncs += 1
                    }
                }
            }

            for try await _ in group {
                // Wait for all tasks to complete
            }
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        let successRate = Double(successfulSyncs) / 50.0

        #expect(successRate >= 0.95) // At least 95% success rate
        #expect(totalDuration < 30.0) // Complete within 30 seconds

        Logger.shared.info("High-frequency sync stress test: \(successfulSyncs)/50 syncs succeeded in \(String(format: "%.2f", totalDuration))s", category: .debug)
    }

    @Test("Memory pressure during concurrent operations")
    func testMemoryPressureStress() async throws {
        let initialMemory = getMemoryUsage()

        let results = try await StressTestFramework.stressTestSwiftData(
            name: "Memory Pressure Stress Test",
            concurrentOperations: 10,
            operationsPerTask: 30
        ) { modelContext, operationId in
            // Create multiple objects per operation
            let trip = Trip(
                name: "Memory Stress Trip \(operationId)",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: false
            )
            modelContext.insert(trip)

            // Add multiple activities per trip
            for j in 0..<5 {
                let activity = Activity()
                activity.name = "Activity \(j) for Operation \(operationId)"
                activity.start = Date()
                activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
                activity.notes = "Memory stress test activity with longer notes to increase memory usage"
                activity.trip = trip
                modelContext.insert(activity)
            }

            try modelContext.save()
        }

        let finalMemory = getMemoryUsage()
        let memoryDelta = Int64(finalMemory) - Int64(initialMemory)

        #expect(results.successRate >= 0.85) // At least 85% success under memory pressure
        #expect(memoryDelta < 150) // Memory increase should be under 150MB (allow for system variability)

        Logger.shared.info("Memory pressure test: Memory delta = \(memoryDelta)MB", category: .debug)
    }

    @Test("Service container resolution under load")
    func testServiceContainerStress() async throws {
        let container = TestServiceContainer.create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.sync.configureSuccessfulSync()
            mocks.cloud.configureAvailable()
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var successfulResolutions = 0

        // Stress test service resolution with concurrent access
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    // Rapid service resolution
                    for _ in 0..<10 {
                        _ = container.resolve(AuthenticationService.self)
                        _ = container.resolve(SyncService.self)
                        _ = container.resolve(CloudStorageService.self)
                    }
                    await MainActor.run {
                        successfulResolutions += 1
                    }
                }
            }

            for try await _ in group {
                // Wait for all tasks to complete
            }
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
        let successRate = Double(successfulResolutions) / 100.0

        #expect(successRate >= 0.98) // Service resolution should be highly reliable
        #expect(totalDuration < 10.0) // Service resolution should be very fast

        Logger.shared.info("Service container stress test: \(successfulResolutions)/100 batches succeeded", category: .debug)
    }

    @Test("Complex workflow stress test")
    func testComplexWorkflowStress() async throws {
        let results = try await StressTestFramework.stressTestSwiftData(
            name: "Complex Workflow Stress Test",
            concurrentOperations: 6,
            operationsPerTask: 10
        ) { modelContext, operationId in
            // Complex workflow: Create trip, add activities, modify, save
            let trip = Trip(
                name: "Complex Workflow Trip \(operationId)",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                isProtected: operationId % 2 == 0
            )
            modelContext.insert(trip)

            // Add multiple activities
            for i in 0..<3 {
                let activity = Activity()
                activity.name = "Workflow Activity \(i) for Op \(operationId)"
                activity.start = Calendar.current.date(byAdding: .day, value: i, to: Date()) ?? Date()
                activity.end = Calendar.current.date(byAdding: .hour, value: 2, to: activity.start) ?? activity.start
                activity.notes = "Complex workflow test"
                activity.trip = trip
                modelContext.insert(activity)
            }

            // Save initial state
            try modelContext.save()

            // Modify data
            trip.name = "Modified \(trip.name)"
            if let firstActivity = trip.activity.first {
                firstActivity.notes = "Modified notes"
            }

            // Save modifications
            try modelContext.save()

            // Query to verify
            let descriptor = FetchDescriptor<Trip>(
                predicate: #Predicate { $0.name.contains("Complex Workflow") }
            )
            let trips = try modelContext.fetch(descriptor)

            if trips.isEmpty {
                throw TestError.verificationFailed("Trip not found after complex workflow")
            }
        }

        #expect(results.successRate >= 0.90) // Complex workflows should be reliable
        #expect(results.totalErrors <= 6) // Some errors acceptable for complex operations
        #expect(results.operationsPerSecond > 2) // At least 2 complex operations per second

        Logger.shared.info("Complex workflow stress test completed: \(results.successRate * 100)% success rate", category: .debug)
    }

    // MARK: - Helper Functions

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size / 1024 / 1024 // Convert to MB
        } else {
            return 0
        }
    }
}

// MARK: - Test Error Types

enum TestError: Error {
    case setupFailed(String)
    case verificationFailed(String)
    case operationFailed(String)
}
