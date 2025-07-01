//
//  ErrorHandling.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

// MARK: - Application Errors

enum AppError: LocalizedError, Equatable {
    // Database errors
    case databaseSaveFailed(String)
    case databaseLoadFailed(String)
    case databaseDeleteFailed(String)
    case databaseCorrupted(String)
    case relationshipIntegrityError(String)

    // File system errors
    case fileNotFound(String)
    case filePermissionDenied(String)
    case fileCorrupted(String)
    case diskSpaceInsufficient
    case fileAlreadyExists(String)

    // Network errors
    case networkUnavailable
    case serverError(Int, String)
    case timeoutError
    case invalidURL(String)

    // CloudKit errors
    case cloudKitUnavailable
    case cloudKitQuotaExceeded
    case cloudKitSyncFailed(String)
    case cloudKitAuthenticationFailed

    // Import/Export errors
    case importFailed(String)
    case exportFailed(String)
    case invalidFileFormat(String)
    case corruptedImportData(String)

    // Validation errors
    case invalidInput(String)
    case missingRequiredField(String)
    case duplicateEntry(String)
    case invalidDateRange

    // Organization errors
    case organizationInUse(String, Int)
    case cannotDeleteNoneOrganization
    case organizationNotFound(String)

    // Generic errors
    case unknown(String)
    case operationCancelled
    case featureNotAvailable(String)

    var errorDescription: String? {
        switch self {
        case .databaseSaveFailed(let details):
            return "Failed to save data: \(details)"
        case .databaseLoadFailed(let details):
            return "Failed to load data: \(details)"
        case .databaseDeleteFailed(let details):
            return "Failed to delete data: \(details)"
        case .databaseCorrupted(let details):
            return "Database corruption detected: \(details)"
        case .relationshipIntegrityError(let details):
            return "Data relationship error: \(details)"

        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .filePermissionDenied(let path):
            return "Permission denied for file: \(path)"
        case .fileCorrupted(let path):
            return "File is corrupted: \(path)"
        case .diskSpaceInsufficient:
            return "Insufficient disk space"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"

        case .networkUnavailable:
            return "Network connection unavailable"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .timeoutError:
            return "Request timed out"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"

        case .cloudKitUnavailable:
            return "CloudKit is unavailable"
        case .cloudKitQuotaExceeded:
            return "CloudKit storage quota exceeded"
        case .cloudKitSyncFailed(let details):
            return "CloudKit sync failed: \(details)"
        case .cloudKitAuthenticationFailed:
            return "CloudKit authentication failed"

        case .importFailed(let details):
            return "Import failed: \(details)"
        case .exportFailed(let details):
            return "Export failed: \(details)"
        case .invalidFileFormat(let format):
            return "Invalid file format: \(format)"
        case .corruptedImportData(let details):
            return "Import data is corrupted: \(details)"

        case .invalidInput(let field):
            return "Invalid input for \(field)"
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .duplicateEntry(let item):
            return "Duplicate entry: \(item)"
        case .invalidDateRange:
            return "Invalid date range: end date must be after start date"

        case .organizationInUse(let name, let count):
            return "Cannot delete '\(name)'. It's used by \(count) items."
        case .cannotDeleteNoneOrganization:
            return "Cannot delete the default 'None' organization"
        case .organizationNotFound(let name):
            return "Organization not found: \(name)"

        case .unknown(let details):
            return "An unexpected error occurred: \(details)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .featureNotAvailable(let feature):
            return "Feature not available: \(feature)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .databaseSaveFailed, .databaseLoadFailed:
            return "Try restarting the app. If the problem persists, contact support."
        case .databaseCorrupted:
            return "Your data may be corrupted. Please restore from a backup if available."
        case .filePermissionDenied:
            return "Check file permissions and try again."
        case .diskSpaceInsufficient:
            return "Free up some storage space and try again."
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .cloudKitUnavailable:
            return "Check your iCloud settings and internet connection."
        case .cloudKitQuotaExceeded:
            return "Upgrade your iCloud storage plan or delete some data."
        case .invalidDateRange:
            return "Please ensure the end date is after the start date."
        case .organizationInUse:
            return "Remove all associated items before deleting this organization."
        default:
            return nil
        }
    }

    var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .timeoutError, .diskSpaceInsufficient,
             .invalidInput, .missingRequiredField, .invalidDateRange, .organizationInUse:
            return true
        case .databaseCorrupted, .fileCorrupted, .cloudKitAuthenticationFailed:
            return false
        default:
            return true
        }
    }

    var category: Logger.Category {
        switch self {
        case .databaseSaveFailed, .databaseLoadFailed, .databaseDeleteFailed,
             .databaseCorrupted, .relationshipIntegrityError:
            return .database
        case .fileNotFound, .filePermissionDenied, .fileCorrupted,
             .diskSpaceInsufficient, .fileAlreadyExists:
            return .fileAttachment
        case .networkUnavailable, .serverError, .timeoutError, .invalidURL:
            return .network
        case .cloudKitUnavailable, .cloudKitQuotaExceeded, .cloudKitSyncFailed, .cloudKitAuthenticationFailed:
            return .cloudKit
        case .importFailed, .corruptedImportData:
            return .dataImport
        case .exportFailed:
            return .export
        case .organizationInUse, .cannotDeleteNoneOrganization, .organizationNotFound:
            return .organization
        default:
            return .app
        }
    }
}

// MARK: - Error Result Type

typealias AppResult<T> = Result<T, AppError>

extension AppResult {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

// MARK: - Error Handler Protocol

protocol ErrorHandling {
    func handle(_ error: AppError, context: String?)
    func handle(_ error: Error, context: String?)
}

// MARK: - Centralized Error Message Formatting

private enum ErrorMessageFormatter {
    static func formatContext(_ context: String?) -> String {
        context.map { " Context: \($0)" } ?? ""
    }

    static func formatErrorMessage(_ error: Error, context: String?, prefix: String = "Error occurred") -> String {
        let contextString = formatContext(context)
        return "\(prefix)\(contextString): \(error.localizedDescription)"
    }

    static func formatAppErrorMessage(_ error: AppError, context: String?) -> String {
        formatErrorMessage(error, context: context, prefix: "AppError occurred")
    }

    static func formatUnmappedErrorMessage(_ error: Error, context: String?) -> String {
        formatErrorMessage(error, context: context, prefix: "Unmapped error occurred")
    }
}

// MARK: - Centralized Error Alert Creation

private enum ErrorAlertFactory {
    static func createAlert(for error: Error) -> ErrorAlert {
        ErrorAlert(id: UUID(), message: error.localizedDescription)
    }

    static func createAlert(for error: AppError) -> ErrorAlert {
        ErrorAlert(id: UUID(), message: error.localizedDescription)
    }
}

// MARK: - Default Error Handler

final class DefaultErrorHandler: ErrorHandling {
    private let logger = Logger.shared

    func handle(_ error: AppError, context: String? = nil) {
        logAppError(error, context: context)
    }

    func handle(_ error: Error, context: String? = nil) {
        // Convert to AppError if possible
        if let appError = error as? AppError {
            handle(appError, context: context)
            return
        }

        // Handle SwiftData errors
        if let nsError = error as NSError? {
            let appError = mapNSErrorToAppError(nsError)
            handle(appError, context: context)
            return
        }

        // Generic error handling
        logUnmappedError(error, context: context)
        let appError = AppError.unknown(error.localizedDescription)
        handle(appError, context: context)
    }

    // MARK: - Private Helper Methods

    private func logAppError(_ error: AppError, context: String?) {
        let message = ErrorMessageFormatter.formatAppErrorMessage(error, context: context)
        logger.log(message, category: error.category, level: error.isRecoverable ? .warning : .error)

        // Log recovery suggestion if available
        if let suggestion = error.recoverySuggestion {
            logger.log("Recovery suggestion: \(suggestion)", category: error.category, level: .info)
        }
    }

    private func logUnmappedError(_ error: Error, context: String?) {
        let message = ErrorMessageFormatter.formatUnmappedErrorMessage(error, context: context)
        logger.log(message, category: .app, level: .error)
    }

    private func mapNSErrorToAppError(_ error: NSError) -> AppError {
        switch error.domain {
        case "NSCocoaErrorDomain":
            switch error.code {
            case 4: // NSFileReadNoSuchFileError
                return .fileNotFound(error.localizedDescription)
            case 257: // NSFileReadNoPermissionError
                return .filePermissionDenied(error.localizedDescription)
            case 640: // NSFileWriteFileExistsError
                return .fileAlreadyExists(error.localizedDescription)
            default:
                return .unknown("Cocoa error: \(error.localizedDescription)")
            }
        case "CloudKitErrorDomain":
            return .cloudKitSyncFailed(error.localizedDescription)
        case "NSURLErrorDomain":
            switch error.code {
            case -1009: // NSURLErrorNotConnectedToInternet
                return .networkUnavailable
            case -1001: // NSURLErrorTimedOut
                return .timeoutError
            default:
                return .networkUnavailable
            }
        default:
            return .unknown("System error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Error Handling View Modifier

struct ErrorHandlingModifier: ViewModifier {
    @State private var errorAlert: ErrorAlert?
    private let errorHandler: ErrorHandling

    init(errorHandler: ErrorHandling = DefaultErrorHandler()) {
        self.errorHandler = errorHandler
    }

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .appErrorOccurred)) { notification in
                if let error = notification.object as? AppError,
                   let context = notification.userInfo?["context"] as? String {
                    handleError(error, context: context)
                } else if let error = notification.object as? Error,
                          let context = notification.userInfo?["context"] as? String {
                    handleError(error, context: context)
                }
            }
            .alert(item: $errorAlert) { errorAlert in
                Alert(
                    title: Text("Error"),
                    message: Text(errorAlert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    private func handleError(_ error: AppError, context: String?) {
        errorHandler.handle(error, context: context)

        // Show user-facing alert for non-recoverable errors
        if !error.isRecoverable {
            errorAlert = ErrorAlertFactory.createAlert(for: error)
        }
    }

    private func handleError(_ error: Error, context: String?) {
        errorHandler.handle(error, context: context)

        // Show generic error alert
        errorAlert = ErrorAlertFactory.createAlert(for: error)
    }
}

extension View {
    func handleErrors(with handler: ErrorHandling = DefaultErrorHandler()) -> some View {
        modifier(ErrorHandlingModifier(errorHandler: handler))
    }
}

// MARK: - Error Alert Model

private struct ErrorAlert: Identifiable {
    let id: UUID
    let message: String
}


extension NotificationCenter {
    func postError(_ error: AppError, context: String? = nil) {
        post(
            name: .appErrorOccurred,
            object: error,
            userInfo: context.map { ["context": $0] }
        )
    }

    func postError(_ error: Error, context: String? = nil) {
        post(
            name: .appErrorOccurred,
            object: error,
            userInfo: context.map { ["context": $0] }
        )
    }
}

// MARK: - Safe Operation Wrappers

extension ModelContext {
    /// Safely save the context with proper error handling
    func safeSave(context: String? = nil) -> AppResult<Void> {
        do {
            try save()
            Logger.shared.logDatabase("Context saved", details: context, success: true)
            return .success(())
        } catch {
            let appError = AppError.databaseSaveFailed(error.localizedDescription)
            Logger.shared.logDatabase("Context save failed", details: "\(context ?? "Unknown"): \(error)", success: false)
            return .failure(appError)
        }
    }

    /// Safely delete an object with proper error handling
    func safeDelete<T: PersistentModel>(_ object: T, context: String? = nil) -> AppResult<Void> {
        delete(object)
        return safeSave(context: context ?? "Deleting \(type(of: object))")
    }

    /// Safely insert an object with proper error handling
    func safeInsert<T: PersistentModel>(_ object: T, context: String? = nil) -> AppResult<Void> {
        insert(object)
        return safeSave(context: context ?? "Inserting \(type(of: object))")
    }
}

// MARK: - Result Extensions

extension Result where Failure == AppError {
    /// Handle the result by logging errors and optionally posting notifications
    func handleResult(
        context: String? = nil,
        postNotification: Bool = true,
        onSuccess: ((Success) -> Void)? = nil,
        onFailure: ((AppError) -> Void)? = nil
    ) {
        switch self {
        case .success(let value):
            onSuccess?(value)
        case .failure(let error):
            DefaultErrorHandler().handle(error, context: context)
            onFailure?(error)

            if postNotification {
                NotificationCenter.default.postError(error, context: context)
            }
        }
    }

    /// Convert to a throwing function
    func throwOnFailure() throws -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Async Error Handling

actor ErrorCollector {
    private var errors: [AppError] = []

    func add(_ error: AppError) {
        errors.append(error)
    }

    func add(_ error: Error) {
        if let appError = error as? AppError {
            errors.append(appError)
        } else {
            errors.append(.unknown(error.localizedDescription))
        }
    }

    func getErrors() -> [AppError] {
        errors
    }

    func clearErrors() {
        errors.removeAll()
    }

    func hasErrors() -> Bool {
        !errors.isEmpty
    }
}
