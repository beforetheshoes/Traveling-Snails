//
//  ActivitySubmitButton.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable submit button component for activity forms
struct ActivitySubmitButton: View {
    let title: String
    let isValid: Bool
    let isSaving: Bool
    let color: Color
    let saveError: Error?
    let recoveryActions: [TripEditAction]?
    let action: () -> Void
    let onRecoveryAction: ((TripEditAction) -> Void)?

    // Backward compatibility initializer
    init(
        title: String,
        isValid: Bool,
        isSaving: Bool,
        color: Color,
        saveError: Error?,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isValid = isValid
        self.isSaving = isSaving
        self.color = color
        self.saveError = saveError
        self.recoveryActions = nil
        self.action = action
        self.onRecoveryAction = nil
    }

    // Enhanced initializer with recovery actions
    init(
        title: String,
        isValid: Bool,
        isSaving: Bool,
        color: Color,
        saveError: Error?,
        recoveryActions: [TripEditAction]? = nil,
        action: @escaping () -> Void,
        onRecoveryAction: ((TripEditAction) -> Void)? = nil
    ) {
        self.title = title
        self.isValid = isValid
        self.isSaving = isSaving
        self.color = color
        self.saveError = saveError
        self.recoveryActions = recoveryActions
        self.action = action
        self.onRecoveryAction = onRecoveryAction
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: action) {
                HStack {
                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.trailing, 4)
                    }

                    Text(isSaving ? "Saving..." : title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isValid && !isSaving ? color : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isValid || isSaving)

            if let error = saveError {
                if let appError = error as? AppError, let actions = effectiveRecoveryActions {
                    // Use enhanced inline recovery view
                    InlineErrorRecoveryView(
                        errorState: TripEditErrorState(
                            error: appError,
                            retryCount: 0,
                            canRetry: actions.contains(.retry),
                            userMessage: contextualHelp,
                            suggestedActions: actions
                        )
                    ) { action in
                        handleRecoveryAction(action)
                    }
                } else {
                    // Fallback to original error display
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)

                        Text(L(L10n.Save.activityFailed))
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.bottom)
    }

    // MARK: - Computed Properties

    var effectiveRecoveryActions: [TripEditAction]? {
        recoveryActions ?? suggestedRecoveryActions
    }

    var suggestedRecoveryActions: [TripEditAction] {
        guard let appError = saveError as? AppError else { return [] }
        let plan = TripEditErrorRecovery.generateRecoveryPlan(for: appError, retryCount: 0)
        return [plan.primaryAction] + plan.alternativeActions
    }

    var contextualHelp: String {
        guard let appError = saveError as? AppError else { return "An error occurred" }

        switch appError {
        case .networkUnavailable:
            return "Network connection is unavailable. Try again or work offline."
        case .missingRequiredField(let field):
            return "Please complete the \(field) field before saving"
        case .invalidInput(let field):
            return "Please check the \(field) field for valid input"
        case .cloudKitQuotaExceeded:
            return "iCloud storage is full. Manage storage or upgrade plan."
        case .databaseSaveFailed:
            return "Failed to save activity. Your data is safe - try again."
        case .timeoutError:
            return "The request took too long. Try again or save as draft."
        default:
            return appError.localizedDescription
        }
    }

    var errorDetails: String {
        guard let appError = saveError as? AppError else { return "" }
        return appError.localizedDescription
    }

    var showsProgressiveDisclosure: Bool {
        guard let appError = saveError as? AppError else { return false }

        switch appError {
        case .databaseSaveFailed, .cloudKitSyncFailed, .importFailed, .exportFailed:
            return true
        default:
            return false
        }
    }

    var accessibilityLabel: String {
        guard let appError = saveError as? AppError else { return title }

        switch appError.category {
        case .network:
            return "\(title) - Network error"
        case .database:
            return "\(title) - Critical error"
        case .app:
            return "\(title) - Validation error"
        case .cloudKit:
            return "\(title) - CloudKit error"
        default:
            return "\(title) - Error"
        }
    }

    var accessibilityHint: String {
        if effectiveRecoveryActions?.isEmpty == false {
            return "recovery actions available"
        }
        return "Double tap to save"
    }

    // MARK: - Methods

    internal func handleRecoveryAction(_ action: TripEditAction) {
        onRecoveryAction?(action)
    }
}

#Preview {
    VStack(spacing: 30) {
        ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Lodging",
            isValid: false,
            isSaving: false,
            color: .green,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Transportation",
            isValid: true,
            isSaving: true,
            color: .orange,
            saveError: nil
        ) {}

        ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error message"])
        ) {}
    }
    .padding()
}
