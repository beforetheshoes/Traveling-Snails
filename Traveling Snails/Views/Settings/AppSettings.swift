//
//  AppSettings.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/2/25.
//

import SwiftUI
import Foundation
import Observation

// MARK: - Simple App Settings with direct @Observable properties
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - Storage systems
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
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
            ubiquitousStore.set(newValue.rawValue, forKey: Keys.colorScheme)
            ubiquitousStore.synchronize()
            
            #if DEBUG
            print("🎨 AppSettings.colorScheme set to: \(newValue)")
            #endif
        }
    }
    
    var biometricTimeoutMinutes: Int {
        get { _biometricTimeoutMinutes }
        set {
            _biometricTimeoutMinutes = newValue
            // Save to both stores
            userDefaults.set(newValue, forKey: Keys.biometricTimeoutMinutes)
            ubiquitousStore.set(newValue, forKey: Keys.biometricTimeoutMinutes)
            ubiquitousStore.synchronize()
            
            #if DEBUG
            print("⏱️ AppSettings.biometricTimeoutMinutes set to: \(newValue)")
            #endif
        }
    }
    
    // MARK: - Initialization
    private init() {
        #if DEBUG
        print("🔧 AppSettings initializing...")
        #endif
        
        loadFromStorage()
        setupICloudNotifications()
        
        #if DEBUG
        print("   Loaded colorScheme: \(colorScheme)")
        print("   Loaded biometricTimeout: \(biometricTimeoutMinutes)")
        #endif
    }
    
    private func loadFromStorage() {
        // Load colorScheme without triggering didSet
        if let stored = userDefaults.string(forKey: Keys.colorScheme),
           let preference = ColorSchemePreference(rawValue: stored) {
            _colorScheme = preference
        } else if let cloud = ubiquitousStore.string(forKey: Keys.colorScheme),
                  let preference = ColorSchemePreference(rawValue: cloud) {
            _colorScheme = preference
        } else {
            // Reset to default when both stores are empty
            _colorScheme = .system
        }
        
        // Load biometricTimeoutMinutes without triggering didSet
        let storedTimeout = userDefaults.integer(forKey: Keys.biometricTimeoutMinutes)
        if storedTimeout > 0 {
            _biometricTimeoutMinutes = storedTimeout
        } else {
            let cloudTimeout = Int(ubiquitousStore.longLong(forKey: Keys.biometricTimeoutMinutes))
            if cloudTimeout > 0 {
                _biometricTimeoutMinutes = cloudTimeout
            } else {
                // Reset to default when both stores are empty
                _biometricTimeoutMinutes = 5
            }
        }
    }
    
    private func setupICloudNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudChanged(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        
        ubiquitousStore.synchronize()
    }
    
    @objc private func iCloudChanged(_ notification: Notification) {
        #if DEBUG
        print("☁️ iCloud changed notification received")
        #endif
        
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        
        Task { @MainActor in
            if changedKeys.contains(Keys.colorScheme) {
                if let cloudValue = self.ubiquitousStore.string(forKey: Keys.colorScheme),
                   let preference = ColorSchemePreference(rawValue: cloudValue),
                   preference != self._colorScheme {
                    
                    #if DEBUG
                    print("   🔄 External colorScheme change: \(self._colorScheme) → \(preference)")
                    #endif
                    
                    // Update backing storage directly to avoid writing back to iCloud
                    self._colorScheme = preference
                    // Also update UserDefaults
                    self.userDefaults.set(preference.rawValue, forKey: Keys.colorScheme)
                }
            }
            
            if changedKeys.contains(Keys.biometricTimeoutMinutes) {
                let cloudValue = Int(self.ubiquitousStore.longLong(forKey: Keys.biometricTimeoutMinutes))
                if cloudValue > 0 && cloudValue != self._biometricTimeoutMinutes {
                    
                    #if DEBUG
                    print("   🔄 External biometricTimeout change: \(self._biometricTimeoutMinutes) → \(cloudValue)")
                    #endif
                    
                    // Update backing storage directly to avoid writing back to iCloud
                    self._biometricTimeoutMinutes = cloudValue
                    // Also update UserDefaults
                    self.userDefaults.set(cloudValue, forKey: Keys.biometricTimeoutMinutes)
                }
            }
        }
    }
    
    // MARK: - Debug Methods (Remove in production)
    #if DEBUG
    public func forceSyncTest() {
        print("🧪 Manual sync test with @AppStorage...")
        let syncResult = NSUbiquitousKeyValueStore.default.synchronize()
        print("   Sync result: \(syncResult)")
        
        // Check current values
        let cloudValue = NSUbiquitousKeyValueStore.default.string(forKey: "colorScheme")
        print("   Current @AppStorage value: \(colorScheme)")
        print("   Direct iCloud read: \(cloudValue ?? "nil")")
        
        // Check iCloud availability
        if let token = FileManager.default.ubiquityIdentityToken {
            print("   ☁️ iCloud available, token: \(token)")
        } else {
            print("   ❌ iCloud NOT available")
        }
    }
    
    public func reloadFromStorage() {
        print("🔄 Reloading from storage for test...")
        loadFromStorage()
        print("   Reloaded colorScheme: \(colorScheme)")
        print("   Reloaded biometricTimeout: \(biometricTimeoutMinutes)")
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