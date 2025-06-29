//
//  ImmediateUIResponseTests.swift
//  Traveling Snails Tests
//
//

import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Immediate UI Response Tests")
struct ImmediateUIResponseTests {
    @Test("Setting colorScheme should return immediately")
    @MainActor func testImmediateColorSchemeResponse() {
        // Clear all stores first
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        let appSettings = AppSettings.shared

        // Test 1: Set to light, should return light immediately
        appSettings.colorScheme = .light
        let immediately = appSettings.colorScheme
        #expect(immediately == .light, "Setting .light should return .light immediately")

        // Test 2: Set to dark, should return dark immediately  
        appSettings.colorScheme = .dark
        let afterDark = appSettings.colorScheme
        #expect(afterDark == .dark, "Setting .dark should return .dark immediately")

        // Test 3: Set to system, should return system immediately
        appSettings.colorScheme = .system
        let afterSystem = appSettings.colorScheme
        #expect(afterSystem == .system, "Setting .system should return .system immediately")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    @Test("Multiple rapid changes should all be reflected immediately")
    @MainActor func testRapidChanges() {
        // Clear all stores first
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        let appSettings = AppSettings.shared

        // Rapid fire changes - each should be immediately reflected
        appSettings.colorScheme = .light
        #expect(appSettings.colorScheme == .light)

        appSettings.colorScheme = .dark
        #expect(appSettings.colorScheme == .dark)

        appSettings.colorScheme = .system
        #expect(appSettings.colorScheme == .system)

        appSettings.colorScheme = .light
        #expect(appSettings.colorScheme == .light)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    @Test("UserDefaults should always have the latest value")
    @MainActor func testUserDefaultsConsistency() {
        // Clear all stores first
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        let appSettings = AppSettings.shared

        // Set value and check UserDefaults immediately
        appSettings.colorScheme = .light
        let userDefaultsValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(userDefaultsValue == "light", "UserDefaults should have 'light' immediately after setting")

        // Change value and check again
        appSettings.colorScheme = .dark
        let newUserDefaultsValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(newUserDefaultsValue == "dark", "UserDefaults should have 'dark' immediately after setting")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    @Test("Settings should persist across getter calls")
    @MainActor func testSettingsPersistence() {
        // Clear all stores first
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        let appSettings = AppSettings.shared

        // Set a value
        appSettings.colorScheme = .dark

        // Multiple getter calls should return the same value
        let first = appSettings.colorScheme
        let second = appSettings.colorScheme
        let third = appSettings.colorScheme

        #expect(first == .dark, "First call should return .dark")
        #expect(second == .dark, "Second call should return .dark")
        #expect(third == .dark, "Third call should return .dark")
        #expect(first == second && second == third, "All calls should return the same value")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    @Test("BiometricTimeout should also respond immediately")
    @MainActor func testImmediateBiometricTimeoutResponse() {
        // Clear all stores first
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")

        let appSettings = AppSettings.shared

        // Test setting timeout values
        appSettings.biometricTimeoutMinutes = 10
        #expect(appSettings.biometricTimeoutMinutes == 10, "Should return 10 immediately")

        appSettings.biometricTimeoutMinutes = 30
        #expect(appSettings.biometricTimeoutMinutes == 30, "Should return 30 immediately")

        appSettings.biometricTimeoutMinutes = 60
        #expect(appSettings.biometricTimeoutMinutes == 60, "Should return 60 immediately")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")
    }
}
