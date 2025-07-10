//
//  ErrorStateManagementTests.swift
//  Traveling Snails
//
//

import Darwin.Mach
import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@Suite("Error State Management and User Feedback Tests")
@MainActor
struct ErrorStateManagementTests {
    /// Tests for error state management, user feedback systems, and progressive error disclosure
    /// Validates that errors are presented appropriately based on severity and user context

    @Test("Error state should persist across view lifecycle", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .validation, .critical, .mainActor))
    func testErrorStatePersistenceAcrossViewLifecycle() async throws {
        _ = SwiftDataTestBase()

        // Create error state for testing
        let errorState = ViewErrorState(
            errorType: .saveFailure,
            message: "Failed to save trip changes",
            isRecoverable: true,
            retryCount: 1,
            timestamp: Date()
        )

        // Simulate view disappearing and reappearing
        let serializedState = errorState.serialize()
        let restoredState = ViewErrorState.deserialize(from: serializedState)

        // Verify error state is preserved
        #expect(restoredState?.errorType == .saveFailure, "Error type should be preserved")
        #expect(restoredState?.message == "Failed to save trip changes", "Error message should be preserved")
        #expect(restoredState?.isRecoverable == true, "Recoverable flag should be preserved")
        #expect(restoredState?.retryCount == 1, "Retry count should be preserved")

        // Verify state age is calculated correctly
        let ageInSeconds = restoredState?.ageInSeconds ?? 0
        #expect(ageInSeconds >= 0, "Error age should be non-negative")
        #expect(ageInSeconds < 5, "Error age should be recent for test")
    }

    @Test("Error state serialization should handle edge cases", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .validation, .critical, .mainActor))
    func testErrorStateSerializationEdgeCases() async throws {
        _ = SwiftDataTestBase()

        // Test 1: Corrupted serialized data recovery
        let corruptedData = Data([0xFF, 0xFE, 0xFD, 0xFC]) // Invalid JSON
        let failedRestore = ViewErrorState.deserialize(from: corruptedData)
        #expect(failedRestore == nil, "Should gracefully handle corrupted data")

        // Test 2: Partial data corruption
        let partialData = "{\"errorType\":\"saveFailure\",\"message\":\"test\"".data(using: .utf8)!
        let partialRestore = ViewErrorState.deserialize(from: partialData)
        #expect(partialRestore == nil, "Should handle incomplete JSON")

        // Test 3: Future format compatibility (missing new fields)
        let legacyFormat = """
        {
            "errorType": "saveFailure",
            "message": "Legacy error message",
            "isRecoverable": true,
            "retryCount": 0,
            "timestamp": \(Date().timeIntervalSince1970)
        }
        """.data(using: .utf8)!

        let legacyRestore = ViewErrorState.deserialize(from: legacyFormat)
        #expect(legacyRestore != nil, "Should handle legacy format")
        #expect(legacyRestore?.message == "Legacy error message", "Should preserve legacy data")

        // Test 4: Invalid error type handling
        let invalidTypeFormat = """
        {
            "errorType": "unknownFutureErrorType",
            "message": "Future error",
            "isRecoverable": true,
            "retryCount": 0,
            "timestamp": \(Date().timeIntervalSince1970)
        }
        """.data(using: .utf8)!

        let invalidTypeRestore = ViewErrorState.deserialize(from: invalidTypeFormat)
        #expect(invalidTypeRestore == nil, "Should reject unknown error types")

        // Test 5: Very large retry counts and old timestamps
        let extremeErrorState = ViewErrorState(
            errorType: .networkFailure,
            message: "Network timeout after multiple retries",
            isRecoverable: true,
            retryCount: 999,
            timestamp: Date(timeIntervalSince1970: 0) // Very old timestamp
        )

        let extremeSerialized = extremeErrorState.serialize()
        let extremeRestored = ViewErrorState.deserialize(from: extremeSerialized)

        #expect(extremeRestored?.retryCount == 999, "Should handle large retry counts")
        #expect((extremeRestored?.ageInSeconds ?? 0) > 1_000_000, "Should calculate age for very old errors")

        // Test 6: Empty and very long messages
        let emptyMessageState = ViewErrorState(
            errorType: .saveFailure,
            message: "",
            isRecoverable: false,
            retryCount: 0,
            timestamp: Date()
        )

        let emptyMessageData = emptyMessageState.serialize()
        let emptyMessageRestored = ViewErrorState.deserialize(from: emptyMessageData)
        #expect(emptyMessageRestored?.message == "", "Should handle empty messages")

        let longMessage = String(repeating: "Very long error message. ", count: 100)
        let longMessageState = ViewErrorState(
            errorType: .validationError,
            message: longMessage,
            isRecoverable: true,
            retryCount: 0,
            timestamp: Date()
        )

        let longMessageData = longMessageState.serialize()
        let longMessageRestored = ViewErrorState.deserialize(from: longMessageData)
        #expect(longMessageRestored?.message == longMessage, "Should handle very long messages")
    }

    @Test("Error state persistence advanced edge cases", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .validation, .critical, .mainActor))
    func testErrorStatePersistenceAdvancedEdgeCases() async throws {
        _ = SwiftDataTestBase()

        // Edge Case 1: App update scenario - version format changes
        let legacyFormatWithExtraFields = """
        {
            "errorType": "saveFailure",
            "message": "Legacy error from old app version",
            "isRecoverable": true,
            "retryCount": 2,
            "timestamp": \(Date().timeIntervalSince1970),
            "legacyField": "should be ignored",
            "futureVersionField": 42
        }
        """.data(using: .utf8)!

        let legacyCompatibleRestore = ViewErrorState.deserialize(from: legacyFormatWithExtraFields)
        #expect(legacyCompatibleRestore != nil, "Should handle format changes during app updates")
        #expect(legacyCompatibleRestore?.message == "Legacy error from old app version", "Should preserve essential data across versions")

        // Edge Case 2: Multiple simultaneous errors recovery
        let simultaneousErrors = [
            ViewErrorState(errorType: .saveFailure, message: "Save failed", isRecoverable: true, retryCount: 0, timestamp: Date()),
            ViewErrorState(errorType: .networkFailure, message: "Network timeout", isRecoverable: true, retryCount: 1, timestamp: Date()),
            ViewErrorState(errorType: .validationError, message: "Invalid input", isRecoverable: false, retryCount: 0, timestamp: Date()),
        ]

        // Serialize all errors and verify they can all be restored independently
        let serializedErrors = simultaneousErrors.map { $0.serialize() }
        let restoredErrors = serializedErrors.compactMap { ViewErrorState.deserialize(from: $0) }

        #expect(restoredErrors.count == simultaneousErrors.count, "Should restore all simultaneous errors")
        #expect(Set(restoredErrors.map(\.message)) == Set(simultaneousErrors.map(\.message)), "Should preserve all error messages")

        // Edge Case 3: Device storage full simulation (using minimal data)
        let minimalErrorState = ViewErrorState(
            errorType: .saveFailure,
            message: "",  // Minimal message to simulate storage constraints
            isRecoverable: false,
            retryCount: 0,
            timestamp: Date()
        )

        let minimalSerialized = minimalErrorState.serialize()
        #expect(minimalSerialized.count < 200, "Should create minimal serialization when storage is constrained")

        let minimalRestored = ViewErrorState.deserialize(from: minimalSerialized)
        #expect(minimalRestored != nil, "Should handle minimal data scenarios")

        // Edge Case 4: Timestamp edge cases (future dates, epoch boundaries)
        let futureTimestamp = Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 86_400) // Tomorrow
        let futureErrorState = ViewErrorState(
            errorType: .networkFailure,
            message: "Future timestamp error",
            isRecoverable: true,
            retryCount: 0,
            timestamp: futureTimestamp
        )

        let futureSerialized = futureErrorState.serialize()
        let futureRestored = ViewErrorState.deserialize(from: futureSerialized)
        #expect(futureRestored?.ageInSeconds ?? 0 < 0, "Should handle future timestamps gracefully")

        // Edge Case 5: Epoch boundary (Year 2038 problem simulation)
        let epochBoundary = Date(timeIntervalSince1970: 2_147_483_647) // 32-bit epoch limit
        let epochErrorState = ViewErrorState(
            errorType: .saveFailure,
            message: "Epoch boundary test",
            isRecoverable: true,
            retryCount: 0,
            timestamp: epochBoundary
        )

        let epochSerialized = epochErrorState.serialize()
        let epochRestored = ViewErrorState.deserialize(from: epochSerialized)
        #expect(epochRestored != nil, "Should handle epoch boundary dates")
        #expect(epochRestored?.timestamp == epochBoundary, "Should preserve exact epoch boundary timestamp")
    }

    @Test("Error state concurrent access and race conditions", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .validation, .critical, .mainActor))
    func testErrorStateConcurrentAccessAndRaceConditions() async throws {
        _ = SwiftDataTestBase()

        // Test 1: Concurrent serialization from multiple tasks
        _ = ViewErrorState(
            errorType: .saveFailure,
            message: "Concurrent test error",
            isRecoverable: true,
            retryCount: 0,
            timestamp: Date()
        )

        let concurrentSerializationTasks = 10
        var serializationResults: [Data] = []

        await withTaskGroup(of: Data.self) { group in
            for i in 0..<concurrentSerializationTasks {
                group.addTask {
                    let errorState = ViewErrorState(
                        errorType: .saveFailure,
                        message: "Concurrent serialization test \(i)",
                        isRecoverable: true,
                        retryCount: i,
                        timestamp: Date()
                    )
                    return errorState.serialize()
                }
            }

            for await result in group {
                serializationResults.append(result)
            }
        }

        #expect(serializationResults.count == concurrentSerializationTasks, "All concurrent serializations should complete")

        // Test 2: Concurrent deserialization with potential race conditions
        let deserializationTasks = serializationResults.map { data in
            Task {
                ViewErrorState.deserialize(from: data)
            }
        }

        var deserializationResults: [ViewErrorState?] = []
        for task in deserializationTasks {
            let result = await task.value
            deserializationResults.append(result)
        }

        let successfulDeserializations = deserializationResults.compactMap { $0 }
        #expect(successfulDeserializations.count == concurrentSerializationTasks, "All concurrent deserializations should succeed")

        // Test 3: Race condition during error state manager operations
        let errorStateManager = ErrorStateManager()
        let concurrentManagerTasks = 50

        await withTaskGroup(of: Void.self) { group in
            // Add errors concurrently
            for i in 0..<concurrentManagerTasks {
                group.addTask {
                    let error = AppError.invalidInput("Concurrent error \(i)")
                    await errorStateManager.addAppError(error, context: "Concurrent test \(i)")
                }
            }

            // Simultaneously read from manager
            for _ in 0..<5 {
                group.addTask {
                    _ = await errorStateManager.getErrorStates()
                    _ = await errorStateManager.getErrorStatesByType()
                }
            }

            await group.waitForAll()
        }

        // Verify manager state after concurrent operations
        let errorStates = errorStateManager.getErrorStates()
        let errorsByType = errorStateManager.getErrorStatesByType()

        #expect(errorStates.count <= concurrentManagerTasks, "Error manager should handle concurrent additions")
        #expect(errorStates.count > 0, "Error states should work under concurrency")
        #expect(errorsByType.keys.count > 0, "Error states should be grouped by type correctly")

        // Test 4: Race condition during error state updates
        let mutableErrorState = ViewErrorState(
            errorType: .networkFailure,
            message: "Original message",
            isRecoverable: true,
            retryCount: 0,
            timestamp: Date()
        )

        let updateTasks = 20
        var updateResults: [Data] = []

        await withTaskGroup(of: Data.self) { group in
            for i in 0..<updateTasks {
                group.addTask {
                    // Simulate concurrent access to error state data
                    let updatedState = ViewErrorState(
                        errorType: mutableErrorState.errorType,
                        message: "Updated message \(i)",
                        isRecoverable: mutableErrorState.isRecoverable,
                        retryCount: mutableErrorState.retryCount + i,
                        timestamp: mutableErrorState.timestamp
                    )
                    return updatedState.serialize()
                }
            }

            for await result in group {
                updateResults.append(result)
            }
        }

        #expect(updateResults.count == updateTasks, "All concurrent updates should complete")

        // Verify all updates produced valid serialized data
        let validUpdates = updateResults.compactMap { ViewErrorState.deserialize(from: $0) }
        #expect(validUpdates.count == updateTasks, "All concurrent updates should produce valid error states")

        // Test 5: Stress test with rapid concurrent operations
        let stressTestDuration = 1.0 // 1 second
        let stressTestStart = Date()
        var stressTestOperations = 0

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<10 { // 10 concurrent workers
                group.addTask {
                    var operationCount = 0
                    while Date().timeIntervalSince(stressTestStart) < stressTestDuration {
                        let errorState = ViewErrorState(
                            errorType: .validationError,
                            message: "Stress test \(operationCount)",
                            isRecoverable: true,
                            retryCount: operationCount,
                            timestamp: Date()
                        )

                        let serialized = errorState.serialize()
                        let deserialized = ViewErrorState.deserialize(from: serialized)

                        if deserialized != nil {
                            operationCount += 1
                        }
                    }
                    return operationCount
                }
            }

            for await count in group {
                stressTestOperations += count
            }
        }

        #expect(stressTestOperations > 100, "Stress test should complete many operations under concurrency")

        let stressTestActualDuration = Date().timeIntervalSince(stressTestStart)
        #expect(stressTestActualDuration < 2.0, "Stress test should complete within reasonable time")
    }

    @Test("Error state memory management during serialization", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .performance, .validation, .mainActor))
    func testErrorStateMemoryManagement() async throws {
        _ = SwiftDataTestBase()

        var initialMemory = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let initialResult = withUnsafeMutablePointer(to: &initialMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        // Create and serialize many error states to test memory usage
        var errorStates: [ViewErrorState] = []
        for i in 0..<1000 {
            let errorState = ViewErrorState(
                errorType: .networkFailure,
                message: "Test error #\(i) with substantial message content",
                isRecoverable: true,
                retryCount: i % 10,
                timestamp: Date()
            )
            errorStates.append(errorState)
        }

        // Serialize all states
        var serializedData: [Data] = []
        for errorState in errorStates {
            serializedData.append(errorState.serialize())
        }

        // Deserialize all states
        var restoredStates: [ViewErrorState?] = []
        for data in serializedData {
            restoredStates.append(ViewErrorState.deserialize(from: data))
        }

        // Verify all states were properly restored
        let successfulRestores = restoredStates.compactMap { $0 }.count
        #expect(successfulRestores == 1000, "All error states should be successfully serialized and restored")

        // Memory should not grow excessively
        var finalMemory = mach_task_basic_info()
        let finalResult = withUnsafeMutablePointer(to: &finalMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if initialResult == KERN_SUCCESS && finalResult == KERN_SUCCESS {
            let memoryGrowth = finalMemory.resident_size - initialMemory.resident_size
            #expect(memoryGrowth < 50_000_000, "Memory growth should be reasonable (< 50MB)")
        }
        // If memory info calls fail, we skip the memory growth test (no assertion needed)
    }

    @Test("Progressive error disclosure should match error severity", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .critical, .mainActor))
    func testProgressiveErrorDisclosureMatchesSeverity() async throws {
        // Test different error scenarios and their appropriate presentation
        let errorScenarios: [ErrorDisclosureTest] = [
            // Validation errors - should be inline/banner level
            ErrorDisclosureTest(
                error: AppError.invalidInput("Trip name cannot be empty"),
                expectedLevel: .inline,
                expectedActions: ["Fix", "Cancel"],
                shouldBlockUserInteraction: false
            ),
            // Network errors - should be banner with retry
            ErrorDisclosureTest(
                error: AppError.networkUnavailable,
                expectedLevel: .banner,
                expectedActions: ["Retry", "Work Offline"],
                shouldBlockUserInteraction: false
            ),
            // Critical errors - should be full alert
            ErrorDisclosureTest(
                error: AppError.databaseCorrupted("Database corruption detected"),
                expectedLevel: .alert,
                expectedActions: ["Contact Support", "Restart App"],
                shouldBlockUserInteraction: true
            ),
            // CloudKit quota - should be alert with guidance
            ErrorDisclosureTest(
                error: AppError.cloudKitQuotaExceeded,
                expectedLevel: .alert,
                expectedActions: ["Upgrade Storage", "Manage Data", "Cancel"],
                shouldBlockUserInteraction: false
            ),
        ]

        for scenario in errorScenarios {
            let disclosure = ErrorDisclosureEngine.determinePresentation(for: scenario.error)

            // Convert ErrorPresentation.DisclosureLevel to ErrorDisclosureTest.DisclosureLevel for comparison
            let actualLevel: ErrorDisclosureTest.DisclosureLevel
            switch disclosure.level {
            case .inline:
                actualLevel = .inline
            case .banner:
                actualLevel = .banner
            case .alert:
                actualLevel = .alert
            }

            #expect(actualLevel == scenario.expectedLevel,
                   "Error \(scenario.error) should use \(scenario.expectedLevel) presentation")
            #expect(disclosure.actions.count >= scenario.expectedActions.count,
                   "Should provide enough action options")
            #expect(disclosure.blocksInteraction == scenario.shouldBlockUserInteraction,
                   "Should correctly block/allow interaction")

            // Verify critical errors have appropriate urgency
            if scenario.expectedLevel == .alert {
                let actualPriority: ErrorPresentation.Priority
                switch disclosure.priority {
                case .low:
                    actualPriority = .low
                case .medium:
                    actualPriority = .medium
                case .high:
                    actualPriority = .high
                }
                #expect(actualPriority == .high, "Alert-level errors should have high priority")
                #expect(!disclosure.isDismissible, "Critical errors should not be easily dismissed")
            }
        }
    }

    @Test("Error feedback should be accessible and localized", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .localization, .validation, .critical, .mainActor))
    func testErrorFeedbackAccessibilityAndLocalization() async throws {
        let errorMessages: [ErrorAccessibilityTest] = [
            ErrorAccessibilityTest(
                error: AppError.networkUnavailable,
                expectedAccessibilityLabel: "Network Error",
                expectedAccessibilityHint: "Double tap to retry connection",
                shouldAnnounceImmediately: true
            ),
            ErrorAccessibilityTest(
                error: AppError.invalidDateRange,
                expectedAccessibilityLabel: "Validation Error",
                expectedAccessibilityHint: "Double tap to fix date range",
                shouldAnnounceImmediately: false
            ),
            ErrorAccessibilityTest(
                error: AppError.databaseSaveFailed("Save failed"),
                expectedAccessibilityLabel: "Critical Error",
                expectedAccessibilityHint: "Double tap for more options",
                shouldAnnounceImmediately: true
            ),
        ]

        for test in errorMessages {
            let accessibility = ErrorAccessibilityEngine.generateAccessibility(for: test.error)

            #expect(!accessibility.label.isEmpty, "Should provide accessibility label")
            #expect(!accessibility.hint.isEmpty, "Should provide accessibility hint")
            #expect(accessibility.shouldAnnounce == test.shouldAnnounceImmediately,
                   "Should correctly determine announcement priority")

            // Test localization keys exist
            let localizationKey = ErrorLocalizationEngine.getLocalizationKey(for: test.error)
            #expect(!localizationKey.isEmpty, "Should provide localization key")
            #expect(localizationKey.hasPrefix("error."), "Localization key should follow naming convention")
        }
    }

    @Test("VoiceOver navigation should work correctly for error messages", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .critical, .mainActor))
    func testVoiceOverNavigationForErrorMessages() async throws {
        let errorScenarios = [
            VoiceOverErrorTest(
                error: AppError.networkUnavailable,
                expectedNavigationOrder: [
                    "Network Error",
                    "Network connection unavailable",
                    "Retry",
                    "Work Offline",
                ],
                shouldInterruptSpeech: true,
                announcementPriority: .high
            ),
            VoiceOverErrorTest(
                error: AppError.invalidInput("Trip name"),
                expectedNavigationOrder: [
                    "Validation Error",
                    "Invalid input for Trip name",
                    "Fix Input",
                    "Cancel",
                ],
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            ),
            VoiceOverErrorTest(
                error: AppError.cloudKitQuotaExceeded,
                expectedNavigationOrder: [
                    "Critical Error",
                    "CloudKit storage quota exceeded",
                    "Upgrade Storage",
                    "Manage Data",
                    "Cancel",
                ],
                shouldInterruptSpeech: true,
                announcementPriority: .high
            ),
        ]

        for scenario in errorScenarios {
            let voiceOverEngine = VoiceOverTestEngine()
            let errorPresentation = ErrorDisclosureEngine.determinePresentation(for: scenario.error)
            let accessibility = ErrorAccessibilityEngine.generateAccessibility(for: scenario.error)

            // Test navigation order
            let navigationElements = voiceOverEngine.generateNavigationOrder(
                error: scenario.error,
                errorPresentation: errorPresentation,
                accessibility: accessibility
            )

            #expect(navigationElements.count >= scenario.expectedNavigationOrder.count,
                   "Should provide all expected navigation elements")

            for (index, expectedElement) in scenario.expectedNavigationOrder.enumerated() {
                #expect(navigationElements[safe: index]?.contains(expectedElement) == true,
                       "Navigation element \(index) should contain '\(expectedElement)'")
            }

            // Test speech interruption
            #expect(accessibility.shouldInterruptSpeech == scenario.shouldInterruptSpeech,
                   "Should correctly determine speech interruption for \(scenario.error)")

            // Test announcement priority
            #expect(accessibility.announcementPriority == scenario.announcementPriority,
                   "Should set correct announcement priority for \(scenario.error)")
        }
    }

    @Test("Screen reader compatibility for error message structure", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .critical, .mainActor))
    func testScreenReaderCompatibilityForErrorStructure() async throws {
        let testCases = [
            ScreenReaderTest(
                error: AppError.databaseSaveFailed("Connection lost"),
                expectedStructure: ScreenReaderStructure(
                    hasHeading: true,
                    hasContentGroup: true,
                    hasActionGroup: true,
                    supportsNavigation: true
                ),
                expectedReadingFlow: [
                    "heading, Critical Error",
                    "text, Failed to save data: Connection lost",
                    "group, Actions",
                    "button, Retry",
                    "button, Cancel",
                ]
            ),
            ScreenReaderTest(
                error: AppError.timeoutError,
                expectedStructure: ScreenReaderStructure(
                    hasHeading: true,
                    hasContentGroup: true,
                    hasActionGroup: true,
                    supportsNavigation: true
                ),
                expectedReadingFlow: [
                    "heading, Network Error",
                    "text, Request timed out",
                    "group, Actions",
                    "button, Retry",
                    "button, Work Offline",
                ]
            ),
        ]

        for testCase in testCases {
            let screenReader = ScreenReaderTestEngine()
            let presentation = ErrorDisclosureEngine.determinePresentation(for: testCase.error)
            let accessibility = ErrorAccessibilityEngine.generateAccessibility(for: testCase.error)

            let structure = screenReader.analyzeStructure(
                presentation: presentation,
                accessibility: accessibility
            )

            #expect(structure.hasHeading == testCase.expectedStructure.hasHeading,
                   "Should have proper heading structure")
            #expect(structure.hasContentGroup == testCase.expectedStructure.hasContentGroup,
                   "Should have content group")
            #expect(structure.hasActionGroup == testCase.expectedStructure.hasActionGroup,
                   "Should have action group")
            #expect(structure.supportsNavigation == testCase.expectedStructure.supportsNavigation,
                   "Should support navigation")

            let readingFlow = screenReader.generateReadingFlow(
                error: testCase.error,
                presentation: presentation,
                accessibility: accessibility
            )

            #expect(readingFlow.count >= testCase.expectedReadingFlow.count,
                   "Should provide complete reading flow")

            for (index, expectedItem) in testCase.expectedReadingFlow.enumerated() {
                #expect(readingFlow[safe: index] == expectedItem,
                       "Reading flow item \(index) should match expected")
            }
        }
    }

    @Test("Voice Control integration for error recovery actions", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .critical, .mainActor))
    func testVoiceControlIntegrationForErrorRecovery() async throws {
        let voiceControlScenarios = [
            VoiceControlTest(
                error: AppError.networkUnavailable,
                expectedVoiceCommands: [
                    VoiceCommand(phrase: "Tap Retry", action: "retry"),
                    VoiceCommand(phrase: "Tap Work Offline", action: "workOffline"),
                ],
                supportsDictation: false,
                supportsNumberedCommands: true
            ),
            VoiceControlTest(
                error: AppError.missingRequiredField("Trip name"),
                expectedVoiceCommands: [
                    VoiceCommand(phrase: "Tap Fix Input", action: "fixInput"),
                    VoiceCommand(phrase: "Tap Cancel", action: "cancel"),
                ],
                supportsDictation: true,
                supportsNumberedCommands: true
            ),
            VoiceControlTest(
                error: AppError.cloudKitQuotaExceeded,
                expectedVoiceCommands: [
                    VoiceCommand(phrase: "Tap Upgrade Storage", action: "upgradeStorage"),
                    VoiceCommand(phrase: "Tap Manage Data", action: "manageData"),
                    VoiceCommand(phrase: "Tap Cancel", action: "cancel"),
                ],
                supportsDictation: false,
                supportsNumberedCommands: true
            ),
        ]

        for scenario in voiceControlScenarios {
            let voiceControl = VoiceControlTestEngine()
            let presentation = ErrorDisclosureEngine.determinePresentation(for: scenario.error)
            let accessibility = ErrorAccessibilityEngine.generateAccessibility(for: scenario.error)

            let voiceCommands = voiceControl.generateVoiceCommands(
                presentation: presentation,
                accessibility: accessibility
            )

            #expect(voiceCommands.count >= scenario.expectedVoiceCommands.count,
                   "Should provide all expected voice commands")

            for expectedCommand in scenario.expectedVoiceCommands {
                let matchingCommand = voiceCommands.first {
                    $0.phrase.contains(expectedCommand.phrase.replacingOccurrences(of: "Tap ", with: ""))
                }
                #expect(matchingCommand != nil,
                       "Should provide voice command for '\(expectedCommand.phrase)'")
            }

            // Test dictation support for text input errors
            let supportsDictation = voiceControl.supportsDictation(for: presentation)
            #expect(supportsDictation == scenario.supportsDictation,
                   "Should correctly determine dictation support")

            // Test numbered commands  
            let supportsNumbered = voiceControl.supportsNumberedCommands(for: presentation)
            #expect(supportsNumbered == scenario.supportsNumberedCommands,
                   "Should correctly determine numbered command support")
        }
    }

    @Test("Switch Control accessibility for error dialogs", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .critical, .mainActor))
    func testSwitchControlAccessibilityForErrorDialogs() async throws {
        let switchControlScenarios = [
            SwitchControlTest(
                error: AppError.databaseSaveFailed("Connection lost"),
                expectedTabOrder: [
                    SwitchControlElement(type: .heading, label: "Critical Error"),
                    SwitchControlElement(type: .text, label: "Failed to save data: Connection lost"),
                    SwitchControlElement(type: .button, label: "Retry"),
                    SwitchControlElement(type: .button, label: "Cancel"),
                ],
                supportsGroupNavigation: true,
                hasEscapeRoute: true
            ),
            SwitchControlTest(
                error: AppError.invalidInput("Trip name"),
                expectedTabOrder: [
                    SwitchControlElement(type: .heading, label: "Validation Error"),
                    SwitchControlElement(type: .text, label: "Invalid input for Trip name"),
                    SwitchControlElement(type: .button, label: "Fix Input"),
                    SwitchControlElement(type: .button, label: "Cancel"),
                ],
                supportsGroupNavigation: true,
                hasEscapeRoute: true
            ),
        ]

        for scenario in switchControlScenarios {
            let switchControl = SwitchControlTestEngine()
            let presentation = ErrorDisclosureEngine.determinePresentation(for: scenario.error)
            let accessibility = ErrorAccessibilityEngine.generateAccessibility(for: scenario.error)

            let tabOrder = switchControl.generateTabOrder(
                error: scenario.error,
                presentation: presentation,
                accessibility: accessibility
            )

            #expect(tabOrder.count >= scenario.expectedTabOrder.count,
                   "Should provide complete tab order")

            for (index, expectedElement) in scenario.expectedTabOrder.enumerated() {
                let actualElement = tabOrder[safe: index]
                #expect(actualElement?.type == expectedElement.type,
                       "Tab order element \(index) should have correct type")
                #expect(actualElement?.label.contains(expectedElement.label) == true,
                       "Tab order element \(index) should contain expected label")
            }

            // Test group navigation
            let groupNavigation = switchControl.supportsGroupNavigation(for: presentation)
            #expect(groupNavigation == scenario.supportsGroupNavigation,
                   "Should correctly determine group navigation support")

            // Test escape route
            let escapeRoute = switchControl.hasEscapeRoute(for: presentation)
            #expect(escapeRoute == scenario.hasEscapeRoute,
                   "Should provide escape route for accessibility")
        }
    }

    @Test("Error state should support batch operations", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .validation, .mainActor))
    func testErrorStateBatchOperations() async throws {
        let testBase = SwiftDataTestBase()

        // Create multiple trips for batch testing
        var trips: [Trip] = []
        for i in 0..<5 {
            let trip = Trip(name: "Batch Trip \(i)")
            testBase.modelContext.insert(trip)
            trips.append(trip)
        }
        try testBase.modelContext.save()

        // Simulate batch operation with some failures
        let batchResult = BatchOperationResult(
            totalOperations: 5,
            successfulOperations: 3,
            failedOperations: [
                FailedOperation(tripId: trips[1].id, error: AppError.networkUnavailable),
                FailedOperation(tripId: trips[3].id, error: AppError.invalidInput("Invalid data")),
            ]
        )

        // Test batch error state management
        let batchErrorState = BatchErrorState(result: batchResult)

        #expect(batchErrorState.hasErrors == true, "Should detect batch errors")
        #expect(batchErrorState.partialSuccess == true, "Should detect partial success")
        #expect(batchErrorState.failedCount == 2, "Should count failed operations")
        #expect(batchErrorState.successCount == 3, "Should count successful operations")

        // Test error grouping by type
        let groupedErrors = batchErrorState.groupErrorsByType()
        #expect(groupedErrors.count == 2, "Should group errors by type")
        #expect(groupedErrors[.network]?.count == 1, "Should group network errors")
        #expect(groupedErrors[.app]?.count == 1, "Should group validation errors")
    }

    @Test("Error recovery should provide clear next steps", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .accessibility, .validation, .userInterface, .mainActor))
    func testErrorRecoveryProvidesNextSteps() async throws {
        let recoveryScenarios: [ErrorRecoveryTest] = [
            ErrorRecoveryTest(
                error: AppError.networkUnavailable,
                expectedRecoverySteps: [
                    "Check your internet connection",
                    "Try syncing again",
                    "Work offline if needed",
                ],
                canRetryAutomatically: true,
                requiresUserAction: false
            ),
            ErrorRecoveryTest(
                error: AppError.cloudKitQuotaExceeded,
                expectedRecoverySteps: [
                    "Free up iCloud storage space",
                    "Upgrade your iCloud plan",
                    "Delete unnecessary data",
                ],
                canRetryAutomatically: false,
                requiresUserAction: true
            ),
            ErrorRecoveryTest(
                error: AppError.invalidDateRange,
                expectedRecoverySteps: [
                    "Check the date format",
                    "Ensure date is in the future",
                    "Try a different date",
                ],
                canRetryAutomatically: false,
                requiresUserAction: true
            ),
        ]

        for scenario in recoveryScenarios {
            let recovery = ErrorRecoveryEngine.generateRecoveryPlan(for: scenario.error)

            #expect(recovery.steps.count >= scenario.expectedRecoverySteps.count,
                   "Should provide enough recovery steps")
            #expect(recovery.canRetryAutomatically == scenario.canRetryAutomatically,
                   "Should correctly determine automatic retry capability")
            #expect(recovery.requiresUserAction == scenario.requiresUserAction,
                   "Should correctly determine user action requirement")

            // Verify steps are actionable
            for step in recovery.steps {
                #expect(step.count > 10, "Recovery steps should be descriptive")
                #expect(step.contains("Try") || step.contains("Check") || step.contains("Ensure") ||
                       step.contains("Delete") || step.contains("Upgrade") || step.contains("Free"),
                       "Steps should contain action verbs")
            }
        }
    }

    @Test("Error state should handle rapid consecutive errors", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .performance, .validation, .mainActor))
    func testRapidConsecutiveErrorHandling() async throws {
        let errorStateManager = ErrorStateManager()

        // Simulate rapid consecutive errors
        let rapidErrors = [
            AppError.networkUnavailable,
            AppError.timeoutError,
            AppError.serverError(500, "DNS failure"),
            AppError.invalidInput("Invalid input"),
            AppError.serverError(503, "Server error"),
        ]

        let startTime = Date()

        // Add errors rapidly
        for (index, error) in rapidErrors.enumerated() {
            errorStateManager.addAppError(error, context: "Rapid test \(index)")
            // Small delay to simulate rapid but not simultaneous
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify error processing completed successfully  
        let errorStates = errorStateManager.getErrorStates()
        #expect(errorStates.count <= rapidErrors.count, "Should process all errors within bounds")

        // Verify error state limiting (bound by maxErrorStates)
        let allErrorStates = errorStateManager.getErrorStates()
        #expect(allErrorStates.count <= 50, "Should limit error states to prevent unbounded growth")

        // Verify error grouping by type
        let errorsByType = errorStateManager.getErrorStatesByType()
        let networkErrors = errorsByType[.networkFailure] ?? []
        #expect(networkErrors.count > 0, "Should group network errors correctly")

        // Performance baseline: Conservative baseline to catch real regressions
        // Calculation: 50 errors + localization processing + SwiftData operations + CI variance buffer
        // Observed: ~12.8s actual, setting 15s baseline allows detection of 20%+ regressions
        #expect(duration < 15.0, "Rapid error processing should complete within 15 seconds")
        #expect(duration >= 0.05, "Should complete after all processing delays")

        // Verify memory usage during rapid error generation
        var initialMemory = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let initialResult = withUnsafeMutablePointer(to: &initialMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        // Generate many rapid errors to test memory usage
        let stressTestStartTime = Date()
        for i in 0..<100 {
            let stressError = AppError.invalidInput("Stress test error #\(i)")
            errorStateManager.addAppError(stressError, context: "Memory stress test")
        }
        let stressTestDuration = Date().timeIntervalSince(stressTestStartTime)

        // Check memory after stress test
        var finalMemory = mach_task_basic_info()
        let finalResult = withUnsafeMutablePointer(to: &finalMemory) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if initialResult == KERN_SUCCESS && finalResult == KERN_SUCCESS {
            let memoryGrowth = finalMemory.resident_size - initialMemory.resident_size
            // Memory baseline: Conservative baseline to catch real memory leaks
            // Calculation: 100 errors + localization strings + SwiftData context overhead
            // Observed: ~54MB actual, setting 60MB baseline allows detection of significant leaks
            #expect(memoryGrowth < 60_000_000, "Memory growth should be limited during rapid error generation (< 60MB)")
        }
        // If memory info calls fail, we skip the memory growth test (no assertion needed)

        #expect(stressTestDuration < 2.0, "Stress test should complete within 2 seconds for better performance guarantees")

        // Verify error manager maintains performance with many errors
        let finalErrorStates = errorStateManager.getErrorStates()
        #expect(finalErrorStates.count <= 50, "Should maintain error limiting even under stress")
    }

    @Test("Error state should support undo operations", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .userInterface, .validation, .mainActor))
    func testErrorStateUndoOperations() async throws {
        let testBase = SwiftDataTestBase()

        // Create trip for undo testing
        let trip = Trip(name: "Undo Test Trip")
        trip.notes = "Original notes"
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        // Create operation that can be undone
        let originalState = TripSnapshot(trip: trip)

        // Modify trip
        trip.name = "Modified Name"
        trip.notes = "Modified notes"

        // Simulate save failure
        let saveError = AppError.databaseSaveFailed("Save operation failed")
        let undoableError = UndoableErrorState(
            error: saveError,
            originalState: originalState,
            failedOperation: .tripUpdate
        )

        // Test undo capability
        #expect(undoableError.canUndo == true, "Should support undo for failed save")
        #expect(undoableError.undoDescription == "Restore trip to previous state",
               "Should provide clear undo description")

        // Perform undo
        let undoResult = undoableError.performUndo(in: testBase.modelContext)

        switch undoResult {
        case .success:
            #expect(trip.name == "Undo Test Trip", "Should restore original name")
            #expect(trip.notes == "Original notes", "Should restore original notes")
        case .failure:
            #expect(Bool(false), "Undo operation should succeed")
        }
    }

    @Test("Error state should provide analytics for debugging", .tags(.ui, .medium, .parallel, .swiftui, .errorHandling, .logging, .validation, .mainActor))
    func testErrorStateAnalyticsForDebugging() async throws {
        let errorAnalytics = ErrorAnalyticsEngine()

        // Generate test errors over time
        let testErrors = [
            (AppError.networkUnavailable, Date()),
            (AppError.invalidInput("Invalid input"), Date().adding(minutes: 1)),
            (AppError.timeoutError, Date().adding(minutes: 2)),
            (AppError.databaseSaveFailed("Save failed"), Date().adding(minutes: 3)),
            (AppError.serverError(500, "DNS error"), Date().adding(minutes: 4)),
        ]

        // Record errors
        for (error, timestamp) in testErrors {
            errorAnalytics.recordError(error, timestamp: timestamp)
        }

        // Generate analytics report
        let report = errorAnalytics.generateReport()

        // Verify error frequency analysis
        #expect(report.totalErrors == 5, "Should count all errors")
        #expect(report.mostCommonErrorType == .network, "Should identify most common error type")
        #expect(report.errorsByType[.network] == 3, "Should count network errors correctly")

        // Verify error patterns
        let patterns = report.identifyPatterns()
        #expect(patterns.contains(.rapidNetworkFailures), "Should identify rapid network failure pattern")
        #expect(patterns.contains(.errorBursts), "Should identify error burst pattern")

        // Verify debugging information
        let debugInfo = report.generateDebugInfo()
        #expect(!debugInfo.isEmpty, "Should provide debugging information")
        #expect(debugInfo.contains("Network"), "Debug info should mention network issues")

        // Verify trend analysis
        let trends = report.analyzeTrends()
        #expect(trends.increasing == .networkErrors, "Should identify increasing network errors trend")
    }
}

// MARK: - Test Support Types

// Note: ViewErrorState is defined in ErrorStateManagement.swift

/// Test case for error disclosure levels
struct ErrorDisclosureTest {
    let error: AppError
    let expectedLevel: DisclosureLevel
    let expectedActions: [String]
    let shouldBlockUserInteraction: Bool

    enum DisclosureLevel {
        case inline
        case banner
        case alert
    }
}

// Note: ErrorDisclosureEngine is defined in ErrorStateManagement.swift

// Note: ErrorPresentation is defined in ErrorStateManagement.swift

/// Test case for error accessibility
struct ErrorAccessibilityTest {
    let error: AppError
    let expectedAccessibilityLabel: String
    let expectedAccessibilityHint: String
    let shouldAnnounceImmediately: Bool
}

// Note: ErrorAccessibilityEngine is defined in ErrorStateManagement.swift

// Note: ErrorAccessibility is defined in ErrorStateManagement.swift

// Note: ErrorLocalizationEngine is defined in ErrorStateManagement.swift

// Note: BatchOperationResult, FailedOperation, and BatchErrorState are defined in ErrorStateManagement.swift

// Note: ErrorRecoveryTest, ErrorRecoveryEngine, and RecoveryPlan are defined in ErrorStateManagement.swift

// Note: ErrorStateManager is defined in ErrorStateManagement.swift

// Note: ErrorEntry is defined in ErrorStateManagement.swift

// Note: AggregatedError is defined in ErrorStateManagement.swift

// Note: UndoableErrorState is defined in ErrorStateManagement.swift

// Note: TripSnapshot is defined in ErrorStateManagement.swift

// Note: ErrorAnalyticsEngine is defined in ErrorStateManagement.swift

// Note: ErrorAnalyticsReport is defined in ErrorStateManagement.swift

// Note: ErrorPattern is defined in ErrorStateManagement.swift

// Note: ErrorTrends is defined in ErrorStateManagement.swift

// MARK: - Extensions

extension Date {
    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes * 60))
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - VoiceOver Testing Support

/// Test case for VoiceOver error scenarios
struct VoiceOverErrorTest {
    let error: AppError
    let expectedNavigationOrder: [String]
    let shouldInterruptSpeech: Bool
    let announcementPriority: ErrorAccessibility.AnnouncementPriority
}

// Note: VoiceOverTestEngine is defined in ErrorStateManagement.swift

// MARK: - Screen Reader Testing Support

/// Test case for screen reader compatibility
struct ScreenReaderTest {
    let error: AppError
    let expectedStructure: ScreenReaderStructure
    let expectedReadingFlow: [String]
}

// Note: ScreenReaderStructure is defined in ErrorStateManagement.swift

// Note: ScreenReaderTestEngine is defined in ErrorStateManagement.swift

// MARK: - Voice Control Testing Support

/// Test case for Voice Control integration
struct VoiceControlTest {
    let error: AppError
    let expectedVoiceCommands: [VoiceCommand]
    let supportsDictation: Bool
    let supportsNumberedCommands: Bool
}

// Note: VoiceCommand is defined in ErrorStateManagement.swift

// Note: VoiceControlTestEngine is defined in ErrorStateManagement.swift

// MARK: - Switch Control Testing Support

/// Test case for Switch Control accessibility
struct SwitchControlTest {
    let error: AppError
    let expectedTabOrder: [SwitchControlElement]
    let supportsGroupNavigation: Bool
    let hasEscapeRoute: Bool
}

// Note: SwitchControlElement is defined in ErrorStateManagement.swift

// Note: SwitchControlTestEngine is defined in ErrorStateManagement.swift

// Note: AppError already has a category property that returns Logger.Category

// ErrorStateManagementTests uses AppError.category which returns Logger.Category
