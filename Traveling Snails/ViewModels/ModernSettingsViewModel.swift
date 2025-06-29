//
//  ModernSettingsViewModel.swift
//  Traveling Snails
//
//

import Foundation
import Observation
import SwiftData

/// Modern SettingsViewModel using dependency injection
/// Replaces singleton-based SettingsViewModel for better testability
@Observable
@MainActor
class ModernSettingsViewModel {
    // MARK: - Properties

    private let modelContext: ModelContext
    private let appSettings: ModernAppSettings
    private let authManager: ModernBiometricAuthManager
    private let authService: AuthenticationService
    private let cloudStorageService: CloudStorageService?

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

    /// Initialize with injected dependencies
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - appSettings: The app settings service
    ///   - authManager: The biometric authentication manager
    ///   - authService: The authentication service
    ///   - cloudStorageService: Optional cloud storage service
    init(
        modelContext: ModelContext,
        appSettings: ModernAppSettings,
        authManager: ModernBiometricAuthManager,
        authService: AuthenticationService,
        cloudStorageService: CloudStorageService? = nil
    ) {
        self.modelContext = modelContext
        self.appSettings = appSettings
        self.authManager = authManager
        self.authService = authService
        self.cloudStorageService = cloudStorageService
    }

    // MARK: - Computed Properties

    var allTripsLocked: Bool {
        authService.allTripsLocked
    }

    var colorScheme: ColorSchemePreference {
        get { appSettings.colorScheme }
        set { appSettings.colorScheme = newValue }
    }

    var canUseBiometrics: Bool {
        authService.canUseBiometrics()
    }

    var biometricType: String {
        switch authService.biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .none:
            return "None"
        }
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
        authService.lockAllTrips()
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

extension ModernSettingsViewModel {
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
            allCases.first { $0.rawValue == timeInterval } ?? .fifteenMinutes
        }
    }
}

// MARK: - Convenience Factory Methods

extension ModernSettingsViewModel {
    /// Create a ModernSettingsViewModel with production services
    /// - Parameter modelContext: The SwiftData model context
    /// - Returns: Configured view model with production services
    static func production(modelContext: ModelContext) -> ModernSettingsViewModel {
        let authService = ProductionAuthenticationService()
        let cloudStorageService = iCloudStorageService()
        let appSettings = ModernAppSettings(cloudStorageService: cloudStorageService)
        let authManager = ModernBiometricAuthManager(authService: authService)

        return ModernSettingsViewModel(
            modelContext: modelContext,
            appSettings: appSettings,
            authManager: authManager,
            authService: authService,
            cloudStorageService: cloudStorageService
        )
    }

    /// Create a ModernSettingsViewModel from a service container
    /// - Parameters:
    ///   - container: The service container to resolve from
    ///   - modelContext: The SwiftData model context
    /// - Returns: Configured view model with services from container
    static func from(container: ServiceContainer, modelContext: ModelContext) -> ModernSettingsViewModel {
        let authService = container.resolve(AuthenticationService.self)
        let cloudStorageService = container.tryResolve(CloudStorageService.self)
        let appSettings = ModernAppSettings(cloudStorageService: cloudStorageService)
        let authManager = ModernBiometricAuthManager(authService: authService)

        return ModernSettingsViewModel(
            modelContext: modelContext,
            appSettings: appSettings,
            authManager: authManager,
            authService: authService,
            cloudStorageService: cloudStorageService
        )
    }

    /// Create a ModernSettingsViewModel for testing
    /// - Parameters:
    ///   - modelContext: The SwiftData model context
    ///   - authService: Authentication service (typically a mock)
    ///   - cloudStorageService: Cloud storage service (typically a mock)
    /// - Returns: Configured view model for testing
    static func testing(
        modelContext: ModelContext,
        authService: AuthenticationService,
        cloudStorageService: CloudStorageService? = nil
    ) -> ModernSettingsViewModel {
        let appSettings = ModernAppSettings(cloudStorageService: cloudStorageService)
        let authManager = ModernBiometricAuthManager(authService: authService)

        return ModernSettingsViewModel(
            modelContext: modelContext,
            appSettings: appSettings,
            authManager: authManager,
            authService: authService,
            cloudStorageService: cloudStorageService
        )
    }
}
