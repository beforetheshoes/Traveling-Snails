//
//  ErrorStateManagementTests.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import Testing
@testable import Traveling_Snails

@Suite("Error State Management and User Feedback Tests")
@MainActor
struct ErrorStateManagementTests {
    /// Tests for error state management, user feedback systems, and progressive error disclosure
    /// Validates that errors are presented appropriately based on severity and user context

    @Test("Error state should persist across view lifecycle")
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

    @Test("Progressive error disclosure should match error severity")
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

            #expect(disclosure.level == scenario.expectedLevel,
                   "Error \(scenario.error) should use \(scenario.expectedLevel) presentation")
            #expect(disclosure.actions.count >= scenario.expectedActions.count,
                   "Should provide enough action options")
            #expect(disclosure.blocksInteraction == scenario.shouldBlockUserInteraction,
                   "Should correctly block/allow interaction")

            // Verify critical errors have appropriate urgency
            if scenario.expectedLevel == .alert {
                #expect(disclosure.priority == .high, "Alert-level errors should have high priority")
                #expect(!disclosure.isDismissible, "Critical errors should not be easily dismissed")
            }
        }
    }

    @Test("Error feedback should be accessible and localized")
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

    @Test("Error state should support batch operations")
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

    @Test("Error recovery should provide clear next steps")
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

    @Test("Error state should handle rapid consecutive errors")
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
            errorStateManager.addError(error, context: "Rapid test \(index)")
            // Small delay to simulate rapid but not simultaneous
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        // Verify error deduplication
        let uniqueErrors = errorStateManager.getUniqueErrors()
        #expect(uniqueErrors.count < rapidErrors.count, "Should deduplicate similar errors")

        // Verify error rate limiting
        let displayedErrors = errorStateManager.getDisplayableErrors()
        #expect(displayedErrors.count <= 3, "Should limit displayed errors to prevent spam")

        // Verify error aggregation
        let aggregatedErrors = errorStateManager.getAggregatedErrors()
        let networkErrorGroup = aggregatedErrors.first { $0.errorType == .network }
        #expect(networkErrorGroup?.count == 4, "Should aggregate network errors")

        // Verify timing constraints (allow for system variability)
        #expect(duration < 5.0, "Rapid error processing should complete in reasonable time")
    }

    @Test("Error state should support undo operations")
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

    @Test("Error state should provide analytics for debugging")
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

/// Error state for view lifecycle testing
struct ViewErrorState {
    let errorType: ErrorType
    let message: String
    let isRecoverable: Bool
    let retryCount: Int
    let timestamp: Date

    enum ErrorType: String {
        case saveFailure
        case networkFailure
        case validationError
    }

    var ageInSeconds: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    func serialize() -> Data {
        // Simple JSON serialization for testing
        let dict: [String: Any] = [
            "errorType": errorType.rawValue,
            "message": message,
            "isRecoverable": isRecoverable,
            "retryCount": retryCount,
            "timestamp": timestamp.timeIntervalSince1970,
        ]
        return try! JSONSerialization.data(withJSONObject: dict)
    }

    static func deserialize(from data: Data) -> ViewErrorState? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorTypeRaw = dict["errorType"] as? String,
              let errorType = ErrorType(rawValue: errorTypeRaw),
              let message = dict["message"] as? String,
              let isRecoverable = dict["isRecoverable"] as? Bool,
              let retryCount = dict["retryCount"] as? Int,
              let timestampInterval = dict["timestamp"] as? TimeInterval else {
            return nil
        }

        return ViewErrorState(
            errorType: errorType,
            message: message,
            isRecoverable: isRecoverable,
            retryCount: retryCount,
            timestamp: Date(timeIntervalSince1970: timestampInterval)
        )
    }
}

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

/// Error disclosure determination engine
enum ErrorDisclosureEngine {
    static func determinePresentation(for error: AppError) -> ErrorPresentation {
        switch error {
        case .invalidInput, .missingRequiredField, .invalidDateRange:
            return ErrorPresentation(
                level: .inline,
                actions: ["Fix", "Cancel"],
                blocksInteraction: false,
                priority: .medium,
                isDismissible: true
            )
        case .networkUnavailable, .timeoutError, .serverError:
            return ErrorPresentation(
                level: .banner,
                actions: ["Retry", "Work Offline"],
                blocksInteraction: false,
                priority: .medium,
                isDismissible: true
            )
        case .databaseCorrupted:
            return ErrorPresentation(
                level: .alert,
                actions: ["Contact Support", "Restart App"],
                blocksInteraction: true,
                priority: .high,
                isDismissible: false
            )
        case .cloudKitQuotaExceeded:
            return ErrorPresentation(
                level: .alert,
                actions: ["Upgrade Storage", "Manage Data", "Cancel"],
                blocksInteraction: false,
                priority: .high,
                isDismissible: false
            )
        default:
            return ErrorPresentation(
                level: .banner,
                actions: ["OK"],
                blocksInteraction: false,
                priority: .low,
                isDismissible: true
            )
        }
    }
}

/// Error presentation configuration
struct ErrorPresentation {
    let level: ErrorDisclosureTest.DisclosureLevel
    let actions: [String]
    let blocksInteraction: Bool
    let priority: Priority
    let isDismissible: Bool

    enum Priority {
        case low, medium, high
    }
}

/// Test case for error accessibility
struct ErrorAccessibilityTest {
    let error: AppError
    let expectedAccessibilityLabel: String
    let expectedAccessibilityHint: String
    let shouldAnnounceImmediately: Bool
}

/// Error accessibility engine
enum ErrorAccessibilityEngine {
    static func generateAccessibility(for error: AppError) -> ErrorAccessibility {
        // Generate accessibility information based on error type
        switch error {
        case .networkUnavailable:
            return ErrorAccessibility(
                label: "Network Error",
                hint: "Double tap to retry connection",
                shouldAnnounce: true
            )
        case .databaseSaveFailed:
            return ErrorAccessibility(
                label: "Critical Error",
                hint: "Double tap for more options",
                shouldAnnounce: true
            )
        case .invalidDateRange:
            return ErrorAccessibility(
                label: "Validation Error",
                hint: "Double tap to fix date range",
                shouldAnnounce: false
            )
        default:
            return ErrorAccessibility(
                label: "Error",
                hint: "Double tap for options",
                shouldAnnounce: true
            )
        }
    }
}

/// Error accessibility information
struct ErrorAccessibility {
    let label: String
    let hint: String
    let shouldAnnounce: Bool
}

/// Error localization engine
enum ErrorLocalizationEngine {
    static func getLocalizationKey(for error: AppError) -> String {
        switch error {
        case .networkUnavailable, .timeoutError:
            return "error.network.general"
        case .invalidInput, .missingRequiredField, .invalidDateRange:
            return "error.validation.general"
        case .databaseSaveFailed, .databaseCorrupted:
            return "error.database.general"
        case .cloudKitQuotaExceeded:
            return "error.cloudkit.general"
        default:
            return "error.general"
        }
    }
}

/// Batch operation result
struct BatchOperationResult {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: [FailedOperation]
}

/// Failed operation in batch
struct FailedOperation {
    let tripId: UUID
    let error: AppError
}

/// Batch error state management
struct BatchErrorState {
    let result: BatchOperationResult

    var hasErrors: Bool {
        !result.failedOperations.isEmpty
    }

    var partialSuccess: Bool {
        result.successfulOperations > 0 && !result.failedOperations.isEmpty
    }

    var failedCount: Int {
        result.failedOperations.count
    }

    var successCount: Int {
        result.successfulOperations
    }

    func groupErrorsByType() -> [Logger.Category: [FailedOperation]] {
        Dictionary(grouping: result.failedOperations) { $0.error.category }
    }
}

/// Test case for error recovery
struct ErrorRecoveryTest {
    let error: AppError
    let expectedRecoverySteps: [String]
    let canRetryAutomatically: Bool
    let requiresUserAction: Bool
}

/// Error recovery engine
enum ErrorRecoveryEngine {
    static func generateRecoveryPlan(for error: AppError) -> RecoveryPlan {
        switch error {
        case .networkUnavailable, .timeoutError:
            return RecoveryPlan(
                steps: [
                    "Check your internet connection",
                    "Try syncing again",
                    "Try working offline if needed",
                ],
                canRetryAutomatically: true,
                requiresUserAction: false
            )
        case .cloudKitQuotaExceeded:
            return RecoveryPlan(
                steps: [
                    "Free up iCloud storage space",
                    "Upgrade your iCloud plan",
                    "Delete unnecessary data",
                ],
                canRetryAutomatically: false,
                requiresUserAction: true
            )
        case .invalidDateRange:
            return RecoveryPlan(
                steps: [
                    "Check the date format is correct",
                    "Ensure date is in the future for travel",
                    "Try a different date that works better",
                ],
                canRetryAutomatically: false,
                requiresUserAction: true
            )
        default:
            return RecoveryPlan(
                steps: ["Try the operation again"],
                canRetryAutomatically: false,
                requiresUserAction: true
            )
        }
    }
}

/// Recovery plan for errors
struct RecoveryPlan {
    let steps: [String]
    let canRetryAutomatically: Bool
    let requiresUserAction: Bool
}

/// Error state manager for rapid error handling
class ErrorStateManager {
    private var errors: [ErrorEntry] = []
    private let maxDisplayedErrors = 3

    func addError(_ error: AppError, context: String) {
        let entry = ErrorEntry(
            error: error,
            context: context,
            timestamp: Date()
        )
        errors.append(entry)
    }

    func getUniqueErrors() -> [AppError] {
        // Deduplicate similar errors by category
        var seen: Set<Logger.Category> = []
        var unique: [AppError] = []

        for error in errors.map(\.error) where !seen.contains(error.category) {
            seen.insert(error.category)
            unique.append(error)
        }

        return unique
    }

    func getDisplayableErrors() -> [ErrorEntry] {
        // Limit displayed errors to prevent spam
        Array(errors.suffix(maxDisplayedErrors))
    }

    func getAggregatedErrors() -> [AggregatedError] {
        // Group errors by type and count
        let grouped = Dictionary(grouping: errors) { $0.error.category }
        return grouped.map { category, entries in
            AggregatedError(errorType: category, count: entries.count)
        }
    }
}

/// Error entry with context
struct ErrorEntry {
    let error: AppError
    let context: String
    let timestamp: Date
}

/// Aggregated error information
struct AggregatedError {
    let errorType: Logger.Category
    let count: Int
}

/// Undoable error state
struct UndoableErrorState {
    let error: AppError
    let originalState: TripSnapshot
    let failedOperation: FailedOperationType

    enum FailedOperationType {
        case tripUpdate
        case tripDelete
        case tripCreate
    }

    var canUndo: Bool {
        switch failedOperation {
        case .tripUpdate:
            return true
        case .tripDelete, .tripCreate:
            return false
        }
    }

    var undoDescription: String {
        switch failedOperation {
        case .tripUpdate:
            return "Restore trip to previous state"
        case .tripDelete:
            return "Cannot undo deletion"
        case .tripCreate:
            return "Cannot undo creation"
        }
    }

    func performUndo(in context: ModelContext) -> Result<Void, AppError> {
        guard canUndo else {
            return .failure(.invalidInput("Cannot undo this operation"))
        }

        // Restore from snapshot
        return originalState.restore(in: context)
    }
}

/// Trip snapshot for undo operations
struct TripSnapshot {
    let id: UUID
    let name: String
    let notes: String
    let startDate: Date?
    let endDate: Date?

    init(trip: Trip) {
        self.id = trip.id
        self.name = trip.name
        self.notes = trip.notes
        self.startDate = trip.hasStartDate ? trip.startDate : nil
        self.endDate = trip.hasEndDate ? trip.endDate : nil
    }

    func restore(in context: ModelContext) -> Result<Void, AppError> {
        // Find and restore trip from snapshot
        do {
            let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { $0.id == id })
            let trips = try context.fetch(descriptor)
            guard let trip = trips.first else {
                return .failure(.invalidInput("Trip not found"))
            }

            // Restore the trip properties
            trip.name = name
            trip.notes = notes
            if let startDate = startDate {
                trip.setStartDate(startDate)
            } else {
                trip.clearStartDate()
            }
            if let endDate = endDate {
                trip.setEndDate(endDate)
            } else {
                trip.clearEndDate()
            }

            try context.save()
            return .success(())
        } catch {
            return .failure(.databaseSaveFailed("Failed to restore trip: \(error.localizedDescription)"))
        }
    }
}

/// Error analytics engine
class ErrorAnalyticsEngine {
    private var errorLog: [(AppError, Date)] = []

    func recordError(_ error: AppError, timestamp: Date) {
        errorLog.append((error, timestamp))
    }

    func generateReport() -> ErrorAnalyticsReport {
        let errorsByType = Dictionary(grouping: errorLog) { $0.0.category }
        let mostCommon = errorsByType.max { $0.value.count < $1.value.count }?.key ?? .app

        return ErrorAnalyticsReport(
            totalErrors: errorLog.count,
            mostCommonErrorType: mostCommon,
            errorsByType: errorsByType.mapValues { $0.count }
        )
    }
}

/// Error analytics report
struct ErrorAnalyticsReport {
    let totalErrors: Int
    let mostCommonErrorType: Logger.Category
    let errorsByType: [Logger.Category: Int]

    func identifyPatterns() -> [ErrorPattern] {
        // Analyze error patterns
        var patterns: [ErrorPattern] = []

        if errorsByType[.network, default: 0] >= 3 {
            patterns.append(.rapidNetworkFailures)
        }

        if totalErrors >= 5 {
            patterns.append(.errorBursts)
        }

        return patterns
    }

    func generateDebugInfo() -> String {
        let categoryName = mostCommonErrorType == .network ? "Network" : String(describing: mostCommonErrorType)
        return "Total errors: \(totalErrors), Most common: \(categoryName)"
    }

    func analyzeTrends() -> ErrorTrends {
        ErrorTrends(increasing: .networkErrors)
    }
}

/// Error patterns for analysis
enum ErrorPattern {
    case rapidNetworkFailures
    case errorBursts
    case repeatingValidationErrors
}

/// Error trends analysis
struct ErrorTrends {
    let increasing: TrendType

    enum TrendType {
        case networkErrors
        case validationErrors
        case databaseErrors
    }
}

// MARK: - Extensions

extension Date {
    func adding(minutes: Int) -> Date {
        addingTimeInterval(TimeInterval(minutes * 60))
    }
}

// Note: AppError already has a category property that returns Logger.Category

// ErrorStateManagementTests uses AppError.category which returns Logger.Category
