//
//  TripEditErrorHandling.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI

// MARK: - Network Status
// Note: NetworkStatus is already defined in SyncService.swift, this is a local copy for view state

// MARK: - Trip Edit Error State

struct TripEditErrorState {
    let error: AppError
    let retryCount: Int
    let canRetry: Bool
    let userMessage: String
    let suggestedActions: [TripEditAction]
    let timestamp: Date

    init(error: AppError, retryCount: Int, canRetry: Bool, userMessage: String, suggestedActions: [TripEditAction]) {
        self.error = error
        self.retryCount = retryCount
        self.canRetry = canRetry
        self.userMessage = userMessage
        self.suggestedActions = suggestedActions
        self.timestamp = Date()
    }

    var isStale: Bool {
        Date().timeIntervalSince(timestamp) > AppConfiguration.errorState.staleTimeout
    }
}

// MARK: - Trip Edit Actions

enum TripEditAction: CaseIterable, Hashable {
    case retry
    case workOffline
    case saveAsDraft
    case fixInput
    case manageStorage
    case upgradeStorage
    case cancel

    var displayName: String {
        switch self {
        case .retry:
            return "Retry"
        case .workOffline:
            return "Work Offline"
        case .saveAsDraft:
            return "Save as Draft"
        case .fixInput:
            return "Fix Input"
        case .manageStorage:
            return "Manage Storage"
        case .upgradeStorage:
            return "Upgrade Storage"
        case .cancel:
            return "Cancel"
        }
    }

    var systemImage: String {
        switch self {
        case .retry:
            return "arrow.clockwise"
        case .workOffline:
            return "wifi.slash"
        case .saveAsDraft:
            return "doc.badge.plus"
        case .fixInput:
            return "pencil"
        case .manageStorage:
            return "externaldrive"
        case .upgradeStorage:
            return "icloud"
        case .cancel:
            return "xmark"
        }
    }
}

// MARK: - Enhanced Error Recovery

enum TripEditErrorRecovery {
    static func generateRecoveryPlan(for error: AppError, retryCount: Int) -> TripEditRecoveryPlan {
        switch error {
        case .networkUnavailable:
            let config = AppConfiguration.networkRetry
            return TripEditRecoveryPlan(
                primaryAction: .workOffline,
                alternativeActions: [.retry, .cancel],
                autoRetry: retryCount < config.maxAttempts,
                retryDelay: config.delay(for: retryCount),
                userGuidance: "Your changes will be saved locally and synced when you're back online."
            )
        case .timeoutError:
            let config = AppConfiguration.networkRetry
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.saveAsDraft, .cancel],
                autoRetry: retryCount < config.maxAttempts,
                retryDelay: config.baseDelay,
                userGuidance: "The operation took too long. Retrying may help."
            )
        case .databaseSaveFailed:
            let config = AppConfiguration.databaseRetry
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.saveAsDraft, .cancel],
                autoRetry: retryCount < config.maxAttempts,
                retryDelay: config.delay(for: retryCount),
                userGuidance: "There was a problem saving your changes. Your data is still safe."
            )
        case .missingRequiredField:
            return TripEditRecoveryPlan(
                primaryAction: .fixInput,
                alternativeActions: [.cancel],
                autoRetry: false,
                retryDelay: 0,
                userGuidance: "Please complete all required fields before saving."
            )
        case .cloudKitQuotaExceeded:
            let config = AppConfiguration.quotaExceededRetry
            return TripEditRecoveryPlan(
                primaryAction: .manageStorage,
                alternativeActions: [.upgradeStorage, .saveAsDraft, .cancel],
                autoRetry: false,
                retryDelay: config.baseDelay,
                userGuidance: "Your iCloud storage is full. Free up space or upgrade your plan to continue syncing."
            )
        default:
            let config = AppConfiguration.networkRetry
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.cancel],
                autoRetry: retryCount < 2,
                retryDelay: config.baseDelay,
                userGuidance: "An unexpected error occurred. Please try again."
            )
        }
    }
}

struct TripEditRecoveryPlan {
    let primaryAction: TripEditAction
    let alternativeActions: [TripEditAction]
    let autoRetry: Bool
    let retryDelay: TimeInterval
    let userGuidance: String
}

// MARK: - Error Analytics

enum TripEditErrorAnalytics {
    private static var errorHistory: [TripEditErrorEvent] = []
    private static let config = AppConfiguration.errorAnalytics
    private static var lastCleanup = Date()

    static func recordError(_ error: AppError, context: String, retryCount: Int) {
        // Perform periodic cleanup before adding new events
        cleanupStaleEventsIfNeeded()

        let event = TripEditErrorEvent(
            errorCategory: error.category,
            errorType: TripEditErrorType.from(error),
            context: context,
            retryCount: retryCount,
            timestamp: Date()
        )
        errorHistory.append(event)

        // Keep only the most recent events
        if errorHistory.count > config.maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - config.maxHistorySize)
        }

        #if DEBUG
        Logger.secure(category: .app).debug("TripEditErrorAnalytics: Recorded error \(error) in context \(context, privacy: .public)")
        #endif
    }

    static func getErrorPatterns() -> [String] {
        cleanupStaleEventsIfNeeded()
        let recentErrors = errorHistory.suffix(10)
        var patterns: [String] = []

        // Detect rapid consecutive errors
        if recentErrors.count >= config.minPatternCount {
            let timeSpan = recentErrors.last!.timestamp.timeIntervalSince(recentErrors.first!.timestamp)
            if timeSpan < config.rapidErrorWindow {
                patterns.append("rapid_consecutive_errors")
            }
        }

        // Detect repeated error types
        let errorTypes = recentErrors.map { $0.errorCategory }
        if Set(errorTypes).count == 1 && errorTypes.count >= config.minPatternCount {
            patterns.append("repeated_\(errorTypes.first!)")
        }

        return patterns
    }

    /// Manually trigger cleanup for testing or when memory pressure is detected
    static func cleanup() {
        let cutoffDate = Date().addingTimeInterval(-config.maxEventAge)
        errorHistory.removeAll { $0.timestamp < cutoffDate }
        lastCleanup = Date()
    }

    /// Reset all analytics state - useful for testing
    static func reset() {
        errorHistory.removeAll()
        lastCleanup = Date()
    }

    /// Get current analytics state for debugging
    static func getAnalyticsState() -> TripEditAnalyticsState {
        cleanupStaleEventsIfNeeded()
        return TripEditAnalyticsState(
            eventCount: errorHistory.count,
            oldestEventAge: errorHistory.first?.timestamp.timeIntervalSinceNow.magnitude,
            newestEventAge: errorHistory.last?.timestamp.timeIntervalSinceNow.magnitude,
            lastCleanup: lastCleanup
        )
    }

    private static func cleanupStaleEventsIfNeeded() {
        let now = Date()

        // Only cleanup if enough time has passed since last cleanup
        guard now.timeIntervalSince(lastCleanup) > config.cleanupInterval else { return }

        let cutoffDate = now.addingTimeInterval(-config.maxEventAge)
        let originalCount = errorHistory.count

        errorHistory.removeAll { $0.timestamp < cutoffDate }
        lastCleanup = now

        #if DEBUG
        let removedCount = originalCount - errorHistory.count
        if removedCount > 0 {
            Logger.secure(category: .app).debug("TripEditErrorAnalytics: Cleaned up \(removedCount) stale error events")
        }
        #endif
    }
}

/// Lightweight error event that stores only essential data to reduce memory footprint
struct TripEditErrorEvent {
    let errorCategory: Logger.Category
    let errorType: TripEditErrorType
    let context: String
    let retryCount: Int
    let timestamp: Date
}

/// Simplified error type enum to avoid holding full AppError instances
enum TripEditErrorType: String, CaseIterable {
    case database = "database"
    case network = "network"
    case cloudKit = "cloudKit"
    case fileSystem = "fileSystem"
    case validation = "validation"
    case organization = "organization"
    case importExport = "importExport"
    case unknown = "unknown"

    static func from(_ error: AppError) -> TripEditErrorType {
        switch error {
        case .databaseSaveFailed, .databaseLoadFailed, .databaseDeleteFailed,
             .databaseCorrupted, .relationshipIntegrityError:
            return .database
        case .networkUnavailable, .serverError, .timeoutError, .invalidURL:
            return .network
        case .cloudKitUnavailable, .cloudKitQuotaExceeded, .cloudKitSyncFailed, .cloudKitAuthenticationFailed:
            return .cloudKit
        case .fileNotFound, .filePermissionDenied, .fileCorrupted, .diskSpaceInsufficient, .fileAlreadyExists:
            return .fileSystem
        case .invalidInput, .missingRequiredField, .duplicateEntry, .invalidDateRange:
            return .validation
        case .organizationInUse, .cannotDeleteNoneOrganization, .organizationNotFound:
            return .organization
        case .importFailed, .exportFailed, .invalidFileFormat, .corruptedImportData:
            return .importExport
        case .unknown, .operationCancelled, .featureNotAvailable:
            return .unknown
        }
    }
}

/// Analytics state for debugging and monitoring
struct TripEditAnalyticsState {
    let eventCount: Int
    let oldestEventAge: TimeInterval?
    let newestEventAge: TimeInterval?
    let lastCleanup: Date
}

// MARK: - User Feedback Components

struct TripEditErrorBanner: View {
    let errorState: TripEditErrorState
    let onAction: (TripEditAction) -> Void

    var body: some View {
        InlineErrorRecoveryView(errorState: errorState, onAction: onAction)
            .padding(.horizontal)
            .onAppear {
                announceErrorIfNeeded()
            }
    }

    private func announceErrorIfNeeded() {
        let shouldAnnounce = shouldAnnounceImmediately(for: errorState.error)

        if shouldAnnounce {
            let announcement = "\(errorAccessibilityLabel). \(errorState.userMessage)"

            // Use UIAccessibility to announce the error
            #if canImport(UIKit)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: announcement
                )
            }
            #endif
        }
    }

    private func shouldAnnounceImmediately(for error: AppError) -> Bool {
        switch error {
        case .networkUnavailable, .databaseSaveFailed, .cloudKitQuotaExceeded:
            return true
        case .invalidInput, .invalidDateRange, .missingRequiredField:
            return false
        default:
            return true
        }
    }

    private var errorAccessibilityLabel: String {
        switch errorState.error.category {
        case .network:
            return "Network Error"
        case .database:
            return "Critical Error"
        case .app:
            return "Validation Error"
        case .cloudKit:
            return "CloudKit Error"
        default:
            return "Error"
        }
    }
}

// MARK: - Error State Persistence

extension TripEditErrorState {
    func persist() -> Data? {
        try? JSONEncoder().encode(PersistableTripEditErrorState(from: self))
    }

    static func restore(from data: Data) -> TripEditErrorState? {
        guard let persistable = try? JSONDecoder().decode(PersistableTripEditErrorState.self, from: data) else {
            return nil
        }
        return persistable.toTripEditErrorState()
    }
}

private struct PersistableTripEditErrorState: Codable {
    let errorDescription: String
    let retryCount: Int
    let canRetry: Bool
    let userMessage: String
    let actionNames: [String]
    let timestamp: Date

    init(from state: TripEditErrorState) {
        self.errorDescription = state.error.localizedDescription
        self.retryCount = state.retryCount
        self.canRetry = state.canRetry
        self.userMessage = state.userMessage
        self.actionNames = state.suggestedActions.map(\.displayName)
        self.timestamp = state.timestamp
    }

    func toTripEditErrorState() -> TripEditErrorState {
        // Convert back to TripEditErrorState
        // Note: We lose the original AppError, so we create a generic one
        let genericError = AppError.unknown(errorDescription)
        let actions = actionNames.compactMap { name in
            TripEditAction.allCases.first { $0.displayName == name }
        }

        return TripEditErrorState(
            error: genericError,
            retryCount: retryCount,
            canRetry: canRetry,
            userMessage: userMessage,
            suggestedActions: actions
        )
    }
}

// MARK: - Main Error Handling Type

enum TripEditErrorHandling {
    // Main error handling logic placeholder
    // This enum provides the file name match for SwiftLint
}
