//
//  ModernAppSettings.swift
//  Traveling Snails
//
//

import Foundation
import Observation
import SwiftUI

/// Modern app settings using dependency injection
/// Replaces the singleton-based AppSettings for better testability
@Observable
class ModernAppSettings {
    // MARK: - Properties

    private let cloudStorageService: CloudStorageService?
    private let userDefaults: UserDefaults

    // MARK: - Keys
    private enum Keys {
        static let colorScheme = "colorScheme"
        static let biometricTimeoutMinutes = "biometricTimeoutMinutes"
    }

    // MARK: - Private backing storage
    private var _colorScheme: ColorSchemePreference = .system
    private var _biometricTimeoutMinutes: Int = 5

    // MARK: - Public @Observable properties
    var colorScheme: ColorSchemePreference {
        get { _colorScheme }
        set {
            _colorScheme = newValue
            saveColorScheme(newValue)
            Logger.shared.debug("ModernAppSettings.colorScheme set to: \(newValue)")
        }
    }

    var biometricTimeoutMinutes: Int {
        get { _biometricTimeoutMinutes }
        set {
            _biometricTimeoutMinutes = newValue
            saveBiometricTimeout(newValue)
            Logger.shared.debug("ModernAppSettings.biometricTimeoutMinutes set to: \(newValue)")
        }
    }

    // MARK: - Initialization

    /// Initialize with injected services
    /// - Parameters:
    ///   - cloudStorageService: Optional cloud storage service for syncing settings
    ///   - userDefaults: UserDefaults instance to use (defaults to .standard)
    init(cloudStorageService: CloudStorageService? = nil, userDefaults: UserDefaults = .standard) {
        self.cloudStorageService = cloudStorageService
        self.userDefaults = userDefaults

        Logger.shared.debug("ModernAppSettings initializing...")
        loadFromStorage()
        setupCloudNotifications()

        Logger.shared.debug("Loaded colorScheme: \(colorScheme)")
        Logger.shared.debug("Loaded biometricTimeout: \(biometricTimeoutMinutes)")
    }

    // MARK: - Private Implementation

    private func loadFromStorage() {
        // Load colorScheme
        if let stored = userDefaults.string(forKey: Keys.colorScheme),
           let preference = ColorSchemePreference(rawValue: stored) {
            _colorScheme = preference
        } else if let cloudService = cloudStorageService,
                  let cloud = cloudService.getString(forKey: Keys.colorScheme),
                  let preference = ColorSchemePreference(rawValue: cloud) {
            _colorScheme = preference
        } else {
            _colorScheme = .system
        }

        // Load biometricTimeoutMinutes
        let storedTimeout = userDefaults.integer(forKey: Keys.biometricTimeoutMinutes)
        if storedTimeout > 0 {
            _biometricTimeoutMinutes = storedTimeout
        } else if let cloudService = cloudStorageService {
            let cloudTimeout = cloudService.getInteger(forKey: Keys.biometricTimeoutMinutes)
            if cloudTimeout > 0 {
                _biometricTimeoutMinutes = cloudTimeout
            } else {
                _biometricTimeoutMinutes = 5
            }
        } else {
            _biometricTimeoutMinutes = 5
        }
    }

    private func saveColorScheme(_ scheme: ColorSchemePreference) {
        // Save to UserDefaults
        userDefaults.set(scheme.rawValue, forKey: Keys.colorScheme)

        // Save to cloud storage if available
        if let cloudService = cloudStorageService {
            cloudService.setString(scheme.rawValue, forKey: Keys.colorScheme)
            cloudService.synchronize()
        }
    }

    private func saveBiometricTimeout(_ timeout: Int) {
        // Save to UserDefaults
        userDefaults.set(timeout, forKey: Keys.biometricTimeoutMinutes)

        // Save to cloud storage if available
        if let cloudService = cloudStorageService {
            cloudService.setInteger(timeout, forKey: Keys.biometricTimeoutMinutes)
            cloudService.synchronize()
        }
    }

    private func setupCloudNotifications() {
        guard cloudStorageService != nil else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudStorageChanged(_:)),
            name: .cloudStorageDidChangeExternally,
            object: nil
        )
    }

    @objc private func cloudStorageChanged(_ notification: Notification) {
        Logger.shared.debug("Cloud storage changed notification received")

        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[CloudStorageNotificationKey.changedKeys] as? [String] else {
            return
        }

        Task { @MainActor in
            if changedKeys.contains(Keys.colorScheme) {
                if let cloudService = self.cloudStorageService,
                   let cloudValue = cloudService.getString(forKey: Keys.colorScheme),
                   let preference = ColorSchemePreference(rawValue: cloudValue),
                   preference != self._colorScheme {
                    Logger.shared.debug("External colorScheme change: \(self._colorScheme) → \(preference)")

                    // Update backing storage directly to avoid writing back to cloud
                    self._colorScheme = preference
                    // Also update UserDefaults
                    self.userDefaults.set(preference.rawValue, forKey: Keys.colorScheme)
                }
            }

            if changedKeys.contains(Keys.biometricTimeoutMinutes) {
                if let cloudService = self.cloudStorageService {
                    let cloudValue = cloudService.getInteger(forKey: Keys.biometricTimeoutMinutes)
                    if cloudValue > 0 && cloudValue != self._biometricTimeoutMinutes {
                        Logger.shared.debug("External biometricTimeout change: \(self._biometricTimeoutMinutes) → \(cloudValue)")

                        // Update backing storage directly to avoid writing back to cloud
                        self._biometricTimeoutMinutes = cloudValue
                        // Also update UserDefaults
                        self.userDefaults.set(cloudValue, forKey: Keys.biometricTimeoutMinutes)
                    }
                }
            }
        }
    }

    // MARK: - Debug Methods
    #if DEBUG
    func forceSyncTest() {
        guard let cloudService = cloudStorageService else {
            Logger.shared.debug("No cloud storage service available for sync test")
            return
        }

        Logger.shared.debug("Manual sync test...")
        let syncResult = cloudService.synchronize()
        Logger.shared.debug("Sync result: \(syncResult)")

        // Check current values
        let cloudValue = cloudService.getString(forKey: Keys.colorScheme)
        Logger.shared.debug("Current colorScheme value: \(colorScheme)")
        Logger.shared.debug("Direct cloud read: \(cloudValue ?? "nil")")

        // Check cloud availability
        Logger.shared.debug("Cloud storage available: \(cloudService.isAvailable)")
    }

    func reloadFromStorage() {
        Logger.shared.debug("Reloading from storage for test...")
        loadFromStorage()
        Logger.shared.debug("Reloaded colorScheme: \(colorScheme)")
        Logger.shared.debug("Reloaded biometricTimeout: \(biometricTimeoutMinutes)")
    }
    #endif

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenience Factory Methods

extension ModernAppSettings {
    /// Create app settings with production cloud storage service
    /// - Returns: Configured settings with production cloud service
    static func production() -> ModernAppSettings {
        ModernAppSettings(cloudStorageService: iCloudStorageService())
    }

    /// Create app settings from a service container
    /// - Parameter container: The service container to resolve from
    /// - Returns: Configured settings with service from container
    static func from(container: ServiceContainer) -> ModernAppSettings {
        let cloudService = container.tryResolve(CloudStorageService.self)
        return ModernAppSettings(cloudStorageService: cloudService)
    }

    /// Create app settings for testing (no cloud storage)
    /// - Parameter userDefaults: UserDefaults instance to use
    /// - Returns: Configured settings for testing
    static func testing(userDefaults: UserDefaults = .standard) -> ModernAppSettings {
        ModernAppSettings(cloudStorageService: nil, userDefaults: userDefaults)
    }
}
