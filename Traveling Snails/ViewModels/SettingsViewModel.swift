//
//  SettingsViewModel.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
class SettingsViewModel {
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let appSettings = AppSettings.shared
    private let authManager = BiometricAuthManager.shared
    
    // UI State
    var showingDataBrowser = false
    var showingExportView = false
    var showingImportPicker = false
    var showingFileAttachmentSettings = false
    var showingImportProgress = false
    var showingDatabaseCleanup = false
    
    // Data management
    var importManager = DatabaseImportManager()
    var importResult: DatabaseImportManager.ImportResult?
    
    // Error handling
    var importError: String?
    var showingImportError = false
    
    // Organization cleanup feedback
    var showingOrganizationCleanupAlert = false
    var organizationCleanupMessage = ""
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Computed Properties
    
    var allTripsLocked: Bool {
        authManager.allTripsLocked
    }
    
    var colorScheme: ColorSchemePreference {
        get { appSettings.colorScheme }
        set { appSettings.colorScheme = newValue }
    }
    
    // Biometric authentication is now always enabled when available
    // Removed global setting - protection is per-trip only
    
    var canUseBiometrics: Bool {
        // Simple wrapper - the actual UI will handle the MainActor call
        true // We'll let the UI component handle the actual check
    }
    
    var biometricType: String {
        // Simple wrapper - the actual UI will handle the MainActor call
        "Touch ID" // Default fallback
    }
    
    var currentBiometricTimeout: TimeoutOption {
        let minutes = appSettings.biometricTimeoutMinutes
        let seconds = TimeInterval(minutes * 60)
        return TimeoutOption.from(seconds)
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // MARK: - Actions
    
    func openDataBrowser() {
        showingDataBrowser = true
    }
    
    func openExportView() {
        showingExportView = true
    }
    
    func openImportPicker() {
        showingImportPicker = true
    }
    
    func openFileAttachmentSettings() {
        showingFileAttachmentSettings = true
    }
    
    func openDatabaseCleanup() {
        showingDatabaseCleanup = true
    }
    
    func setBiometricTimeout(_ timeout: TimeoutOption) {
        let minutes = Int(timeout.rawValue / 60)
        appSettings.biometricTimeoutMinutes = minutes
    }
    
    func lockAllProtectedTrips() {
        Task { @MainActor in
            authManager.lockAllTrips()
        }
    }
    
    func cleanupNoneOrganizations() {
        let duplicatesRemoved = DataManagementService.cleanupNoneOrganizations(in: modelContext)
        
        if duplicatesRemoved > 0 {
            organizationCleanupMessage = "Successfully removed \(duplicatesRemoved) duplicate organization\(duplicatesRemoved == 1 ? "" : "s")"
        } else {
            organizationCleanupMessage = "No duplicate organizations found"
        }
        
        showingOrganizationCleanupAlert = true
    }
    
    func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            showingImportProgress = true
            
            Task {
                let result = await DataManagementService.importDatabase(
                    from: url,
                    using: importManager,
                    into: modelContext
                )
                
                await MainActor.run {
                    self.importResult = result
                    
                    // Post notification for progress view
                    NotificationCenter.default.post(
                        name: .importCompleted,
                        object: result
                    )
                }
            }
        case .failure(let error):
            Logger.shared.error("Import failed: \(error)")
            
            // Provide user-friendly error message
            let userFriendlyError = getUserFriendlyImportError(from: error)
            
            Task { @MainActor in
                self.importError = userFriendlyError
                self.showingImportError = true
            }
        }
    }
    
    // MARK: - Error Handling Helpers
    
    private func getUserFriendlyImportError(from error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSCocoaErrorDomain:
            switch nsError.code {
            case NSFileReadNoPermissionError:
                return "Permission denied. Please try selecting the file again through the import dialog."
            case NSFileReadNoSuchFileError:
                return "The selected file could not be found. It may have been moved or deleted."
            case NSFileReadCorruptFileError:
                return "The selected file appears to be corrupted and cannot be read."
            default:
                return "Unable to read the selected file. Please ensure you have permission to access it and try again."
            }
        case NSPOSIXErrorDomain:
            switch nsError.code {
            case Int(EACCES):
                return "Access denied. Please check that you have permission to read the selected file."
            case Int(ENOENT):
                return "File not found. Please ensure the file still exists at the selected location."
            default:
                return "A system error occurred while trying to access the file."
            }
        default:
            let description = error.localizedDescription.lowercased()
            if description.contains("permission") || description.contains("denied") {
                return "Permission denied. Please ensure you have access to the selected file and try again."
            } else if description.contains("not found") || description.contains("does not exist") {
                return "The selected file could not be found. Please try selecting it again."
            } else {
                return "An error occurred while importing: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - TimeoutOption

extension SettingsViewModel {
    enum TimeoutOption: TimeInterval, CaseIterable {
        case immediately = 0
        case fiveMinutes = 300
        case fifteenMinutes = 900
        case thirtyMinutes = 1800
        case oneHour = 3600
        case never = -1
        
        var displayName: String {
            switch self {
            case .immediately: return "Immediately"
            case .fiveMinutes: return "5 minutes"
            case .fifteenMinutes: return "15 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            case .never: return "Never"
            }
        }
        
        static func from(_ timeInterval: TimeInterval) -> TimeoutOption {
            return allCases.first { $0.rawValue == timeInterval } ?? .fifteenMinutes
        }
    }
}

// MARK: - DataManagementService

class DataManagementService {
    static func cleanupNoneOrganizations(in modelContext: ModelContext) -> Int {
        #if DEBUG
        Logger.shared.debug("Starting cleanup of None organizations...")
        #endif
        let duplicatesRemoved = Organization.cleanupDuplicateNoneOrganizations(in: modelContext)
        #if DEBUG
        Logger.shared.debug("None organization cleanup completed")
        #endif
        return duplicatesRemoved
    }
    
    static func importDatabase(
        from url: URL,
        using importManager: DatabaseImportManager,
        into modelContext: ModelContext
    ) async -> DatabaseImportManager.ImportResult {
        let result = await importManager.importDatabase(from: url, into: modelContext)
        
        #if DEBUG
        Logger.shared.debug("Import completed - Trips: \(result.tripsImported), Organizations: \(result.organizationsImported), Merged: \(result.organizationsMerged), Transportation: \(result.transportationImported), Lodging: \(result.lodgingImported), Activities: \(result.activitiesImported), Attachments: \(result.attachmentsImported)")
        #endif
        
        if !result.errors.isEmpty {
            Logger.shared.warning("Errors during import:")
            for error in result.errors {
                Logger.shared.warning("Import error: \(error)")
            }
        }
        
        return result
    }
}

