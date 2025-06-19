//
//  SettingsViewModel.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import Foundation
import SwiftData
import Observation

@Observable @MainActor
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
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Computed Properties
    
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
        let saved = UserDefaults.standard.double(forKey: "biometricTimeout")
        let current = saved > 0 ? saved : 900 // Default to 15 minutes
        return TimeoutOption.from(current)
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
        UserDefaults.standard.set(timeout.rawValue, forKey: "biometricTimeout")
    }
    
    func lockAllProtectedTrips() {
        Task { @MainActor in
            authManager.lockAllTrips()
        }
    }
    
    func cleanupNoneOrganizations() {
        DataManagementService.cleanupNoneOrganizations(in: modelContext)
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
            print("❌ Import failed: \(error)")
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
    static func cleanupNoneOrganizations(in modelContext: ModelContext) {
        print("🧹 Starting cleanup of None organizations...")
        Organization.cleanupDuplicateNoneOrganizations(in: modelContext)
        print("✅ None organization cleanup completed")
    }
    
    static func importDatabase(
        from url: URL,
        using importManager: DatabaseImportManager,
        into modelContext: ModelContext
    ) async -> DatabaseImportManager.ImportResult {
        let result = await importManager.importDatabase(from: url, into: modelContext)
        
        print("✅ Import completed with results:")
        print("  - Trips: \(result.tripsImported)")
        print("  - Organizations: \(result.organizationsImported)")
        print("  - Organizations merged: \(result.organizationsMerged)")
        print("  - Transportation: \(result.transportationImported)")
        print("  - Lodging: \(result.lodgingImported)")
        print("  - Activities: \(result.activitiesImported)")
        print("  - Attachments: \(result.attachmentsImported)")
        
        if !result.errors.isEmpty {
            print("⚠️ Errors during import:")
            for error in result.errors {
                print("  - \(error)")
            }
        }
        
        return result
    }
}

