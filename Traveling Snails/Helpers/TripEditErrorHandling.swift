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
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
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
            return TripEditRecoveryPlan(
                primaryAction: .workOffline,
                alternativeActions: [.retry, .cancel],
                autoRetry: retryCount <= 2,
                retryDelay: pow(2.0, Double(retryCount)), // Exponential backoff
                userGuidance: "Your changes will be saved locally and synced when you're back online."
            )
        case .timeoutError:
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.saveAsDraft, .cancel],
                autoRetry: retryCount <= 3,
                retryDelay: 2.0,
                userGuidance: "The operation took too long. Retrying may help."
            )
        case .databaseSaveFailed:
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.saveAsDraft, .cancel],
                autoRetry: retryCount <= 2,
                retryDelay: 1.0,
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
            return TripEditRecoveryPlan(
                primaryAction: .manageStorage,
                alternativeActions: [.upgradeStorage, .saveAsDraft, .cancel],
                autoRetry: false,
                retryDelay: 0,
                userGuidance: "Your iCloud storage is full. Free up space or upgrade your plan to continue syncing."
            )
        default:
            return TripEditRecoveryPlan(
                primaryAction: .retry,
                alternativeActions: [.cancel],
                autoRetry: retryCount <= 1,
                retryDelay: 2.0,
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

    static func recordError(_ error: AppError, context: String, retryCount: Int) {
        let event = TripEditErrorEvent(
            error: error,
            context: context,
            retryCount: retryCount,
            timestamp: Date()
        )
        errorHistory.append(event)

        // Keep only last 100 events
        if errorHistory.count > 100 {
            errorHistory.removeFirst(errorHistory.count - 100)
        }

        #if DEBUG
        Logger.secure(category: .app).debug("TripEditErrorAnalytics: Recorded error \(error) in context \(context, privacy: .public)")
        #endif
    }

    static func getErrorPatterns() -> [String] {
        let recentErrors = errorHistory.suffix(10)
        var patterns: [String] = []

        // Detect rapid consecutive errors
        if recentErrors.count >= 3 {
            let timeSpan = recentErrors.last!.timestamp.timeIntervalSince(recentErrors.first!.timestamp)
            if timeSpan < 60 { // Within 1 minute
                patterns.append("rapid_consecutive_errors")
            }
        }

        // Detect repeated error types
        let errorTypes = recentErrors.map { $0.error.category }
        if Set(errorTypes).count == 1 && errorTypes.count >= 3 {
            patterns.append("repeated_\(errorTypes.first!)")
        }

        return patterns
    }
}

struct TripEditErrorEvent {
    let error: AppError
    let context: String
    let retryCount: Int
    let timestamp: Date
}

// MARK: - User Feedback Components

struct TripEditErrorBanner: View {
    let errorState: TripEditErrorState
    let onAction: (TripEditAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .accessibilityLabel("Error")
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorState.userMessage)
                        .font(.caption)
                        .foregroundColor(.primary)
                    if errorState.canRetry {
                        Text("Retry attempt \(errorState.retryCount)/3")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            if !errorState.suggestedActions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(errorState.suggestedActions.prefix(3), id: \.self) { action in
                        Button(action.displayName) {
                            onAction(action)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
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
