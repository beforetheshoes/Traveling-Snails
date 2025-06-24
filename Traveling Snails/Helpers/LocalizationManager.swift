//
//  LocalizationManager.swift
//  Traveling Snails
//
//

import SwiftUI
import Combine

// MARK: - Localization Manager

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    
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
        
        // Log missing translations for debugging
        if value == key && defaultValue == nil {
            Logger.shared.warning("Missing localization for key: \(key)", category: .app)
        }
        
        return value
    }
    
    private func getHardcodedTranslation(for key: String) -> String? {
        // Hardcoded fallbacks for critical UI text
        switch key {
        case "file_attachments.title":
            return "Attachments"
        case "file_attachments.no_attachments":
            return "No attachments yet"
        case "file_attachments.no_attachments_description":
            return "Add files to keep them with this activity"
        case "file_attachments.add_attachment":
            return "Add Attachment"
        case "general.cancel":
            return "Cancel"
        case "general.save":
            return "Save"
        case "general.edit":
            return "Edit"
        case "general.delete":
            return "Delete"
        case "general.untitled":
            return "Untitled"
        default:
            return nil
        }
    }
    
    func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Localization Keys Enum

enum L10n {
    // MARK: - General
    enum General {
        static let cancel = "general.cancel"
        static let save = "general.save"
        static let delete = "general.delete"
        static let edit = "general.edit"
        static let add = "general.add"
        static let done = "general.done"
        static let ok = "general.ok"
        static let yes = "general.yes"
        static let no = "general.no"
        static let search = "general.search"
        static let clear = "general.clear"
        static let loading = "general.loading"
        static let error = "general.error"
        static let warning = "general.warning"
        static let info = "general.info"
        static let none = "general.none"
        static let unknown = "general.unknown"
        static let untitled = "general.untitled"
    }
    
    // MARK: - Navigation
    enum Navigation {
        static let trips = "navigation.trips"
        static let organizations = "navigation.organizations"
        static let files = "navigation.files"
        static let settings = "navigation.settings"
        static let debug = "navigation.debug"
        static let back = "navigation.back"
        static let close = "navigation.close"
    }
    
    // MARK: - Trips
    enum Trips {
        static let title = "trips.title"
        static let emptyState = "trips.empty_state"
        static let emptyStateDescription = "trips.empty_state_description"
        static let addTrip = "trips.add_trip"
        static let editTrip = "trips.edit_trip"
        static let deleteTrip = "trips.delete_trip"
        static let tripName = "trips.name"
        static let tripNotes = "trips.notes"
        static let startDate = "trips.start_date"
        static let endDate = "trips.end_date"
        static let totalCost = "trips.total_cost"
        static let totalActivities = "trips.total_activities"
        static let searchPlaceholder = "trips.search_placeholder"
        static let dateRange = "trips.date_range"
        static let noDatesSet = "trips.no_dates_set"
        
        enum Activities {
            static let transportation = "trips.activities.transportation"
            static let lodging = "trips.activities.lodging"
            static let activities = "trips.activities.activities"
            static let addActivity = "trips.activities.add_activity"
            static let noActivities = "trips.activities.no_activities"
        }
    }
    
    // MARK: - Organizations
    enum Organizations {
        static let title = "organizations.title"
        static let emptyState = "organizations.empty_state"
        static let emptyStateDescription = "organizations.empty_state_description"
        static let addOrganization = "organizations.add_organization"
        static let editOrganization = "organizations.edit_organization"
        static let deleteOrganization = "organizations.delete_organization"
        static let name = "organizations.name"
        static let phone = "organizations.phone"
        static let email = "organizations.email"
        static let website = "organizations.website"
        static let address = "organizations.address"
        static let searchPlaceholder = "organizations.search_placeholder"
        static let cannotDeleteInUse = "organizations.cannot_delete_in_use"
        static let cannotDeleteNone = "organizations.cannot_delete_none"
        
        enum Usage {
            static let usedBy = "organizations.usage.used_by"
            static let transportCount = "organizations.usage.transport_count"
            static let lodgingCount = "organizations.usage.lodging_count"
            static let activityCount = "organizations.usage.activity_count"
        }
    }
    
    // MARK: - Activities
    enum Activities {
        static let name = "activities.name"
        static let start = "activities.start"
        static let end = "activities.end"
        static let cost = "activities.cost"
        static let notes = "activities.notes"
        static let organization = "activities.organization"
        static let confirmation = "activities.confirmation"
        static let reservation = "activities.reservation"
        static let paid = "activities.paid"
        static let duration = "activities.duration"
        static let location = "activities.location"
        static let customLocation = "activities.custom_location"
        static let hideLocation = "activities.hide_location"
        static let attachments = "activities.attachments"
        
        enum Transportation {
            static let title = "activities.transportation.title"
            static let type = "activities.transportation.type"
            static let plane = "activities.transportation.plane"
            static let train = "activities.transportation.train"
            static let bus = "activities.transportation.bus"
            static let car = "activities.transportation.car"
            static let ship = "activities.transportation.ship"
            static let other = "activities.transportation.other"
        }
        
        enum Lodging {
            static let title = "activities.lodging.title"
            static let checkIn = "activities.lodging.check_in"
            static let checkOut = "activities.lodging.check_out"
        }
        
        enum Activity {
            static let title = "activities.activity.title"
        }
        
        enum Payment {
            static let none = "activities.payment.none"
            static let partial = "activities.payment.partial"
            static let full = "activities.payment.full"
        }
    }
    
    // MARK: - File Attachments
    enum FileAttachments {
        static let title = "file_attachments.title"
        static let addAttachment = "file_attachments.add_attachment"
        static let choosePhoto = "file_attachments.choose_photo"
        static let chooseDocument = "file_attachments.choose_document"
        static let noAttachments = "file_attachments.no_attachments"
        static let noAttachmentsDescription = "file_attachments.no_attachments_description"
        static let description = "file_attachments.description"
        static let originalName = "file_attachments.original_name"
        static let fileType = "file_attachments.file_type"
        static let fileSize = "file_attachments.file_size"
        static let createdDate = "file_attachments.created_date"
        static let editAttachment = "file_attachments.edit_attachment"
        static let deleteAttachment = "file_attachments.delete_attachment"
        
        enum Settings {
            static let title = "file_attachments.settings.title"
            static let management = "file_attachments.settings.management"
            static let storage = "file_attachments.settings.storage"
            static let fileTypes = "file_attachments.settings.file_types"
            static let totalFiles = "file_attachments.settings.total_files"
            static let totalSize = "file_attachments.settings.total_size"
            static let findOrphaned = "file_attachments.settings.find_orphaned"
            static let cleanupOrphaned = "file_attachments.settings.cleanup_orphaned"
            static let clearAll = "file_attachments.settings.clear_all"
            static let images = "file_attachments.settings.images"
            static let documents = "file_attachments.settings.documents"
            static let other = "file_attachments.settings.other"
        }
        
        enum Errors {
            static let failedToLoad = "file_attachments.errors.failed_to_load"
            static let failedToSave = "file_attachments.errors.failed_to_save"
            static let failedToDelete = "file_attachments.errors.failed_to_delete"
            static let invalidFormat = "file_attachments.errors.invalid_format"
            static let tooLarge = "file_attachments.errors.too_large"
        }
    }
    
    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"
        static let appearance = "settings.appearance"
        static let colorScheme = "settings.color_scheme"
        static let systemDefault = "settings.system_default"
        static let light = "settings.light"
        static let dark = "settings.dark"
        static let language = "settings.language"
        static let dataManagement = "settings.data_management"
        static let exportData = "settings.export_data"
        static let importData = "settings.import_data"
        static let clearData = "settings.clear_data"
        static let about = "settings.about"
        static let version = "settings.version"
        static let build = "settings.build"
        static let fileAttachmentSettings = "settings.file_attachment_settings"
        static let managementDescription = "settings.management_description"
        
        enum Import {
            static let title = "settings.import.title"
            static let selectFile = "settings.import.select_file"
            static let importing = "settings.import.importing"
            static let success = "settings.import.success"
            static let failed = "settings.import.failed"
            static let invalidFile = "settings.import.invalid_file"
            static let progress = "settings.import.progress"
        }
        
        enum Export {
            static let title = "settings.export.title"
            static let exporting = "settings.export.exporting"
            static let success = "settings.export.success"
            static let failed = "settings.export.failed"
            static let format = "settings.export.format"
            static let json = "settings.export.json"
            static let csv = "settings.export.csv"
        }
    }
    
    // MARK: - Errors
    enum Errors {
        static let title = "errors.title"
        static let unknown = "errors.unknown"
        static let networkUnavailable = "errors.network_unavailable"
        static let databaseError = "errors.database_error"
        static let fileError = "errors.file_error"
        static let validationError = "errors.validation_error"
        static let permissionDenied = "errors.permission_denied"
        static let diskSpaceFull = "errors.disk_space_full"
        static let operationCancelled = "errors.operation_cancelled"
        static let featureNotAvailable = "errors.feature_not_available"
        
        enum CloudKit {
            static let unavailable = "errors.cloudkit.unavailable"
            static let quotaExceeded = "errors.cloudkit.quota_exceeded"
            static let syncFailed = "errors.cloudkit.sync_failed"
            static let authenticationFailed = "errors.cloudkit.authentication_failed"
        }
        
        enum Recovery {
            static let restartApp = "errors.recovery.restart_app"
            static let checkConnection = "errors.recovery.check_connection"
            static let freeSpace = "errors.recovery.free_space"
            static let checkPermissions = "errors.recovery.check_permissions"
            static let contactSupport = "errors.recovery.contact_support"
            static let tryAgain = "errors.recovery.try_again"
        }
    }
    
    // MARK: - Validation
    enum Validation {
        static let required = "validation.required"
        static let invalidEmail = "validation.invalid_email"
        static let invalidURL = "validation.invalid_url"
        static let invalidPhone = "validation.invalid_phone"
        static let invalidDateRange = "validation.invalid_date_range"
        static let duplicateEntry = "validation.duplicate_entry"
        static let tooLong = "validation.too_long"
        static let tooShort = "validation.too_short"
        static let invalidFormat = "validation.invalid_format"
    }
    
    // MARK: - Time and Dates
    enum Time {
        static let now = "time.now"
        static let today = "time.today"
        static let yesterday = "time.yesterday"
        static let tomorrow = "time.tomorrow"
        static let thisWeek = "time.this_week"
        static let lastWeek = "time.last_week"
        static let nextWeek = "time.next_week"
        static let thisMonth = "time.this_month"
        static let lastMonth = "time.last_month"
        static let nextMonth = "time.next_month"
        static let duration = "time.duration"
        static let starts = "time.starts"
        static let ends = "time.ends"
        
        enum Units {
            static let seconds = "time.units.seconds"
            static let minutes = "time.units.minutes"
            static let hours = "time.units.hours"
            static let days = "time.units.days"
            static let weeks = "time.units.weeks"
            static let months = "time.units.months"
            static let years = "time.units.years"
        }
    }
    
    // MARK: - Database and Tools
    enum Database {
        static let title = "database.title"
        static let maintenance = "database.maintenance"
        static let compact = "database.compact"
        static let rebuild = "database.rebuild"
        static let validate = "database.validate"
        static let createTestData = "database.create_test_data"
        static let operations = "database.operations"
        static let browser = "database.browser"
        static let diagnostics = "database.diagnostics"
        static let repair = "database.repair"
        
        enum Status {
            static let healthy = "database.status.healthy"
            static let needsAttention = "database.status.needs_attention"
            static let corrupted = "database.status.corrupted"
            static let optimizing = "database.status.optimizing"
            static let repairing = "database.status.repairing"
        }
    }
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

// MARK: - Notification Extension

extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
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
        ("zh-Hant", "繁體中文")
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
        let _ = Mirror(reflecting: L10n.self) // Acknowledge unused mirror
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
