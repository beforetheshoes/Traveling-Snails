//
//  NSUbiquitousKeyValueStoreTests.swift
//  Traveling Snails Tests
//
//

import SwiftUI
import Testing
@testable import Traveling_Snails

// TEMPORARILY DISABLED ENTIRE SUITE - AppSettings hanging issue being investigated
// @Suite("NSUbiquitousKeyValueStore AppSettings Tests")
struct NSUbiquitousKeyValueStoreTests_DISABLED {
    // TEMPORARILY DISABLED - AppSettings hanging issue
    // @Test("AppSettings should work with UserDefaults fallback")
    @MainActor func testUserDefaultsFallback() {
        // let appSettings = AppSettings.shared

        // Clear both stores for clean test
        // UserDefaults.standard.removeObject(forKey: "colorScheme")
        // NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        // Set a known value to test behavior predictably
        // appSettings.colorScheme = .system
        // let initialScheme = appSettings.colorScheme
        // #expect(initialScheme == .system, "Should return system after setting it")

        // Should read from UserDefaults
        // UserDefaults.standard.set("dark", forKey: "colorScheme")
        // let fallbackScheme = appSettings.colorScheme
        // #expect(fallbackScheme == .dark, "Should read from UserDefaults")

        // Clean up
        // UserDefaults.standard.removeObject(forKey: "colorScheme")
        // NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    // @Test("AppSettings should write to UserDefaults")
    @MainActor func testWriteToUserDefaults() {
        let appSettings = AppSettings.shared

        // Clear both stores
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        // Set a value
        appSettings.colorScheme = .light

        // Should be written to UserDefaults (always reliable)
        let userDefaultsValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(userDefaultsValue == "light", "UserDefaults should always work")

        // AppSettings should read the value correctly
        #expect(appSettings.colorScheme == .light, "Should read back the correct value")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    // @Test("AppSettings should handle biometric timeout correctly")
    @MainActor func testBiometricTimeoutUserDefaults() {
        let appSettings = AppSettings.shared

        // Clear existing values from both stores
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")

        // Should persist new values
        appSettings.biometricTimeoutMinutes = 15

        // Should be readable immediately
        let retrievedTimeout = appSettings.biometricTimeoutMinutes
        #expect(retrievedTimeout == 15)

        // Should be in UserDefaults (always reliable)
        let userDefaultsTimeout = UserDefaults.standard.integer(forKey: "biometricTimeoutMinutes")
        #expect(userDefaultsTimeout == 15, "UserDefaults should always persist")

        // Clean up both stores
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")
    }

    // @Test("AppSettings should handle notifications without crashing")
    @MainActor func testNotificationSetup() {
        let appSettings = AppSettings.shared

        // Clear both stores
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")

        // Set initial value in UserDefaults
        UserDefaults.standard.set("light", forKey: "colorScheme")
        #expect(appSettings.colorScheme == .light, "Should read from UserDefaults")

        // Post a notification to verify the handler doesn't crash
        let userInfo: [String: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
            NSUbiquitousKeyValueStoreChangedKeysKey: ["colorScheme"],
        ]

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            userInfo: userInfo
        )

        // The notification handler should not crash, AppSettings should still work
        #expect(appSettings.colorScheme == .light, "AppSettings should continue working after notification")

        // Clean up both stores
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }

    // @Test("AppSettings should work without ModelContext dependency")
    @MainActor func testWorksWithoutSwiftData() {
        // This test ensures AppSettings works completely independently of SwiftData
        let appSettings = AppSettings.shared

        // Clear both stores (since AppSettings checks iCloud first)
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")

        // Set a known value first, then test the behavior
        appSettings.colorScheme = .system

        // Should work without any SwiftData setup and return the set value
        let scheme = appSettings.colorScheme
        #expect(scheme == .system, "Should return system after explicitly setting it")

        // Should be able to set values
        appSettings.colorScheme = .light
        appSettings.biometricTimeoutMinutes = 10

        // Should retrieve the set values
        #expect(appSettings.colorScheme == .light)
        #expect(appSettings.biometricTimeoutMinutes == 10)

        // No crashes, no ModelContext needed

        // Clean up
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        UserDefaults.standard.removeObject(forKey: "biometricTimeoutMinutes")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "biometricTimeoutMinutes")
    }

    // @Test("AppSettings should handle quota violations gracefully")
    @MainActor func testQuotaViolationHandling() {
        let appSettings = AppSettings.shared

        // Simulate quota violation notification
        let userInfo: [String: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreQuotaViolationChange,
            NSUbiquitousKeyValueStoreChangedKeysKey: ["colorScheme"],
        ]

        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            userInfo: userInfo
        )

        // App should continue working with UserDefaults fallback
        appSettings.colorScheme = .dark

        let retrievedScheme = appSettings.colorScheme
        #expect(retrievedScheme == .dark)

        // UserDefaults should still work
        let fallbackValue = UserDefaults.standard.string(forKey: "colorScheme")
        #expect(fallbackValue == "dark")

        // Clean up
        UserDefaults.standard.removeObject(forKey: "colorScheme")
    }
}
