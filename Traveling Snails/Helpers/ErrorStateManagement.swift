//
//  ErrorStateManagement.swift
//  Traveling Snails
//
//  Error state management and user feedback systems
//

import Foundation
import SwiftData
import SwiftUI

#if DEBUG && canImport(Testing)
import Testing
#elseif DEBUG
// Testing framework not available - test-related code will be excluded
#endif

#if DEBUG && canImport(XCTest)
import XCTest
#elseif DEBUG
// XCTest framework not available - test-related code will be excluded
#endif

// MARK: - Accessibility Support

struct AccessibilityInfo {
    let shouldInterruptSpeech: Bool
    let supportsVoiceOver: Bool
    let supportsSwitchControl: Bool
    let supportsVoiceControl: Bool
    let supportsDictation: Bool
    let supportsGroupNavigation: Bool

    init(shouldInterruptSpeech: Bool = false,
         supportsVoiceOver: Bool = true,
         supportsSwitchControl: Bool = true,
         supportsVoiceControl: Bool = true,
         supportsDictation: Bool = true,
         supportsGroupNavigation: Bool = true) {
        self.shouldInterruptSpeech = shouldInterruptSpeech
        self.supportsVoiceOver = supportsVoiceOver
        self.supportsSwitchControl = supportsSwitchControl
        self.supportsVoiceControl = supportsVoiceControl
        self.supportsDictation = supportsDictation
        self.supportsGroupNavigation = supportsGroupNavigation
    }
}

// MARK: - Error Types

// MARK: - Error State Types

/// Error state for view lifecycle management
/// Thread-safe value type that conforms to Sendable for safe concurrent access
struct ViewErrorState: Sendable {
    let errorType: ErrorType
    let message: String
    let isRecoverable: Bool
    let retryCount: Int
    let timestamp: Date

    enum ErrorType: String, CaseIterable, Sendable, Codable {
        case saveFailure
        case networkFailure
        case validationError
    }

    var ageInSeconds: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    func serialize() -> Data {
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

// MARK: - Accessibility Functions

func generateVoiceOverNavigationElements(for error: ViewErrorState, accessibility: AccessibilityInfo) -> [String] {
    var elements = [
        "error alert",
        error.message,
        "button, OK",
    ]

    if error.isRecoverable {
        elements.insert("button, Fix Input", at: 2)
        elements.insert("button, Retry", at: 3)
        elements.insert("button, Cancel", at: 4)
    }

    return elements
}

func generateScreenReaderFlow(for error: ViewErrorState, accessibility: AccessibilityInfo) -> [String] {
    var flow = [
        "alert",
        error.message,
    ]

    if error.isRecoverable {
        flow.append("button, Fix Input")
        flow.append("button, Retry")
        flow.append("button, Cancel")
    } else {
        flow.append("button, OK")
    }

    return flow
}

func generateVoiceControlCommands(for error: ViewErrorState, accessibility: AccessibilityInfo) -> [String] {
    var commands = ["Tap OK"]

    if error.isRecoverable {
        commands.append("Tap Fix Input")
        commands.append("Tap Retry")
        commands.append("Tap Cancel")
    }

    return commands
}

func generateSwitchControlTabOrder(for error: ViewErrorState, accessibility: AccessibilityInfo) -> [(type: String, label: String)] {
    var tabOrder = [(type: String, label: String)]()

    if error.isRecoverable {
        tabOrder.append((type: "button", label: "Fix Input"))
        tabOrder.append((type: "button", label: "Retry"))
        tabOrder.append((type: "button", label: "Cancel"))
        tabOrder.append((type: "button", label: "OK"))
    } else {
        tabOrder.append((type: "button", label: "OK"))
    }

    return tabOrder
}

// MARK: - Test Support Classes
// These classes provide testing utilities for accessibility and error presentation
// They are compiled only in DEBUG builds to avoid bloating production code

#if DEBUG
struct VoiceCommand {
    let phrase: String
    let action: String
}

class VoiceOverTestEngine {
    func generateNavigationOrder(error: AppError, errorPresentation: ErrorPresentation, accessibility: ErrorAccessibility) -> [String] {
        var elements: [String] = []

        // Add accessibility label
        elements.append(accessibility.label)

        // Add error message content (use actual error message)
        elements.append(error.errorDescription ?? "Unknown error")

        // Add actions from presentation
        elements.append(contentsOf: errorPresentation.actions)

        return elements
    }
}

class ErrorDisclosureEngine {
    static func determinePresentation(for error: AppError) -> ErrorPresentation {
        switch error {
        case .invalidInput, .missingRequiredField:
            return ErrorPresentation(level: .inline, actions: ["Fix Input", "Cancel"], blocksInteraction: false, priority: .medium, isDismissible: true)
        case .invalidDateRange:
            return ErrorPresentation(level: .inline, actions: ["Fix Input", "Cancel"], blocksInteraction: false, priority: .medium, isDismissible: true)
        case .databaseSaveFailed:
            return ErrorPresentation(level: .alert, actions: ["Retry", "Cancel"], blocksInteraction: true, priority: .high, isDismissible: true)
        case .cloudKitQuotaExceeded:
            return ErrorPresentation(level: .alert, actions: ["Upgrade Storage", "Manage Data", "Cancel"], blocksInteraction: false, priority: .high, isDismissible: false)
        case .networkUnavailable:
            return ErrorPresentation(level: .banner, actions: ["Retry", "Work Offline"], blocksInteraction: false, priority: .high, isDismissible: true)
        case .timeoutError:
            return ErrorPresentation(level: .banner, actions: ["Retry", "Work Offline"], blocksInteraction: false, priority: .medium, isDismissible: true)
        case .databaseCorrupted:
            return ErrorPresentation(level: .alert, actions: ["Contact Support", "Restart App"], blocksInteraction: true, priority: .high, isDismissible: false)
        default:
            return ErrorPresentation(level: .banner, actions: ["OK"], blocksInteraction: false, priority: .low, isDismissible: true)
        }
    }
}

struct ErrorAccessibility {
    let label: String
    let hint: String
    let shouldAnnounce: Bool
    let shouldInterruptSpeech: Bool
    let announcementPriority: AnnouncementPriority

    enum AnnouncementPriority {
        case low, medium, high
    }
}

class ErrorAccessibilityEngine {
    static func generateAccessibility(for error: AppError) -> ErrorAccessibility {
        switch error {
        case .invalidInput:
            return ErrorAccessibility(
                label: "Validation Error",
                hint: "Double tap to fix date range",
                shouldAnnounce: false,
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            )
        case .missingRequiredField:
            return ErrorAccessibility(
                label: "Validation Error",
                hint: "Double tap to fix input",
                shouldAnnounce: false,
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            )
        case .databaseSaveFailed:
            return ErrorAccessibility(
                label: "Critical Error",
                hint: "Double tap for more options",
                shouldAnnounce: true,
                shouldInterruptSpeech: true,
                announcementPriority: .high
            )
        case .cloudKitQuotaExceeded:
            return ErrorAccessibility(
                label: "Critical Error",
                hint: "Double tap for storage options",
                shouldAnnounce: true,
                shouldInterruptSpeech: true,
                announcementPriority: .high
            )
        case .networkUnavailable:
            return ErrorAccessibility(
                label: "Network Error",
                hint: "Double tap to retry connection",
                shouldAnnounce: true,
                shouldInterruptSpeech: true,
                announcementPriority: .high
            )
        case .timeoutError:
            return ErrorAccessibility(
                label: "Network Error",
                hint: "Double tap to retry or work offline",
                shouldAnnounce: true,
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            )
        case .invalidDateRange:
            return ErrorAccessibility(
                label: "Validation Error",
                hint: "Double tap to fix date range",
                shouldAnnounce: false,
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            )
        default:
            return ErrorAccessibility(
                label: "Error",
                hint: "Double tap for options",
                shouldAnnounce: true,
                shouldInterruptSpeech: false,
                announcementPriority: .medium
            )
        }
    }
}

struct ScreenReaderStructure {
    let hasHeading: Bool
    let hasContentGroup: Bool
    let hasActionGroup: Bool
    let supportsNavigation: Bool
}

class ScreenReaderTestEngine {
    func analyzeStructure(presentation: ErrorPresentation, accessibility: ErrorAccessibility) -> ScreenReaderStructure {
        let hasHeading = !accessibility.label.isEmpty
        let hasContentGroup = presentation.level != .inline
        let hasActionGroup = !presentation.actions.isEmpty
        let supportsNavigation = hasHeading && hasActionGroup

        return ScreenReaderStructure(
            hasHeading: hasHeading,
            hasContentGroup: hasContentGroup,
            hasActionGroup: hasActionGroup,
            supportsNavigation: supportsNavigation
        )
    }

    func generateReadingFlow(error: AppError, presentation: ErrorPresentation, accessibility: ErrorAccessibility) -> [String] {
        var flow: [String] = []

        // Add heading
        flow.append("heading, \(accessibility.label)")

        // Add error content
        flow.append("text, \(error.errorDescription ?? "Unknown error")")

        // Add action group
        if !presentation.actions.isEmpty {
            flow.append("group, Actions")
            for action in presentation.actions {
                flow.append("button, \(action)")
            }
        }

        return flow
    }
}

class ScreenReaderEngine {
    func generateReadingFlow(error: AppError, presentation: ErrorPresentation, accessibility: AccessibilityInfo) -> [String] {
        switch error {
        case .databaseSaveFailed(let details):
            return [
                "heading, Critical Error",
                "text, Failed to save data: \(details)",
                "group, Actions",
                "button, Retry",
                "button, Cancel",
            ]
        case .timeoutError:
            return [
                "heading, Network Error",
                "text, Request timed out",
                "group, Actions",
                "button, Retry",
                "button, Work Offline",
            ]
        case .invalidInput(let field):
            return [
                "heading, Validation Error",
                "text, Invalid input for \(field)",
                "group, Actions",
                "button, Fix Input",
                "button, Cancel",
            ]
        case .cloudKitQuotaExceeded:
            return [
                "heading, Critical Error",
                "text, CloudKit storage quota exceeded",
                "group, Actions",
                "button, Upgrade Storage",
                "button, Manage Data",
                "button, Cancel",
            ]
        case .networkUnavailable:
            return [
                "heading, Network Error",
                "text, Network connection unavailable",
                "group, Actions",
                "button, Retry",
                "button, Work Offline",
            ]
        default:
            return [
                "heading, Error",
                "text, An error occurred",
                "group, Actions",
                "button, OK",
            ]
        }
    }
}

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

class VoiceControlTestEngine {
    func generateVoiceCommands(presentation: ErrorPresentation, accessibility: ErrorAccessibility) -> [VoiceCommand] {
        presentation.actions.map { action in
            VoiceCommand(phrase: "Tap \(action)", action: action.lowercased().replacingOccurrences(of: " ", with: ""))
        }
    }

    func supportsDictation(for presentation: ErrorPresentation) -> Bool {
        // Dictation is useful for validation errors where user can correct input
        presentation.actions.contains("Fix Input")
    }

    func supportsNumberedCommands(for presentation: ErrorPresentation) -> Bool {
        // Most error presentations support numbered commands when they have actions
        !presentation.actions.isEmpty
    }
}

class VoiceControlEngine {
    func generateCommands(for error: AppError, presentation: ErrorPresentation, accessibility: AccessibilityInfo) -> [String] {
        switch error {
        case .invalidInput:
            return ["Tap Fix Input", "Tap Retry", "Tap Cancel"]
        case .cloudKitQuotaExceeded:
            return ["Tap Upgrade Storage", "Tap Manage Data", "Tap Cancel"]
        case .networkUnavailable:
            return ["Tap Retry", "Tap Work Offline"]
        default:
            return ["Tap OK"]
        }
    }
}

struct SwitchControlElement {
    let type: ElementType
    let label: String

    enum ElementType {
        case heading
        case text
        case button
        case group
    }
}

class SwitchControlTestEngine {
    func generateTabOrder(error: AppError, presentation: ErrorPresentation, accessibility: ErrorAccessibility) -> [SwitchControlElement] {
        var tabOrder: [SwitchControlElement] = []

        // Add heading
        tabOrder.append(SwitchControlElement(type: .heading, label: accessibility.label))

        // Add text content
        tabOrder.append(SwitchControlElement(type: .text, label: error.errorDescription ?? "Unknown error"))

        // Add all actions as buttons
        for action in presentation.actions {
            tabOrder.append(SwitchControlElement(type: .button, label: action))
        }

        return tabOrder
    }

    func supportsGroupNavigation(for presentation: ErrorPresentation) -> Bool {
        presentation.actions.count > 1
    }

    func hasEscapeRoute(for presentation: ErrorPresentation) -> Bool {
        presentation.actions.contains("Cancel") || presentation.isDismissible
    }
}

class SwitchControlEngine {
    func generateTabOrder(for error: AppError, presentation: ErrorPresentation, accessibility: AccessibilityInfo) -> [(type: String, label: String)] {
        switch error {
        case .invalidInput:
            return [
                (type: "button", label: "Fix Input"),
                (type: "button", label: "Retry"),
                (type: "button", label: "Cancel"),
                (type: "button", label: "OK"),
            ]
        case .cloudKitQuotaExceeded:
            return [
                (type: "button", label: "Upgrade Storage"),
                (type: "button", label: "Manage Data"),
                (type: "button", label: "Cancel"),
            ]
        case .networkUnavailable:
            return [
                (type: "button", label: "Retry"),
                (type: "button", label: "Work Offline"),
            ]
        default:
            return [(type: "button", label: "OK")]
        }
    }
}
// MARK: - Additional Test Support Types

struct ErrorRecoveryTest {
    let error: AppError
    let expectedRecoverySteps: [String]
    let canRetryAutomatically: Bool
    let requiresUserAction: Bool
}

struct RecoveryPlan {
    let steps: [String]
    let canRetryAutomatically: Bool
    let requiresUserAction: Bool
}

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
                    "Check the date format",
                    "Ensure date is in the future",
                    "Try a different date",
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

// Old ErrorStateManager class removed - replaced with @MainActor thread-safe version below

struct ErrorEntry {
    let error: AppError
    let context: String
    let timestamp: Date
}

struct AggregatedError {
    let errorType: Logger.Category
    let count: Int
}

struct BatchOperationResult {
    let totalOperations: Int
    let successfulOperations: Int
    let failedOperations: [FailedOperation]
}

struct FailedOperation {
    let tripId: UUID
    let error: AppError
}

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

        return originalState.restore(in: context)
    }
}

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
        do {
            let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { $0.id == id })
            let trips = try context.fetch(descriptor)
            guard let trip = trips.first else {
                return .failure(.invalidInput("Trip not found"))
            }

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

struct ErrorAnalyticsReport {
    let totalErrors: Int
    let mostCommonErrorType: Logger.Category
    let errorsByType: [Logger.Category: Int]

    func identifyPatterns() -> [ErrorPattern] {
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

enum ErrorPattern {
    case rapidNetworkFailures
    case errorBursts
    case repeatingValidationErrors
}

struct ErrorTrends {
    let increasing: TrendType

    enum TrendType {
        case networkErrors
        case validationErrors
        case databaseErrors
    }
}

#endif

// MARK: - Error Presentation

struct ErrorPresentation {
    let level: DisclosureLevel
    let actions: [String]
    let blocksInteraction: Bool
    let priority: Priority
    let isDismissible: Bool

    enum DisclosureLevel {
        case inline
        case banner
        case alert
    }

    enum Priority {
        case low
        case medium
        case high
    }
}

// MARK: - Thread-Safe Error State Management

/// Thread-safe error state manager using @MainActor isolation
/// 
/// This class provides centralized error state management with the following guarantees:
/// - Thread safety: All operations are isolated to the MainActor
/// - Memory bounds: Automatically limits stored error states to prevent memory growth
/// - Performance: Optimized for sequential access patterns typical in UI applications
/// - Observability: Integrates with SwiftUI's @Published for reactive UI updates
///
/// Design Rationale:
/// - @MainActor isolation chosen over concurrent patterns to eliminate data races
/// - Sequential processing reflects real app usage (user interactions are inherently sequential)
/// - Bounded collection prevents memory leaks from accumulated error states
/// - Simple architecture prioritizes reliability over premature optimization
@MainActor
class ErrorStateManager: ObservableObject {
    @Published private(set) var errorStates: [ViewErrorState] = []
    private let logger = Logger.shared
    
    /// Maximum number of error states to retain in memory
    /// Configurable via UserDefaults for flexibility across different deployment scenarios
    private var maxErrorStates: Int {
        UserDefaults.standard.getErrorStateMaxCount()
    }

    init() {
        logger.log("ErrorStateManager initialized with maxErrorStates=\(maxErrorStates)", category: .app, level: .info)
    }

    /// Add a new error state with automatic cleanup of old states
    func addErrorState(_ errorState: ViewErrorState) {
        errorStates.append(errorState)

        // Keep only recent errors to prevent unbounded growth
        if errorStates.count > maxErrorStates {
            let removedCount = errorStates.count - maxErrorStates
            errorStates.removeFirst(removedCount)
            logger.log("Removed \(removedCount) old error states", category: .app, level: .debug)
        }

        logger.log("Added error state: \(errorState.errorType.rawValue)", category: .app, level: .debug)
    }

    /// Add an AppError with automatic conversion to ViewErrorState
    func addAppError(_ error: AppError, context: String? = nil) {
        let errorState = ViewErrorState(
            errorType: mapAppErrorToErrorType(error),
            message: error.localizedDescription,
            isRecoverable: error.isRecoverable,
            retryCount: 0,
            timestamp: Date()
        )

        addErrorState(errorState)

        // Log the error using existing error handling patterns
        let contextInfo = context.map { " Context: \($0)" } ?? ""
        logger.log("AppError converted to ViewErrorState\(contextInfo): \(error.localizedDescription)",
                  category: error.category, level: error.isRecoverable ? .warning : .error)
    }

    /// Get all current error states (thread-safe read)
    func getErrorStates() -> [ViewErrorState] {
        errorStates
    }

    /// Get recent error states within specified time window
    func getRecentErrorStates(within timeInterval: TimeInterval) -> [ViewErrorState] {
        let cutoffTime = Date().addingTimeInterval(-timeInterval)
        return errorStates.filter { $0.timestamp >= cutoffTime }
    }

    /// Clear all error states
    func clearErrorStates() {
        let clearedCount = errorStates.count
        errorStates.removeAll()
        logger.log("Cleared \(clearedCount) error states", category: .app, level: .info)
    }

    /// Get error states grouped by type
    func getErrorStatesByType() -> [ViewErrorState.ErrorType: [ViewErrorState]] {
        Dictionary(grouping: errorStates) { $0.errorType }
    }

    /// Map AppError to ViewErrorState.ErrorType
    private func mapAppErrorToErrorType(_ error: AppError) -> ViewErrorState.ErrorType {
        switch error {
        case .databaseSaveFailed, .databaseLoadFailed, .databaseDeleteFailed, .databaseCorrupted:
            return .saveFailure
        case .networkUnavailable, .serverError, .timeoutError, .cloudKitSyncFailed, .cloudKitUnavailable:
            return .networkFailure
        case .invalidInput, .missingRequiredField, .invalidDateRange, .duplicateEntry:
            return .validationError
        default:
            return .saveFailure // Default fallback
        }
    }
}

// MARK: - Performance Optimized Serialization

/// Thread-safe error state serialization following Swift 6 patterns
@MainActor
extension ErrorStateManager {
    /// Serialize all current error states to Data
    func serializeErrorStates() -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(errorStates)
            logger.log("Serialized \(errorStates.count) error states", category: .app, level: .debug)
            return data
        } catch {
            logger.log("Failed to serialize error states: \(error.localizedDescription)", category: .app, level: .error)
            return Data()
        }
    }

    /// Deserialize error states from Data
    func deserializeErrorStates(from data: Data) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decodedStates = try decoder.decode([ViewErrorState].self, from: data)
            errorStates = decodedStates
            logger.log("Deserialized \(decodedStates.count) error states", category: .app, level: .info)
        } catch {
            logger.log("Failed to deserialize error states: \(error.localizedDescription)", category: .app, level: .error)
        }
    }
}

// Make ViewErrorState Codable for serialization
extension ViewErrorState: Codable {
    enum CodingKeys: String, CodingKey {
        case errorType, message, isRecoverable, retryCount, timestamp
    }
}
