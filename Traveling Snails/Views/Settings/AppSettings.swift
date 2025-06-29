//
//  AppSettings.swift
//  Traveling Snails
//
//

import Foundation
import Observation
import SwiftUI

// MARK: - Simple App Settings with direct @Observable properties
@Observable
class AppSettings {
    static let shared = AppSettings()

    // MARK: - Storage systems
    private var _ubiquitousStore: NSUbiquitousKeyValueStore?
    private var ubiquitousStore: NSUbiquitousKeyValueStore? {
        if _ubiquitousStore == nil {
            // Avoid creating NSUbiquitousKeyValueStore during testing to prevent hanging
            // CRITICAL: When test target imports this code, NSUbiquitousKeyValueStore operations can hang during build
            #if targetEnvironment(simulator) && DEBUG
            // In DEBUG simulator builds, always assume we might be testing and avoid iCloud
            _ubiquitousStore = nil
            #else
            let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                               NSClassFromString("XCTestCase") != nil ||
                               ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

            _ubiquitousStore = isRunningTests ? nil : NSUbiquitousKeyValueStore.default
            #endif
        }
        return _ubiquitousStore
    }
    private let userDefaults = UserDefaults.standard

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
            // Save to both stores
            userDefaults.set(newValue.rawValue, forKey: Keys.colorScheme)

            // Skip iCloud operations during testing to prevent hanging
            if let store = ubiquitousStore {
                store.set(newValue.rawValue, forKey: Keys.colorScheme)
                store.synchronize()
            }

            #if DEBUG
            #if DEBUG
            Logger.shared.debug("AppSettings.colorScheme set to: \(newValue)")
            #endif
            #endif
        }
    }

    var biometricTimeoutMinutes: Int {
        get { _biometricTimeoutMinutes }
        set {
            _biometricTimeoutMinutes = newValue
            // Save to both stores
            userDefaults.set(newValue, forKey: Keys.biometricTimeoutMinutes)

            // Skip iCloud operations during testing to prevent hanging
            if let store = ubiquitousStore {
                store.set(newValue, forKey: Keys.biometricTimeoutMinutes)
                store.synchronize()
            }

            #if DEBUG
            #if DEBUG
            Logger.shared.debug("AppSettings.biometricTimeoutMinutes set to: \(newValue)")
            #endif
            #endif
        }
    }

    // MARK: - Initialization
    private init() {
        #if DEBUG
        #if DEBUG
        Logger.shared.debug("AppSettings initializing...")
        #endif
        #endif

        loadFromStorage()

        // Skip iCloud setup during testing to prevent hanging
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            setupICloudNotifications()
        } else {
            #if DEBUG
            #if DEBUG
            Logger.shared.debug("Test environment detected, skipping iCloud setup")
            #endif
            #endif
        }

        #if DEBUG
        #if DEBUG
        Logger.shared.debug("Loaded colorScheme: \(colorScheme)")
        Logger.shared.debug("Loaded biometricTimeout: \(biometricTimeoutMinutes)")
        #endif
        #endif
    }

    private func loadFromStorage() {
        // Load colorScheme without triggering didSet
        if let stored = userDefaults.string(forKey: Keys.colorScheme),
           let preference = ColorSchemePreference(rawValue: stored) {
            _colorScheme = preference
        } else if let store = ubiquitousStore,
                  let cloud = store.string(forKey: Keys.colorScheme),
                  let preference = ColorSchemePreference(rawValue: cloud) {
            _colorScheme = preference
        } else {
            // Reset to default when both stores are empty or in test environment
            _colorScheme = .system
        }

        // Load biometricTimeoutMinutes without triggering didSet
        let storedTimeout = userDefaults.integer(forKey: Keys.biometricTimeoutMinutes)
        if storedTimeout > 0 {
            _biometricTimeoutMinutes = storedTimeout
        } else if let store = ubiquitousStore {
            let cloudTimeout = Int(store.longLong(forKey: Keys.biometricTimeoutMinutes))
            if cloudTimeout > 0 {
                _biometricTimeoutMinutes = cloudTimeout
            } else {
                // Reset to default when both stores are empty
                _biometricTimeoutMinutes = 5
            }
        } else {
            // In test environment, use default value
            _biometricTimeoutMinutes = 5
        }
    }

    private func setupICloudNotifications() {
        guard let store = ubiquitousStore else {
            #if DEBUG
            Logger.shared.debug("No ubiquitous store available for iCloud sync")
            #endif
            return
        }

        #if DEBUG
        Logger.shared.debug("Setting up iCloud notifications for store: \(store)")
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )

        // Force synchronization and check current values
        let syncResult = store.synchronize()
        #if DEBUG
        Logger.shared.debug("Initial iCloud sync result: \(syncResult)")
        let currentCloudScheme = store.string(forKey: Keys.colorScheme)
        Logger.shared.debug("Current cloud colorScheme: \(currentCloudScheme ?? "nil")")
        Logger.shared.debug("Current local colorScheme: \(_colorScheme.rawValue)")
        #endif

        // Set up periodic sync check as backup - more frequent on Mac Catalyst due to notification issues
        #if targetEnvironment(macCatalyst)
        Logger.shared.warning("Mac Catalyst detected - using enhanced polling for UserDefaults sync")
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkForCloudChanges()
        }
        #else
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkForCloudChanges()
        }
        #endif
    }

    @objc private func iCloudChanged(_ notification: Notification) {
        #if DEBUG
        #if DEBUG
        Logger.shared.debug("iCloud changed notification received")
        #endif
        #endif

        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        Task { @MainActor in
            if changedKeys.contains(Keys.colorScheme) {
                if let store = self.ubiquitousStore,
                   let cloudValue = store.string(forKey: Keys.colorScheme),
                   let preference = ColorSchemePreference(rawValue: cloudValue),
                   preference != self._colorScheme {
                    #if DEBUG
                    #if DEBUG
                    Logger.shared.debug("External colorScheme change: \(self._colorScheme) → \(preference)")
                    #endif
                    #endif

                    // Update backing storage directly to avoid writing back to iCloud
                    self._colorScheme = preference
                    // Also update UserDefaults
                    self.userDefaults.set(preference.rawValue, forKey: Keys.colorScheme)
                }
            }

            if changedKeys.contains(Keys.biometricTimeoutMinutes) {
                guard let store = self.ubiquitousStore else { return }
                let cloudValue = Int(store.longLong(forKey: Keys.biometricTimeoutMinutes))
                if cloudValue > 0 && cloudValue != self._biometricTimeoutMinutes {
                    #if DEBUG
                    #if DEBUG
                    Logger.shared.debug("External biometricTimeout change: \(self._biometricTimeoutMinutes) → \(cloudValue)")
                    #endif
                    #endif

                    // Update backing storage directly to avoid writing back to iCloud
                    self._biometricTimeoutMinutes = cloudValue
                    // Also update UserDefaults
                    self.userDefaults.set(cloudValue, forKey: Keys.biometricTimeoutMinutes)
                }
            }
        }
    }

    private func checkForCloudChanges() {
        guard let store = ubiquitousStore else { return }

        #if DEBUG
        Logger.shared.debug("Performing manual cloud change check...")
        #endif

        // Force sync to get latest values
        store.synchronize()

        // Check for changes in color scheme
        if let cloudScheme = store.string(forKey: Keys.colorScheme),
           let preference = ColorSchemePreference(rawValue: cloudScheme),
           preference != _colorScheme {
            #if DEBUG
            Logger.shared.debug("Manual sync detected colorScheme change: \(_colorScheme) → \(preference)")
            #endif

            Task { @MainActor in
                // Update backing storage directly to avoid writing back to iCloud
                self._colorScheme = preference
                // Also update UserDefaults
                self.userDefaults.set(preference.rawValue, forKey: Keys.colorScheme)
            }
        }

        // Check for changes in biometric timeout
        let cloudTimeout = Int(store.longLong(forKey: Keys.biometricTimeoutMinutes))
        if cloudTimeout > 0 && cloudTimeout != _biometricTimeoutMinutes {
            #if DEBUG
            Logger.shared.debug("Manual sync detected biometricTimeout change: \(_biometricTimeoutMinutes) → \(cloudTimeout)")
            #endif

            Task { @MainActor in
                // Update backing storage directly to avoid writing back to iCloud
                self._biometricTimeoutMinutes = cloudTimeout
                // Also update UserDefaults
                self.userDefaults.set(cloudTimeout, forKey: Keys.biometricTimeoutMinutes)
            }
        }
    }

    // MARK: - Debug Methods (Remove in production)
    #if DEBUG
    func forceSyncTest() {
        #if DEBUG
        Logger.shared.debug("Manual sync test with @AppStorage...")
        #endif
        let syncResult = NSUbiquitousKeyValueStore.default.synchronize()
        #if DEBUG
        Logger.shared.debug("Sync result: \(syncResult)")
        #endif

        // Check current values
        let cloudValue = NSUbiquitousKeyValueStore.default.string(forKey: "colorScheme")
        #if DEBUG
        Logger.shared.debug("Current @AppStorage value: \(colorScheme)")
        Logger.shared.debug("Direct iCloud read: \(cloudValue ?? "nil")")
        #endif

        // Check iCloud availability
        if let token = FileManager.default.ubiquityIdentityToken {
            #if DEBUG
            Logger.shared.debug("iCloud available, token: \(token)")
            #endif
        } else {
            #if DEBUG
            Logger.shared.debug("iCloud NOT available")
            #endif
        }
    }

    func reloadFromStorage() {
        #if DEBUG
        Logger.shared.debug("Reloading from storage for test...")
        #endif
        loadFromStorage()
        #if DEBUG
        Logger.shared.debug("Reloaded colorScheme: \(colorScheme)")
        Logger.shared.debug("Reloaded biometricTimeout: \(biometricTimeoutMinutes)")
        #endif
    }
    #endif
}

// MARK: - Color Scheme Preference Enum
enum ColorSchemePreference: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}
