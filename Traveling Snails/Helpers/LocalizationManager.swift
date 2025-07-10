//
//  LocalizationManager.swift
//  Traveling Snails
//
//

import Combine
import SwiftUI

// MARK: - Localization Manager

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    /// Enable/disable missing translation debug logging
    /// Set to true to log missing translations during development
    static var isLocalizationDebuggingEnabled: Bool = false

    private(set) var currentLanguage: String
    private var bundle: Bundle

    private init() {
        // Get the current language from user defaults or system
        let initialLanguage: String
        if let preferredLanguage = UserDefaults.standard.string(forKey: "app_language") {
            initialLanguage = preferredLanguage
        } else {
            initialLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        }

        // Initialize all stored properties
        self.currentLanguage = initialLanguage
        self.bundle = Self.loadBundle(for: initialLanguage)
    }

    private static func loadBundle(for language: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main // Fallback to main bundle
        }
        return bundle
    }

    func setLanguage(_ language: String) {
        guard language != currentLanguage else { return }

        currentLanguage = language
        bundle = Self.loadBundle(for: language)
        UserDefaults.standard.set(language, forKey: "app_language")

        // Post notification for app-wide language change
        NotificationCenter.default.post(name: .languageChanged, object: language)
    }

    func localizedString(for key: String, defaultValue: String? = nil) -> String {
        // Try the loaded bundle first
        var value = bundle.localizedString(forKey: key, value: nil, table: nil)

        // If not found and we're not already using main bundle, try main bundle
        if value == key && bundle != Bundle.main {
            value = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }

        // If still not found, try hardcoded values for file attachments as a fallback
        if value == key {
            value = getHardcodedTranslation(for: key) ?? defaultValue ?? key
        }

        // Log missing translations with dedicated localization debug flag
        #if DEBUG
        if value == key && defaultValue == nil && LocalizationManager.isLocalizationDebuggingEnabled {
            Logger.shared.debug("Missing localization for key: \(key)", category: .localization)
        }
        #endif

        return value
    }

    private func getHardcodedTranslation(for key: String) -> String? {
        // All strings now properly localized - no hardcoded fallbacks needed
        // This method remains for backwards compatibility but returns nil
        nil
    }

    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Localization Keys Base Enum
// Feature-specific keys are organized in separate extension files:
// - L10n+Errors.swift: Error messages and recovery suggestions
// - L10n+Trips.swift: Trips and Activities functionality
// - L10n+Organizations.swift: Organizations management
// - L10n+UI.swift: General UI, Navigation, Settings, FileAttachments
// - L10n+Data.swift: Database, Validation, Time, Operations

enum L10n {
    enum General {
        static let save = "general.save"
        static let cancel = "general.cancel"
        static let delete = "general.delete"
        static let edit = "general.edit"
        static let ok = "general.ok"
        static let error = "general.error"
        static let untitled = "general.untitled"
        static let info = "general.info"
        static let loading = "general.loading"
    }
    
    enum Errors {
        static let unknown = "errors.unknown"
        static let permissionDenied = "errors.permission_denied"
        static let networkOfflineLabel = "errors.network_offline_label"
        
        enum Database {
            static let saveFailed = "errors.database.save_failed"
            static let loadFailed = "errors.database.load_failed"
            static let deleteFailed = "errors.database.delete_failed"
            static let corrupted = "errors.database.corrupted"
            static let relationshipIntegrity = "errors.database.relationship_integrity"
        }
        
        enum File {
            static let notFound = "errors.file.not_found"
            static let permissionDenied = "errors.file.permission_denied"
            static let corrupted = "errors.file.corrupted"
            static let invalidFormat = "errors.file.invalid_format"
            static let sizeTooLarge = "errors.file.size_too_large"
            static let diskSpaceInsufficient = "errors.file.disk_space_insufficient"
            static let alreadyExists = "errors.file.already_exists"
        }
        
        enum Network {
            static let unavailable = "errors.network.unavailable"
            static let timeout = "errors.network.timeout"
            static let invalidResponse = "errors.network.invalid_response"
            static let unauthorized = "errors.network.unauthorized"
            static let serverError = "errors.network.server_error"
            static let invalidURL = "errors.network.invalid_url"
        }
        
        enum CloudKit {
            static let quotaExceeded = "errors.cloudkit.quota_exceeded"
            static let accountUnavailable = "errors.cloudkit.account_unavailable"
            static let syncFailed = "errors.cloudkit.sync_failed"
            static let shareUnavailable = "errors.cloudkit.share_unavailable"
            static let unavailable = "errors.cloudkit.unavailable"
            static let authenticationFailed = "errors.cloudkit.authentication_failed"
        }
        
        enum Import {
            static let invalidFile = "errors.import.invalid_file"
            static let unsupportedFormat = "errors.import.unsupported_format"
            static let dataCorrupted = "errors.import.data_corrupted"
            static let failed = "errors.import.failed"
            static let invalidFormat = "errors.import.invalid_format"
            static let corruptedData = "errors.import.corrupted_data"
        }
        
        enum Export {
            static let writeFailed = "errors.export.write_failed"
            static let failed = "errors.export.failed"
        }
        
        enum Validation {
            static let required = "errors.validation.required"
            static let invalidFormat = "errors.validation.invalid_format"
            static let outOfRange = "errors.validation.out_of_range"
            static let tooLong = "errors.validation.too_long"
            static let invalidInput = "errors.validation.invalid_input"
            static let missingRequiredField = "errors.validation.missing_required_field"
            static let duplicateEntry = "errors.validation.duplicate_entry"
            static let invalidDateRange = "errors.validation.invalid_date_range"
        }
        
        enum Organization {
            static let notFound = "errors.organization.not_found"
            static let cannotDelete = "errors.organization.cannot_delete"
            static let creationFailed = "errors.organization.creation_failed"
            static let inUse = "errors.organization.in_use"
            static let inUsePlural = "errors.organization.in_use_plural"
            static let cannotDeleteNone = "errors.organization.cannot_delete_none"
        }
        
        enum General {
            static let operationFailed = "errors.general.operation_failed"
            static let unexpectedError = "errors.general.unexpected_error"
            static let notImplemented = "errors.general.not_implemented"
            static let unknown = "errors.general.unknown"
            static let operationCancelled = "errors.general.operation_cancelled"
            static let featureNotAvailable = "errors.general.feature_not_available"
        }
        
        enum Recovery {
            static let tryAgain = "errors.recovery.try_again"
            static let checkConnection = "errors.recovery.check_connection"
            static let contactSupport = "errors.recovery.contact_support"
            static let restartApp = "errors.recovery.restart_app"
            static let checkPermissions = "errors.recovery.check_permissions"
            static let freeSpace = "errors.recovery.free_space"
            static let updateApp = "errors.recovery.update_app"
            static let reLogin = "errors.recovery.re_login"
            static let checkSettings = "errors.recovery.check_settings"
            static let restoreFromBackup = "errors.recovery.restore_from_backup"
            static let checkiCloudSettings = "errors.recovery.check_icloud_settings"
            static let upgradeiCloudStorage = "errors.recovery.upgrade_icloud_storage"
            static let ensureEndDateAfterStart = "errors.recovery.ensure_end_date_after_start"
            static let removeAssociatedItems = "errors.recovery.remove_associated_items"
        }
        
        enum Log {
            static let errorOccurred = "errors.log.error_occurred"
            static let details = "errors.log.details"
            static let technicalError = "errors.log.technical_error"
            static let genericUserMessage = "errors.log.generic_user_message"
        }
    }
    
    enum Settings {
        static let language = "settings.language"
        
        enum Import {
            static let failed = "settings.import.failed"
        }
    }
    
    enum File {
        static let selectFile = "file.select_file"
        static let noFileSelected = "file.no_file_selected"
        static let unsupportedType = "file.unsupported_type"
        static let tooLarge = "file.too_large"
        static let photoFailed = "file.photo_failed"
        static let documentFailed = "file.document_failed"
        static let selectionFailed = "file.selection_failed"
        static let databaseSaveFailed = "file.database_save_failed"
        static let accessFailed = "file.access_failed"
    }
    
    enum Database {
        static let cleanup = "database.cleanup"
        static let export = "database.export"
        
        enum Operations {
            static let cleanup = "database.operations.cleanup"
            static let resetFailed = "database.operations.reset_failed"
            static let cleanupFailed = "database.operations.cleanup_failed"
            static let exportFailed = "database.operations.export_failed"
        }
    }
    
    enum Save {
        static let activity = "save.activity"
        static let activityFailed = "save.activity_failed"
        static let failed = "save.failed"
        static let attachmentFailed = "save.attachment_failed"
        static let organizationFailed = "save.organization_failed"
    }
    
    enum FileAttachments {
        static let title = "file_attachments.title"
        static let noAttachments = "file_attachments.no_attachments"
        static let noAttachmentsDescription = "file_attachments.no_attachments_description"
    }
    
    enum Delete {
        static let attachment = "delete.attachment"
        static let failed = "delete.failed"
        static let organizationFailed = "delete.organization_failed"
        static let attachmentFailed = "delete.attachment_failed"
    }
    
    enum Validation {
        static let required = "validation.required"
        static let invalidDateRange = "validation.invalid_date_range"
        static let invalidPhone = "validation.invalid_phone"
        static let invalidEmail = "validation.invalid_email"
        static let invalidURL = "validation.invalid_url"
    }
    
    enum Trips {
        static let startDate = "trips.start_date"
        static let endDate = "trips.end_date"
        static let name = "trips.name"
        static let notes = "trips.notes"
        static let addTrip = "trips.add_trip"
        static let editTrip = "trips.edit_trip"
        static let tripName = "trips.trip_name"
        static let tripNotes = "trips.trip_notes"
        static let dateRange = "trips.date_range"
    }
    
    enum Organizations {
        static let name = "organizations.name"
        static let address = "organizations.address"
        static let phone = "organizations.phone"
        static let email = "organizations.email"
        static let website = "organizations.website"
        static let selectOrganization = "organizations.select_organization"
        static let createNew = "organizations.create_new"
        static let addOrganization = "organizations.add_organization"
        static let editOrganization = "organizations.edit_organization"
    }
    
    enum Activities {
        static let name = "activities.name"
        static let startDate = "activities.start_date"
        static let endDate = "activities.end_date"
        static let cost = "activities.cost"
        static let reservation = "activities.reservation"
        static let notes = "activities.notes"
        static let start = "activities.start"
        static let end = "activities.end"
        static let confirmation = "activities.confirmation"
    }
    
    // Base enum - specific feature keys are defined in extension files
    // This enum serves as the namespace for all localization keys
}

// MARK: - Localized String Function

/// Get a localized string for the given key
func L(_ key: String, defaultValue: String? = nil) -> String {
    LocalizationManager.shared.localizedString(for: key, defaultValue: defaultValue)
}

/// Get a localized string with format arguments
func L(_ key: String, _ arguments: CVarArg...) -> String {
    LocalizationManager.shared.localizedString(for: key, arguments: arguments)
}

// MARK: - SwiftUI Extensions

extension Text {
    /// Create a Text view with localized content
    init(localized key: String, defaultValue: String? = nil) {
        self.init(L(key, defaultValue: defaultValue))
    }

    /// Create a Text view with localized content and format arguments
    init(localized key: String, _ arguments: CVarArg...) {
        self.init(L(key, arguments))
    }
}

extension String {
    /// Get the localized version of this string (treating it as a key)
    var localized: String {
        L(self)
    }

    /// Get the localized version with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        L(self, arguments)
    }
}

// MARK: - View Modifier for Language Changes

struct LocalizationModifier: ViewModifier {
    @State private var localizationManager = LocalizationManager.shared
    @State private var languageChangeToken: AnyCancellable?

    func body(content: Content) -> some View {
        content
            .onAppear {
                // Listen for language changes
                languageChangeToken = NotificationCenter.default
                    .publisher(for: .languageChanged)
                    .sink { _ in
                        // Force view refresh by updating the manager reference
                        localizationManager = LocalizationManager.shared
                    }
            }
            .onDisappear {
                languageChangeToken?.cancel()
            }
    }
}

extension View {
    func handleLanguageChanges() -> some View {
        modifier(LocalizationModifier())
    }
}


// MARK: - Language Picker View

struct LanguagePicker: View {
    @State private var localizationManager = LocalizationManager.shared

    private let supportedLanguages = [
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("it", "Italiano"),
        ("pt", "Português"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
    ]

    var body: some View {
        Section {
            Picker(L(L10n.Settings.language), selection: Binding(
                get: { localizationManager.currentLanguage },
                set: { newLanguage in
                    localizationManager.setLanguage(newLanguage)
                }
            )) {
                ForEach(supportedLanguages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text(localized: L10n.Settings.language)
        } footer: {
            Text("Restart the app to fully apply language changes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Localizable.strings Content Generator

#if DEBUG
extension LocalizationManager {
    /// Generate a template Localizable.strings file with all keys
    func generateLocalizableStringsTemplate() -> String {
        _ = Mirror(reflecting: L10n.self) // Acknowledge unused mirror
        var output = "// Localizable.strings\n// Generated template\n\n"

        // This would need to be expanded to recursively traverse the nested enums
        // For now, here are some example entries:

        let keys = [
            // General
            ("general.cancel", "Cancel"),
            ("general.save", "Save"),
            ("general.delete", "Delete"),
            ("general.edit", "Edit"),
            ("general.add", "Add"),
            ("general.done", "Done"),
            ("general.ok", "OK"),
            ("general.yes", "Yes"),
            ("general.no", "No"),
            ("general.search", "Search"),
            ("general.clear", "Clear"),
            ("general.loading", "Loading..."),
            ("general.error", "Error"),
            ("general.warning", "Warning"),
            ("general.info", "Info"),
            ("general.none", "None"),
            ("general.unknown", "Unknown"),
            ("general.untitled", "Untitled"),

            // Navigation
            ("navigation.trips", "Trips"),
            ("navigation.organizations", "Organizations"),
            ("navigation.files", "Files"),
            ("navigation.settings", "Settings"),
            ("navigation.debug", "Debug"),
            ("navigation.back", "Back"),
            ("navigation.close", "Close"),

            // Trips
            ("trips.title", "Trips"),
            ("trips.empty_state", "No Trips"),
            ("trips.empty_state_description", "Create your first trip to get started"),
            ("trips.add_trip", "Add Trip"),
            ("trips.edit_trip", "Edit Trip"),
            ("trips.delete_trip", "Delete Trip"),
            ("trips.name", "Trip Name"),
            ("trips.notes", "Notes"),
            ("trips.start_date", "Start Date"),
            ("trips.end_date", "End Date"),
            ("trips.total_cost", "Total Cost"),
            ("trips.total_activities", "Total Activities"),
            ("trips.search_placeholder", "Search trips..."),
            ("trips.date_range", "Date Range"),
            ("trips.no_dates_set", "No dates set"),

            // Activities
            ("trips.activities.transportation", "Transportation"),
            ("trips.activities.lodging", "Lodging"),
            ("trips.activities.activities", "Activities"),
            ("trips.activities.add_activity", "Add Activity"),
            ("trips.activities.no_activities", "No activities yet"),

            // Organizations
            ("organizations.title", "Organizations"),
            ("organizations.empty_state", "No Organizations"),
            ("organizations.empty_state_description", "Add organizations to track your travel services"),
            ("organizations.add_organization", "Add Organization"),
            ("organizations.edit_organization", "Edit Organization"),
            ("organizations.delete_organization", "Delete Organization"),
            ("organizations.name", "Organization Name"),
            ("organizations.phone", "Phone"),
            ("organizations.email", "Email"),
            ("organizations.website", "Website"),
            ("organizations.address", "Address"),
            ("organizations.search_placeholder", "Search organizations..."),
            ("organizations.cannot_delete_in_use", "Cannot delete organization: it's being used by %d items"),
            ("organizations.cannot_delete_none", "Cannot delete the default 'None' organization"),

            // File Attachments
            ("file_attachments.title", "Attachments"),
            ("file_attachments.add_attachment", "Add Attachment"),
            ("file_attachments.choose_photo", "Choose Photo"),
            ("file_attachments.choose_document", "Choose Document"),
            ("file_attachments.no_attachments", "No Attachments"),
            ("file_attachments.no_attachments_description", "Add files to keep them with this activity"),
            ("file_attachments.description", "Description"),
            ("file_attachments.original_name", "Original Name"),
            ("file_attachments.file_type", "File Type"),
            ("file_attachments.file_size", "File Size"),
            ("file_attachments.created_date", "Created"),
            ("file_attachments.edit_attachment", "Edit Attachment"),
            ("file_attachments.delete_attachment", "Delete Attachment"),

            // Errors
            ("errors.title", "Error"),
            ("errors.unknown", "An unexpected error occurred"),
            ("errors.network_unavailable", "Network connection unavailable"),
            ("errors.database_error", "Database error occurred"),
            ("errors.file_error", "File operation failed"),
            ("errors.validation_error", "Validation failed"),
            ("errors.permission_denied", "Permission denied"),
            ("errors.disk_space_full", "Insufficient storage space"),
            ("errors.operation_cancelled", "Operation was cancelled"),
            ("errors.feature_not_available", "Feature not available"),
        ]

        for (key, value) in keys {
            output += "\"\(key)\" = \"\(value)\";\n"
        }

        return output
    }
}
#endif
