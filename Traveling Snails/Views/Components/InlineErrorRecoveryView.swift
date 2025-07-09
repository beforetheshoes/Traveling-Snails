//
//  InlineErrorRecoveryView.swift
//  Traveling Snails
//
//  Inline error recovery view with progressive disclosure
//

import SwiftUI

struct InlineErrorRecoveryView: View {
    let errorState: TripEditErrorState
    let onAction: (TripEditAction) -> Void

    @State internal var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Basic error display
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .accessibilityLabel(errorAccessibilityLabel)

                VStack(alignment: .leading, spacing: 4) {
                    Text(errorState.userMessage)
                        .font(.caption)
                        .foregroundColor(.primary)

                    if errorState.canRetry {
                        Text("Retry attempt \(errorState.retryCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if canExpand {
                    Button(action: { toggleExpansion() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(isExpanded ? "Collapse details" : "Expand details")
                }
            }

            // Inline recovery actions
            if !inlineActions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(inlineActions, id: \.displayName) { action in
                        Button(action.displayName) {
                            handleAction(action)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                        .accessibilityLabel(action.displayName)
                        .accessibilityHint(accessibilityHint(for: action))
                    }
                    Spacer()
                }
            }

            // Progressive disclosure content
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Technical details:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(expandedContent)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)

                    if !contextualHelp.isEmpty {
                        Text("Suggested solutions:")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        Text(contextualHelp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Computed Properties

    var canExpand: Bool {
        true // Always expandable for technical details
    }

    var inlineActions: [TripEditAction] {
        errorState.suggestedActions
    }

    var expandedContent: String {
        switch errorState.error {
        case .databaseSaveFailed(let details):
            return "Database error: \(details)"
        case .networkUnavailable:
            return "Network connection is not available"
        case .timeoutError:
            return "The request took too long to complete"
        case .cloudKitQuotaExceeded:
            return "iCloud storage quota has been exceeded"
        case .invalidInput(let field):
            return "Invalid input provided for: \(field)"
        case .missingRequiredField(let field):
            return "Required field is missing: \(field)"
        default:
            return "An unexpected error occurred"
        }
    }

    var contextualHelp: String {
        switch errorState.error {
        case .cloudKitQuotaExceeded:
            return "Free up space in iCloud storage or upgrade your plan to continue syncing your data."
        case .networkUnavailable:
            return "Check your internet connection and try again, or work offline until connection is restored."
        case .invalidInput, .missingRequiredField:
            return "Please review the highlighted fields and correct any errors before saving."
        case .databaseSaveFailed:
            return "Your data is safe. This is usually temporary - try saving again."
        case .timeoutError:
            return "The operation may succeed if you try again, or save as draft to avoid losing changes."
        default:
            return "Try the suggested actions above to resolve this issue."
        }
    }

    var accessibilityLabel: String {
        switch errorState.error.category {
        case .network:
            return "Network error: \(errorState.userMessage)"
        case .database:
            return "Critical error: \(errorState.userMessage)"
        case .app:
            return "Validation error: \(errorState.userMessage)"
        case .cloudKit:
            return "CloudKit error: \(errorState.userMessage)"
        default:
            return "Error: \(errorState.userMessage)"
        }
    }

    var accessibilityHint: String {
        "Double tap to view recovery options"
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

    // MARK: - Methods

    internal func toggleExpansion() {
        isExpanded.toggle()
    }

    internal func handleAction(_ action: TripEditAction) {
        onAction(action)
    }

    private func accessibilityHint(for action: TripEditAction) -> String {
        switch action {
        case .retry:
            return "Attempts the operation again"
        case .workOffline:
            return "Continues working without network connection"
        case .saveAsDraft:
            return "Saves your changes locally"
        case .fixInput:
            return "Allows you to correct the input"
        case .manageStorage:
            return "Opens storage management options"
        case .upgradeStorage:
            return "Opens iCloud storage upgrade options"
        case .cancel:
            return "Dismisses the error and cancels the operation"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InlineErrorRecoveryView(
            errorState: TripEditErrorState(
                error: .networkUnavailable,
                retryCount: 1,
                canRetry: true,
                userMessage: "Network connection unavailable",
                suggestedActions: [.retry, .workOffline]
            )
        ) { action in
            Logger.shared.info("Action selected: \(action)", category: .ui)
        }

        InlineErrorRecoveryView(
            errorState: TripEditErrorState(
                error: .cloudKitQuotaExceeded,
                retryCount: 0,
                canRetry: false,
                userMessage: "iCloud storage full",
                suggestedActions: [.manageStorage, .upgradeStorage]
            )
        ) { action in
            Logger.shared.info("Action selected: \(action)", category: .ui)
        }
    }
    .padding()
}
