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
            return L(L10n.Errors.Database.saveFailed, details)
        case .databaseLoadFailed(let details):
            return L(L10n.Errors.Database.loadFailed, details)
        case .databaseDeleteFailed(let details):
            return L(L10n.Errors.Database.deleteFailed, details)
        case .databaseCorrupted(let details):
            return L(L10n.Errors.Database.corrupted, details)
        case .relationshipIntegrityError(let details):
            return L(L10n.Errors.Database.relationshipIntegrity, details)

        case .fileNotFound(let path):
            return L(L10n.Errors.File.notFound, path)
        case .filePermissionDenied(let path):
            return L(L10n.Errors.File.permissionDenied, path)
        case .fileCorrupted(let path):
            return L(L10n.Errors.File.corrupted, path)
        case .diskSpaceInsufficient:
            return L(L10n.Errors.File.diskSpaceInsufficient)
        case .fileAlreadyExists(let path):
            return L(L10n.Errors.File.alreadyExists, path)

        case .networkUnavailable:
            return L(L10n.Errors.Network.unavailable)
        case .serverError(let code, let message):
            return L(L10n.Errors.Network.serverError, code, message)
        case .timeoutError:
            return L(L10n.Errors.Network.timeout)
        case .invalidURL(let url):
            return L(L10n.Errors.Network.invalidURL, url)

        case .cloudKitUnavailable:
            return L(L10n.Errors.CloudKit.unavailable)
        case .cloudKitQuotaExceeded:
            return L(L10n.Errors.CloudKit.quotaExceeded)
        case .cloudKitSyncFailed(let details):
            return L(L10n.Errors.CloudKit.syncFailed, details)
        case .cloudKitAuthenticationFailed:
            return L(L10n.Errors.CloudKit.authenticationFailed)

        case .importFailed(let details):
            return L(L10n.Errors.Import.failed, details)
        case .exportFailed(let details):
            return L(L10n.Errors.Export.failed, details)
        case .invalidFileFormat(let format):
            return L(L10n.Errors.Import.invalidFormat, format)
        case .corruptedImportData(let details):
            return L(L10n.Errors.Import.corruptedData, details)

        case .invalidInput(let field):
            return L(L10n.Errors.Validation.invalidInput, field)
        case .missingRequiredField(let field):
            return L(L10n.Errors.Validation.missingRequiredField, field)
        case .duplicateEntry(let item):
            return L(L10n.Errors.Validation.duplicateEntry, item)
        case .invalidDateRange:
            return L(L10n.Errors.Validation.invalidDateRange)

        case .organizationInUse(let name, let count):
            // Use pluralization for better localization
            let key = count == 1 ? L10n.Errors.Organization.inUse : L10n.Errors.Organization.inUsePlural
            return L(key, name, count)
        case .cannotDeleteNoneOrganization:
            return L(L10n.Errors.Organization.cannotDeleteNone)
        case .organizationNotFound(let name):
            return L(L10n.Errors.Organization.notFound, name)

        case .unknown(let details):
            return L(L10n.Errors.General.unknown, details)
        case .operationCancelled:
            return L(L10n.Errors.General.operationCancelled)
        case .featureNotAvailable(let feature):
            return L(L10n.Errors.General.featureNotAvailable, feature)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .databaseSaveFailed, .databaseLoadFailed:
            return L(L10n.Errors.Recovery.restartApp)
        case .databaseCorrupted:
            return L(L10n.Errors.Recovery.restoreFromBackup)
        case .filePermissionDenied:
            return L(L10n.Errors.Recovery.checkPermissions)
        case .diskSpaceInsufficient:
            return L(L10n.Errors.Recovery.freeSpace)
        case .networkUnavailable:
            return L(L10n.Errors.Recovery.checkConnection)
        case .cloudKitUnavailable:
            return L(L10n.Errors.Recovery.checkiCloudSettings)
        case .cloudKitQuotaExceeded:
            return L(L10n.Errors.Recovery.upgradeiCloudStorage)
        case .invalidDateRange:
            return L(L10n.Errors.Recovery.ensureEndDateAfterStart)
        case .organizationInUse:
            return L(L10n.Errors.Recovery.removeAssociatedItems)
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
        // Log the technical details but show generic message to user
        Logger.shared.error(L(L10n.Errors.Log.technicalError, error.localizedDescription), category: .app)

        // Show generic user-friendly message
        let userMessage = L(L10n.Errors.Log.genericUserMessage)
        return ErrorAlert(id: UUID(), message: userMessage)
    }

    static func createAlert(for error: AppError) -> ErrorAlert {
        // Log the technical details
        Logger.shared.error("AppError alert created: \(error.localizedDescription)", category: error.category)

        // Use AppError's user-friendly message or fallback to localized generic
        let userMessage = error.recoverySuggestion ?? L(L10n.Errors.Recovery.tryAgain)
        return ErrorAlert(id: UUID(), message: userMessage)
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
                    title: Text(L(L10n.General.error)),
                    message: Text(errorAlert.message),
                    dismissButton: .default(Text(L(L10n.General.ok)))
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
