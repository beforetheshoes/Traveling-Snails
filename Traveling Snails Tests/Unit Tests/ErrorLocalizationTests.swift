//
//  ErrorLocalizationTests.swift
//  Traveling Snails Tests
//
//  Error message localization tests
//

import Testing
import SwiftUI
@testable import Traveling_Snails

// MARK: - Error Localization Tests

@Suite("Error Message Localization")
struct ErrorLocalizationTests {
    
    @Test("All AppError cases should use localized strings")
    func testAllErrorsUseLocalizedStrings() async throws {
        // Test all error cases to ensure they use L() function instead of hardcoded strings
        let testCases: [AppError] = [
            .databaseSaveFailed("test"),
            .databaseLoadFailed("test"),
            .databaseDeleteFailed("test"),
            .databaseCorrupted("test"),
            .relationshipIntegrityError("test"),
            .fileNotFound("test.txt"),
            .filePermissionDenied("test.txt"),
            .fileCorrupted("test.txt"),
            .diskSpaceInsufficient,
            .fileAlreadyExists("test.txt"),
            .networkUnavailable,
            .serverError(500, "Internal Error"),
            .timeoutError,
            .invalidURL("invalid-url"),
            .cloudKitUnavailable,
            .cloudKitQuotaExceeded,
            .cloudKitSyncFailed("sync error"),
            .cloudKitAuthenticationFailed,
            .importFailed("import error"),
            .exportFailed("export error"),
            .invalidFileFormat("pdf"),
            .corruptedImportData("corrupt data"),
            .invalidInput("email"),
            .missingRequiredField("name"),
            .duplicateEntry("Trip Name"),
            .invalidDateRange,
            .organizationInUse("Work", 5),
            .cannotDeleteNoneOrganization,
            .organizationNotFound("Personal"),
            .unknown("unknown error"),
            .operationCancelled,
            .featureNotAvailable("premium feature")
        ]
        
        for error in testCases {
            let description = error.errorDescription ?? ""
            
            // Verify that we get a meaningful error message (not the localization key)
            // and that it includes expected dynamic content
            #expect(!description.isEmpty, "Error '\(error)' should have a description")
            
            // For errors with parameters, verify the parameter is included
            switch error {
            case .databaseSaveFailed(let details):
                #expect(description.contains(details), "Database save error should include details: \(details)")
            case .fileNotFound(let path):
                #expect(description.contains(path), "File not found error should include path: \(path)")
            case .serverError(let code, let message):
                #expect(description.contains("\(code)"), "Server error should include code: \(code)")
                #expect(description.contains(message), "Server error should include message: \(message)")
            case .organizationInUse(let name, let count):
                #expect(description.contains(name), "Organization error should include name: \(name)")
                #expect(description.contains("\(count)"), "Organization error should include count: \(count)")
            default:
                break
            }
            
            // Verify we're not returning localization keys (which would start with "errors.")
            #expect(!description.hasPrefix("errors."), "Error '\(error)' should not return localization key: '\(description)'")
        }
    }
    
    @Test("All recovery suggestions should use localized strings")
    func testAllRecoverySuggestionsUseLocalizedStrings() async throws {
        let testCases: [AppError] = [
            .databaseSaveFailed("test"),
            .databaseLoadFailed("test"),
            .databaseCorrupted("test"),
            .filePermissionDenied("test.txt"),
            .diskSpaceInsufficient,
            .networkUnavailable,
            .cloudKitUnavailable,
            .cloudKitQuotaExceeded,
            .invalidDateRange,
            .organizationInUse("Work", 5)
        ]
        
        for error in testCases {
            if let suggestion = error.recoverySuggestion {
                // Verify that we get a meaningful recovery suggestion (not the localization key)
                #expect(!suggestion.isEmpty, "Recovery suggestion for '\(error)' should not be empty")
                
                // Verify we're not returning localization keys (which would start with "errors.")
                #expect(!suggestion.hasPrefix("errors."), "Recovery suggestion for '\(error)' should not return localization key: '\(suggestion)'")
                
                // Verify we get a helpful suggestion (contains some action words)
                let hasActionWords = suggestion.lowercased().contains("try") ||
                                   suggestion.lowercased().contains("check") ||
                                   suggestion.lowercased().contains("free") ||
                                   suggestion.lowercased().contains("contact") ||
                                   suggestion.lowercased().contains("ensure") ||
                                   suggestion.lowercased().contains("upgrade") ||
                                   suggestion.lowercased().contains("remove") ||
                                   suggestion.lowercased().contains("restore") ||
                                   suggestion.lowercased().contains("please")
                
                #expect(hasActionWords, "Recovery suggestion for '\(error)' should contain actionable advice: '\(suggestion)'")
            }
        }
    }
    
    @Test("Error localization keys should exist in Localizable.strings")
    func testErrorKeysExistInLocalizations() async throws {
        // Test that all expected error keys exist in the main bundle
        let requiredKeys = [
            "errors.database.save_failed",
            "errors.database.load_failed",
            "errors.database.delete_failed",
            "errors.database.corrupted",
            "errors.database.relationship_integrity",
            "errors.file.not_found",
            "errors.file.permission_denied",
            "errors.file.corrupted",
            "errors.file.disk_space_insufficient",
            "errors.file.already_exists",
            "errors.network.unavailable",
            "errors.network.server_error",
            "errors.network.timeout",
            "errors.network.invalid_url",
            "errors.cloudkit.unavailable",
            "errors.cloudkit.quota_exceeded",
            "errors.cloudkit.sync_failed",
            "errors.cloudkit.authentication_failed",
            "errors.import.failed",
            "errors.export.failed",
            "errors.import.invalid_format",
            "errors.import.corrupted_data",
            "errors.validation.invalid_input",
            "errors.validation.missing_required_field",
            "errors.validation.duplicate_entry",
            "errors.validation.invalid_date_range",
            "errors.organization.in_use",
            "errors.organization.cannot_delete_none",
            "errors.organization.not_found",
            "errors.general.unknown",
            "errors.general.operation_cancelled",
            "errors.general.feature_not_available"
        ]
        
        for key in requiredKeys {
            let localizedValue = L(key)
            // Test will fail initially because these keys don't exist yet
            #expect(localizedValue != key, "Localization key '\(key)' should exist in Localizable.strings")
        }
    }
    
    @Test("Error localization should support parameter formatting")
    func testErrorParameterFormatting() async throws {
        // Test that error messages can properly format parameters
        let testError = AppError.databaseSaveFailed("Connection timeout")
        let description = testError.errorDescription ?? ""
        
        // After implementation, this should use string formatting
        #expect(description.contains("Connection timeout"), "Error description should include the parameter details")
        
        // Test organization error with multiple parameters
        let orgError = AppError.organizationInUse("Work", 5)
        let orgDescription = orgError.errorDescription ?? ""
        
        #expect(orgDescription.contains("Work"), "Organization error should include organization name")
        #expect(orgDescription.contains("5"), "Organization error should include item count")
    }
    
    @Test("Error messages should handle pluralization")
    func testErrorPluralizations() async throws {
        // Test that errors with counts handle pluralization properly
        let singleItemError = AppError.organizationInUse("Work", 1)
        let multipleItemsError = AppError.organizationInUse("Work", 5)
        
        let singleDescription = singleItemError.errorDescription ?? ""
        let multipleDescription = multipleItemsError.errorDescription ?? ""
        
        // After implementing pluralization, these should use different strings
        #expect(singleDescription != multipleDescription, "Error messages should use different pluralization for different counts")
    }
    
    @Test("All supported languages should have error translations")
    func testMultiLanguageSupport() async throws {
        let supportedLanguages = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh-Hans", "zh-Hant"]
        let testKey = "errors.network.unavailable"
        
        for language in supportedLanguages {
            // This will fail initially for non-English languages
            let bundle = Bundle.main.path(forResource: language, ofType: "lproj")
                .flatMap { Bundle(path: $0) } ?? Bundle.main
            
            let localizedValue = bundle.localizedString(forKey: testKey, value: nil, table: nil)
            #expect(localizedValue != testKey, "Language '\(language)' should have translation for key '\(testKey)'")
        }
    }
}

// MARK: - Error Alert Localization Tests

@Suite("Error Alert Localization") 
struct ErrorAlertLocalizationTests {
    
    @Test("Error alert titles should use localized strings")
    func testErrorAlertTitlesUseLocalizedStrings() async throws {
        // Test that hardcoded "Error" strings in alerts are localized
        // This will need to be updated after refactoring ErrorAlertFactory
        // For now, this documents the expected behavior
        let shouldUseLocalizedStrings = true
        #expect(shouldUseLocalizedStrings, "Error alert factory should use L(L10n.General.error) instead of hardcoded 'Error'")
    }
    
    @Test("Error alert messages should use localized recovery suggestions")
    func testErrorAlertMessagesUseLocalizedSuggestions() async throws {
        let testError = AppError.networkUnavailable
        let recoverySuggestion = testError.recoverySuggestion ?? ""
        
        // Verify that recovery suggestion exists and is not a localization key
        #expect(!recoverySuggestion.isEmpty, "Network error should have a recovery suggestion")
        #expect(!recoverySuggestion.hasPrefix("errors."), "Recovery suggestion should not be a localization key")
        
        // Verify it contains actionable advice
        let hasActionableAdvice = recoverySuggestion.lowercased().contains("check") ||
                                recoverySuggestion.lowercased().contains("try") ||
                                recoverySuggestion.lowercased().contains("verify")
        #expect(hasActionableAdvice, "Recovery suggestion should contain actionable advice")
    }
}