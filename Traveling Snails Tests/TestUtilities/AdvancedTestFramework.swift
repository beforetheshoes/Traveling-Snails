//
//  AdvancedTestFramework.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

// MARK: - Performance Testing Framework

/// Performance testing utilities for measuring and validating performance characteristics
@MainActor
final class PerformanceTestFramework {
    /// Test performance of a SwiftData operation
    /// - Parameters:
    ///   - name: Test name for reporting
    ///   - iterations: Number of iterations to run
    ///   - operation: The operation to measure
    ///   - baseline: Expected baseline duration in seconds
    /// - Returns: Performance metrics
    static func measureSwiftDataOperation(
        name: String,
        iterations: Int = 100,
        operation: @escaping (ModelContext) async throws -> Void,
        baseline: TimeInterval? = nil
    ) async throws -> PerformanceMetrics {
        let testBase = SwiftDataTestBase()
        var durations: [TimeInterval] = []

        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            try await operation(testBase.modelContext)
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            durations.append(duration)
        }

        let metrics = PerformanceMetrics(
            testName: name,
            iterations: iterations,
            durations: durations,
            baseline: baseline
        )

        // Log performance results
        Logger.shared.info("Performance Test: \(name)", category: .debug)
        Logger.shared.info("  Avg: \(String(format: "%.3f", metrics.averageDuration))ms", category: .debug)
        Logger.shared.info("  Min: \(String(format: "%.3f", metrics.minDuration))ms", category: .debug)
        Logger.shared.info("  Max: \(String(format: "%.3f", metrics.maxDuration))ms", category: .debug)

        return metrics
    }

    /// Test memory usage of an operation
    /// - Parameters:
    ///   - name: Test name for reporting
    ///   - operation: The operation to measure
    /// - Returns: Memory usage before and after operation
    static func measureMemoryUsage(
        name: String,
        operation: @escaping () async throws -> Void
    ) async throws -> MemoryMetrics {
        let initialMemory = getMemoryUsage()
        try await operation()
        let finalMemory = getMemoryUsage()

        let metrics = MemoryMetrics(
            testName: name,
            initialMemory: initialMemory,
            finalMemory: finalMemory
        )

        Logger.shared.info("Memory Test: \(name)", category: .debug)
        Logger.shared.info("  Initial: \(metrics.initialMemory)MB", category: .debug)
        Logger.shared.info("  Final: \(metrics.finalMemory)MB", category: .debug)
        Logger.shared.info("  Delta: \(metrics.memoryDelta)MB", category: .debug)

        return metrics
    }

    private static func getMemoryUsage() -> UInt64 {
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

// MARK: - Stress Testing Framework

/// Stress testing utilities for testing system behavior under load
@MainActor
final class StressTestFramework {
    /// Stress test SwiftData with concurrent operations
    /// - Parameters:
    ///   - name: Test name for reporting
    ///   - concurrentOperations: Number of concurrent operations
    ///   - operationsPerTask: Number of operations per concurrent task
    ///   - operation: The operation to stress test
    /// - Returns: Stress test results
    static func stressTestSwiftData(
        name: String,
        concurrentOperations: Int = 10,
        operationsPerTask: Int = 50,
        operation: @escaping @MainActor (ModelContext, Int) async throws -> Void
    ) async throws -> StressTestResults {
        let testBase = SwiftDataTestBase()
        var results: [StressTaskResult] = []

        Logger.shared.info("Starting stress test: \(name)", category: .debug)
        Logger.shared.info("  Concurrent tasks: \(concurrentOperations)", category: .debug)
        Logger.shared.info("  Operations per task: \(operationsPerTask)", category: .debug)

        let startTime = CFAbsoluteTimeGetCurrent()

        try await withThrowingTaskGroup(of: StressTaskResult.self) { group in
            for taskId in 0..<concurrentOperations {
                group.addTask {
                    let taskStartTime = CFAbsoluteTimeGetCurrent()
                    var successfulOperations = 0
                    var errors: [Error] = []

                    for operationId in 0..<operationsPerTask {
                        do {
                            // Create fresh ModelContext for each task to avoid concurrency issues
                            let taskModelContext = ModelContext(testBase.modelContainer)
                            try await operation(taskModelContext, taskId * operationsPerTask + operationId)
                            successfulOperations += 1
                        } catch {
                            errors.append(error)
                        }
                    }

                    let taskDuration = CFAbsoluteTimeGetCurrent() - taskStartTime
                    return StressTaskResult(
                        taskId: taskId,
                        duration: taskDuration,
                        successfulOperations: successfulOperations,
                        totalOperations: operationsPerTask,
                        errors: errors
                    )
                }
            }

            for try await result in group {
                results.append(result)
            }
        }

        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime

        let stressResults = StressTestResults(
            testName: name,
            totalDuration: totalDuration,
            taskResults: results
        )

        Logger.shared.info("Stress test completed: \(name)", category: .debug)
        Logger.shared.info("  Total duration: \(String(format: "%.3f", totalDuration))s", category: .debug)
        Logger.shared.info("  Success rate: \(String(format: "%.1f", stressResults.successRate * 100))%", category: .debug)
        Logger.shared.info("  Throughput: \(String(format: "%.1f", stressResults.operationsPerSecond)) ops/sec", category: .debug)

        return stressResults
    }
}

// MARK: - Integration Testing Framework

/// Advanced integration testing utilities
@MainActor
final class IntegrationTestFramework {
    /// Test end-to-end workflow with mock services
    /// - Parameters:
    ///   - name: Test name for reporting
    ///   - workflow: The workflow to test
    ///   - mockConfiguration: Mock service configuration
    /// - Returns: Integration test results
    static func testWorkflow(
        name: String,
        workflow: @escaping (ServiceContainer, ModelContext) async throws -> WorkflowResult,
        mockConfiguration: (MockServices) throws -> Void = { _ in }
    ) async throws -> IntegrationTestResult {
        let testBase = SwiftDataTestBase()
        let container = try TestServiceContainer.create(configure: mockConfiguration)

        Logger.shared.info("Starting integration test: \(name)", category: .debug)

        let startTime = CFAbsoluteTimeGetCurrent()
        let workflowResult = try await workflow(container, testBase.modelContext)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let result = IntegrationTestResult(
            testName: name,
            duration: duration,
            workflowResult: workflowResult
        )

        Logger.shared.info("Integration test completed: \(name)", category: .debug)
        Logger.shared.info("  Duration: \(String(format: "%.3f", duration))s", category: .debug)
        Logger.shared.info("  Success: \(workflowResult.success)", category: .debug)

        return result
    }

    /// Test service interaction patterns
    /// - Parameters:
    ///   - name: Test name for reporting
    ///   - services: Services to test interaction between
    ///   - interactions: Interaction patterns to test
    /// - Returns: Service interaction test results
    static func testServiceInteractions(
        name: String,
        services: [String: Any],
        interactions: @escaping ([String: Any]) async throws -> InteractionResult
    ) async throws -> ServiceInteractionTestResult {
        Logger.shared.info("Starting service interaction test: \(name)", category: .debug)

        let startTime = CFAbsoluteTimeGetCurrent()
        let interactionResult = try await interactions(services)
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        let result = ServiceInteractionTestResult(
            testName: name,
            duration: duration,
            interactionResult: interactionResult
        )

        Logger.shared.info("Service interaction test completed: \(name)", category: .debug)
        Logger.shared.info("  Duration: \(String(format: "%.3f", duration))s", category: .debug)
        Logger.shared.info("  Success: \(interactionResult.success)", category: .debug)

        return result
    }
}

// MARK: - Test Data Generation Framework

/// Utilities for generating realistic test data
final class TestDataGenerator {
    /// Generate realistic trip data for testing
    /// - Parameters:
    ///   - count: Number of trips to generate
    ///   - modelContext: SwiftData context to insert into
    /// - Returns: Array of generated trips
    static func generateTrips(count: Int, in modelContext: ModelContext) throws -> [Trip] {
        var trips: [Trip] = []

        let destinations = [
            "Paris, France", "Tokyo, Japan", "New York, USA", "London, UK",
            "Sydney, Australia", "Barcelona, Spain", "Rome, Italy", "Bangkok, Thailand",
        ]

        for i in 0..<count {
            let destination = destinations[i % destinations.count]
            let startDate = Calendar.current.date(byAdding: .day, value: i * 7, to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 5, to: startDate) ?? Date()

            let trip = Trip(
                name: "Trip to \(destination)",
                startDate: startDate,
                endDate: endDate,
                isProtected: i % 3 == 0 // Every third trip is protected
            )

            // Add some activities
            let activityCount = Int.random(in: 2...6)
            for j in 0..<activityCount {
                let activity = Activity()
                activity.name = "Activity \(j + 1) in \(destination)"
                activity.start = Calendar.current.date(byAdding: .day, value: j, to: startDate) ?? startDate
                activity.end = Calendar.current.date(byAdding: .hour, value: 2, to: activity.start) ?? activity.start
                activity.notes = "Generated test activity"
                activity.trip = trip
                modelContext.insert(activity)
            }

            modelContext.insert(trip)
            trips.append(trip)
        }

        try modelContext.save()
        return trips
    }

    /// Generate large dataset for performance testing
    /// - Parameters:
    ///   - tripCount: Number of trips
    ///   - activitiesPerTrip: Activities per trip
    ///   - modelContext: SwiftData context
    static func generateLargeDataset(
        tripCount: Int,
        activitiesPerTrip: Int,
        in modelContext: ModelContext
    ) throws {
        Logger.shared.info("Generating large dataset: \(tripCount) trips, \(activitiesPerTrip) activities each", category: .debug)

        let batchSize = 50 // Process in batches to avoid memory issues
        for batchStart in stride(from: 0, to: tripCount, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, tripCount)

            for i in batchStart..<batchEnd {
                let trip = Trip(
                    name: "Generated Trip \(i)",
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    isProtected: false
                )

                for j in 0..<activitiesPerTrip {
                    let activity = Activity()
                    activity.name = "Generated Activity \(j) for Trip \(i)"
                    activity.start = Date()
                    activity.end = Calendar.current.date(byAdding: .hour, value: 1, to: activity.start) ?? activity.start
                    activity.notes = "Generated for performance testing"
                    activity.trip = trip
                    modelContext.insert(activity)
                }

                modelContext.insert(trip)
            }

            try modelContext.save()
            Logger.shared.info("Batch \(batchStart / batchSize + 1) completed", category: .debug)
        }

        Logger.shared.info("Large dataset generation completed", category: .debug)
    }
}

// MARK: - Data Structures

struct PerformanceMetrics {
    let testName: String
    let iterations: Int
    let durations: [TimeInterval]
    let baseline: TimeInterval?

    var averageDuration: TimeInterval {
        durations.reduce(0, +) / Double(durations.count)
    }

    var minDuration: TimeInterval {
        durations.min() ?? 0
    }

    var maxDuration: TimeInterval {
        durations.max() ?? 0
    }

    var standardDeviation: TimeInterval {
        let mean = averageDuration
        let variance = durations.map { pow($0 - mean, 2) }.reduce(0, +) / Double(durations.count)
        return sqrt(variance)
    }

    var isWithinBaseline: Bool? {
        guard let baseline = baseline else { return nil }
        return averageDuration <= baseline * 1.1 // Allow 10% variance
    }
}

struct MemoryMetrics {
    let testName: String
    let initialMemory: UInt64
    let finalMemory: UInt64

    var memoryDelta: Int64 {
        Int64(finalMemory) - Int64(initialMemory)
    }
}

struct StressTaskResult {
    let taskId: Int
    let duration: TimeInterval
    let successfulOperations: Int
    let totalOperations: Int
    let errors: [Error]

    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }
}

struct StressTestResults {
    let testName: String
    let totalDuration: TimeInterval
    let taskResults: [StressTaskResult]

    var totalOperations: Int {
        taskResults.reduce(0) { $0 + $1.totalOperations }
    }

    var successfulOperations: Int {
        taskResults.reduce(0) { $0 + $1.successfulOperations }
    }

    var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successfulOperations) / Double(totalOperations)
    }

    var operationsPerSecond: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(successfulOperations) / totalDuration
    }

    var totalErrors: Int {
        taskResults.reduce(0) { $0 + $1.errors.count }
    }
}

struct WorkflowResult {
    let success: Bool
    let steps: [String]
    let data: [String: Any]
    let errors: [Error]
}

struct IntegrationTestResult {
    let testName: String
    let duration: TimeInterval
    let workflowResult: WorkflowResult
}

struct InteractionResult {
    let success: Bool
    let interactions: [String]
    let data: [String: Any]
}

struct ServiceInteractionTestResult {
    let testName: String
    let duration: TimeInterval
    let interactionResult: InteractionResult
}
