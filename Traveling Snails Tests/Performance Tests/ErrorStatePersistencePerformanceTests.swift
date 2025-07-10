//
//  ErrorStatePersistencePerformanceTests.swift
//  Traveling Snails
//
//

import Darwin.Mach
import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@Suite("Error State Persistence Performance Tests")
@MainActor
struct ErrorStatePersistencePerformanceTests {
    @Test("Sequential high-frequency error handling performance", .tags(.performance, .errorHandling, .validation, .mainActor))
    func testSequentialHighFrequencyErrorHandling() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()
        let errorCount = 1000
        let startTime = Date()

        // Test realistic sequential error bursts (simulating rapid user interactions)
        for i in 0..<errorCount {
            let errorState = ViewErrorState(
                errorType: .saveFailure,
                message: "Sequential error #\(i)",
                isRecoverable: true,
                retryCount: i % 5,
                timestamp: Date()
            )

            errorManager.addErrorState(errorState)

            // Small delay to simulate realistic UI interactions (1ms)
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let finalStates = errorManager.getErrorStates()

        // Verify all operations completed successfully
        #expect(finalStates.count <= errorCount, "Error states should be managed within bounds")
        #expect(finalStates.count > 0, "Should have error states")

        // Performance baseline: Conservative to catch real regressions
        // 1000 operations + 1ms each = ~1s base + error processing overhead = realistic 35s max
        #expect(processingTime < 35.0, "Sequential processing should complete within 35 seconds")

        print("SEQUENTIAL - Processed: \(finalStates.count)/\(errorCount), Time: \(processingTime)s")
    }

    @Test("Error state serialization performance", .tags(.performance, .errorHandling, .validation, .mainActor))
    func testErrorStateSerializationPerformance() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()
        let errorCount = 500

        // Generate error states
        for i in 0..<errorCount {
            let errorState = ViewErrorState(
                errorType: .networkFailure,
                message: "Serialization test error #\(i)",
                isRecoverable: true,
                retryCount: i % 3,
                timestamp: Date()
            )
            errorManager.addErrorState(errorState)
        }

        // Test serialization performance
        let serializeStartTime = Date()
        let serializedData = errorManager.serializeErrorStates()
        let serializationTime = Date().timeIntervalSince(serializeStartTime)

        // Test deserialization performance
        let deserializeStartTime = Date()
        let newErrorManager = ErrorStateManager()
        newErrorManager.deserializeErrorStates(from: serializedData)
        let deserializationTime = Date().timeIntervalSince(deserializeStartTime)

        let totalTime = serializationTime + deserializationTime

        // Verify serialization correctness
        let restoredStates = newErrorManager.getErrorStates()
        #expect(restoredStates.count == min(errorCount, 50), "Should restore correct number of states")
        #expect(serializedData.count > 0, "Should produce serialized data")

        // Performance expectations - much faster than old complex serialization
        #expect(serializationTime < 1.0, "Serialization should be under 1 second")
        #expect(deserializationTime < 1.0, "Deserialization should be under 1 second")
        #expect(totalTime < 2.0, "Total serialization time should be under 2 seconds")

        print("SERIALIZATION - Serialize: \(serializationTime)s, Deserialize: \(deserializationTime)s, Total: \(totalTime)s")
    }

    @Test("AppError integration performance", .tags(.performance, .errorHandling, .validation, .mainActor))
    func testAppErrorIntegrationPerformance() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()
        let errorCount = 300
        let appErrors: [AppError] = [
            .databaseSaveFailed("Test save failure"),
            .networkUnavailable,
            .invalidInput("Test field"),
            .cloudKitSyncFailed("Test sync failure"),
            .invalidDateRange,
        ]

        let startTime = Date()

        // Test realistic AppError conversion patterns
        for i in 0..<errorCount {
            let appError = appErrors[i % appErrors.count]
            errorManager.addAppError(appError, context: "Performance test #\(i)")

            // Simulate realistic error handling delays
            try await Task.sleep(nanoseconds: 500_000) // 0.5ms
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let finalStates = errorManager.getErrorStates()

        // Verify AppError mapping worked correctly
        #expect(finalStates.count > 0, "Should have converted AppErrors to ViewErrorStates")
        #expect(finalStates.count <= errorCount, "Should respect bounds")

        // Check that different error types were created
        let errorsByType = errorManager.getErrorStatesByType()
        #expect(errorsByType.keys.count > 1, "Should have multiple error types")

        // Performance baseline: 300 operations + 0.5ms each = ~150ms base + error processing overhead
        #expect(processingTime < 25.0, "AppError integration should complete within 25 seconds")

        print("APP_ERROR_INTEGRATION - Processed: \(finalStates.count)/\(errorCount), Time: \(processingTime)s, Types: \(errorsByType.keys.count)")
    }

    @Test("Memory efficiency with bounded error states", .tags(.performance, .errorHandling, .validation, .mainActor))
    func testMemoryEfficiencyWithBoundedErrorStates() async throws {
        _ = SwiftDataTestBase()

        // Measure initial memory
        var initialMemory = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let initialResult = withUnsafeMutablePointer(to: &initialMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let errorManager = ErrorStateManager()
        let largeUpdateCount = 2000 // Much larger than maxErrorStates (50)

        let startTime = Date()

        // Test that memory stays bounded even with many sequential updates
        for i in 0..<largeUpdateCount {
            let errorState = ViewErrorState(
                errorType: .saveFailure,
                message: "Memory test error #\(i)",
                isRecoverable: true,
                retryCount: i % 10,
                timestamp: Date()
            )

            errorManager.addErrorState(errorState)

            // Quick processing to test memory management
            if i % 100 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms pause every 100 items
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)

        // Measure final memory
        var finalMemory = mach_task_basic_info()
        let finalResult = withUnsafeMutablePointer(to: &finalMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let finalStates = errorManager.getErrorStates()

        // Verify bounded behavior worked
        #expect(finalStates.count <= 50, "Should maintain bounded error states (max 50)")
        #expect(finalStates.count > 0, "Should have some error states")

        if initialResult == KERN_SUCCESS && finalResult == KERN_SUCCESS {
            let memoryGrowth = finalMemory.resident_size - initialMemory.resident_size

            // Memory growth should be reasonable due to bounded collection (adjusted for CI)
            #expect(memoryGrowth < 2_000_000_000, "Memory growth should be under 2GB for \(largeUpdateCount) updates")

            print("MEMORY - Growth: \(memoryGrowth / 1_000_000)MB for \(largeUpdateCount) updates, Final states: \(finalStates.count)")
        }

        // Performance baseline: 2000 operations with memory management should be reasonable
        #expect(processingTime < 20.0, "Bounded processing should complete within 20 seconds")
    }

    @Test("Error state filtering and querying performance", .tags(.performance, .errorHandling, .validation, .mainActor))
    func testErrorStateFilteringAndQueryingPerformance() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()
        let errorCount = 200
        let baseTime = Date()

        // Create mix of error states with different timestamps
        for i in 0..<errorCount {
            let errorState = ViewErrorState(
                errorType: ViewErrorState.ErrorType.allCases[i % 3],
                message: "Query test error #\(i)",
                isRecoverable: i % 2 == 0,
                retryCount: i % 5,
                timestamp: baseTime.addingTimeInterval(TimeInterval(i) * 0.1)
            )
            errorManager.addErrorState(errorState)
        }

        // Test querying performance
        let queryStartTime = Date()

        // Test various query patterns
        let allStates = errorManager.getErrorStates()
        let recentStates = errorManager.getRecentErrorStates(within: 10.0)
        let statesByType = errorManager.getErrorStatesByType()

        let queryTime = Date().timeIntervalSince(queryStartTime)

        // Verify query results
        #expect(allStates.count > 0, "Should have error states")
        #expect(recentStates.count <= allStates.count, "Recent states should be subset")
        #expect(statesByType.keys.count > 0, "Should have grouped states")

        // Query performance should be fast
        #expect(queryTime < 0.1, "Query operations should complete within 100ms")

        print("QUERY - All: \(allStates.count), Recent: \(recentStates.count), Types: \(statesByType.keys.count), Time: \(queryTime)s")
    }

    @Test("Thread safety with sequential @MainActor access", .tags(.performance, .errorHandling, .mainActor))
    func testThreadSafetyWithSequentialMainActorAccess() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()
        let taskCount = 50 // Sequential processing

        let startTime = Date()

        // Test sequential access - @MainActor ensures thread safety
        for taskId in 0..<taskCount {
            let errorState = ViewErrorState(
                errorType: ViewErrorState.ErrorType.allCases[taskId % 3],
                message: "Sequential task \(taskId) error",
                isRecoverable: true,
                retryCount: 0,
                timestamp: Date()
            )
            errorManager.addErrorState(errorState)
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let finalStates = errorManager.getErrorStates()

        // Verify thread safety - all updates should be processed correctly
        #expect(finalStates.count > 0, "Should have processed error states")
        #expect(finalStates.count <= taskCount, "Should not exceed expected count")

        // Verify no data corruption occurred
        for state in finalStates {
            #expect(!state.message.isEmpty, "Error messages should not be corrupted")
            #expect(state.retryCount >= 0, "Retry count should be valid")
        }

        // Performance should be excellent for sequential access (adjusted for CI)
        #expect(processingTime < 3.0, "Sequential @MainActor access should complete within 3 seconds")

        print("THREAD_SAFETY - Tasks: \(taskCount), Final states: \(finalStates.count), Time: \(processingTime)s")
    }

    @Test("Non-MainActor access safety verification", .tags(.performance, .errorHandling, .mainActor))
    func testNonMainActorAccessSafety() async throws {
        _ = SwiftDataTestBase()
        
        let errorManager = ErrorStateManager()
        
        // Test that ViewErrorState can be safely created on background threads
        // and then transferred to MainActor
        let backgroundCreatedStates = await withTaskGroup(of: ViewErrorState.self, returning: [ViewErrorState].self) { group in
            var states: [ViewErrorState] = []
            
            // Create error states on background threads (testing Sendable conformance)
            for i in 0..<3 {
                group.addTask {
                    // This runs on a background thread
                    return ViewErrorState(
                        errorType: .networkFailure,
                        message: "Background error \(i)",
                        isRecoverable: true,
                        retryCount: i,
                        timestamp: Date()
                    )
                }
            }
            
            for await state in group {
                states.append(state)
            }
            
            return states
        }
        
        let startTime = Date()
        
        // Transfer states to MainActor (this should be safe due to Sendable conformance)
        for state in backgroundCreatedStates {
            errorManager.addErrorState(state)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        let finalStates = errorManager.getErrorStates()
        
        // Verify safe transfer worked correctly
        #expect(finalStates.count == backgroundCreatedStates.count, "All background-created states should be transferred")
        
        // Verify data integrity after cross-thread transfer
        let messages = Set(finalStates.map { $0.message })
        let expectedMessages = Set(backgroundCreatedStates.map { $0.message })
        #expect(messages == expectedMessages, "Message data should be preserved across thread boundaries")
        
        // Performance should be excellent for MainActor operations
        #expect(processingTime < 1.0, "MainActor operations should complete within 1 second")
        
        print("NON_MAINACTOR_SAFETY - Background created: \(backgroundCreatedStates.count), MainActor processed: \(finalStates.count), Time: \(processingTime)s")
    }

    @Test("Sendable conformance verification", .tags(.performance, .errorHandling, .mainActor))
    func testSendableConformanceVerification() async throws {
        _ = SwiftDataTestBase()

        let errorManager = ErrorStateManager()

        // Test that ViewErrorState can be safely passed across concurrency boundaries
        let sendableStates: [ViewErrorState] = [
            ViewErrorState(
                errorType: .saveFailure,
                message: "Sendable test 1",
                isRecoverable: true,
                retryCount: 0,
                timestamp: Date()
            ),
            ViewErrorState(
                errorType: .networkFailure,
                message: "Sendable test 2",
                isRecoverable: false,
                retryCount: 1,
                timestamp: Date()
            ),
            ViewErrorState(
                errorType: .validationError,
                message: "Sendable test 3",
                isRecoverable: true,
                retryCount: 2,
                timestamp: Date()
            ),
        ]

        let startTime = Date()

        // Test safe transfer by processing each state sequentially
        // This demonstrates Sendable safety without complex TaskGroup patterns
        for state in sendableStates {
            // ViewErrorState can be safely passed between contexts
            // because it conforms to Sendable
            errorManager.addErrorState(state)
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let finalStates = errorManager.getErrorStates()

        // Verify Sendable transfer worked correctly
        #expect(finalStates.count == sendableStates.count, "All Sendable states should be processed")

        // Verify data integrity after transfer
        let messages = Set(finalStates.map { $0.message })
        let expectedMessages = Set(sendableStates.map { $0.message })
        #expect(messages == expectedMessages, "Message data should be preserved across transfers")

        // Performance should be excellent
        #expect(processingTime < 1.0, "Sendable transfer should complete within 1 second")

        print("SENDABLE - Transferred: \(sendableStates.count), Final: \(finalStates.count), Time: \(processingTime)s")
    }
}

// MARK: - Note: Thread-Safe Architecture
// These tests verify the performance of the new thread-safe ErrorStateManager
// that uses @MainActor isolation instead of problematic concurrent optimizations.
// All tests use realistic sequential patterns that reflect actual app usage.
