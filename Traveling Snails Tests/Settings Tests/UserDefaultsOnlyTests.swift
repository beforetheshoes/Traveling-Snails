//
//  UserDefaultsOnlyTests.swift
//  Traveling Snails Tests
//
//

import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("UserDefaults Only Tests")
struct UserDefaultsOnlyTests {
    @Test("UserDefaults should persist AppSettings values")
    @MainActor func testUserDefaultsPersistence() {
        let appSettings = AppSettings.shared

        // Set a specific value
        appSettings.colorScheme = .dark

        // Check that it was written to UserDefaults (this always works)
        let storedValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(storedValue == "dark", "Should write to UserDefaults")

        // Set another value
        appSettings.colorScheme = .light
        let newStoredValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(newStoredValue == "light", "Should update UserDefaults")

        // Test biometric timeout
        appSettings.biometricTimeoutMinutes = 30
        let timeoutValue = UserDefaults.standard.integer(forKey: "biometricTimeoutMinutes")
        #expect(timeoutValue == 30, "Should write timeout to UserDefaults")
    }

    @Test("AppSettings should read set values correctly")
    @MainActor func testReadSetValues() {
        let appSettings = AppSettings.shared

        // Set and immediately read back
        appSettings.colorScheme = .system
        #expect(appSettings.colorScheme == .system, "Should read back system")

        appSettings.colorScheme = .light
        #expect(appSettings.colorScheme == .light, "Should read back light")

        appSettings.colorScheme = .dark
        #expect(appSettings.colorScheme == .dark, "Should read back dark")

        // Test timeout
        appSettings.biometricTimeoutMinutes = 15
        #expect(appSettings.biometricTimeoutMinutes == 15, "Should read back timeout")

        appSettings.biometricTimeoutMinutes = 45
        #expect(appSettings.biometricTimeoutMinutes == 45, "Should read back new timeout")
    }

    @Test("AppSettings should not crash with basic operations")
    @MainActor func testBasicOperations() {
        let appSettings = AppSettings.shared

        // Should not crash when getting current values
        let currentScheme = appSettings.colorScheme
        let currentTimeout = appSettings.biometricTimeoutMinutes

        // Values should be reasonable
        let validSchemes: [ColorSchemePreference] = [.system, .light, .dark]
        #expect(validSchemes.contains(currentScheme), "Should return a valid scheme")
        #expect(currentTimeout >= 0, "Timeout should be non-negative")

        // Should not crash when setting values
        appSettings.colorScheme = .dark
        appSettings.biometricTimeoutMinutes = 20

        // Should not crash when setting different values
        appSettings.colorScheme = .light
        appSettings.biometricTimeoutMinutes = 10

        // Should not crash when setting back to system
        appSettings.colorScheme = .system
    }

    @Test("ColorSchemePreference enum should work correctly")
    func testColorSchemeEnum() {
        // Test raw values
        #expect(ColorSchemePreference.system.rawValue == "system")
        #expect(ColorSchemePreference.light.rawValue == "light")
        #expect(ColorSchemePreference.dark.rawValue == "dark")

        // Test init from raw value
        #expect(ColorSchemePreference(rawValue: "system") == .system)
        #expect(ColorSchemePreference(rawValue: "light") == .light)
        #expect(ColorSchemePreference(rawValue: "dark") == .dark)
        #expect(ColorSchemePreference(rawValue: "invalid") == nil)

        // Test colorScheme mapping
        #expect(ColorSchemePreference.system.colorScheme == nil)
        #expect(ColorSchemePreference.light.colorScheme == .light)
        #expect(ColorSchemePreference.dark.colorScheme == .dark)

        // Test display names
        #expect(!ColorSchemePreference.system.displayName.isEmpty)
        #expect(!ColorSchemePreference.light.displayName.isEmpty)
        #expect(!ColorSchemePreference.dark.displayName.isEmpty)
    }
}
