//
//  BasicAppSettingsTests.swift
//  Traveling Snails Tests
//
//

import Testing
import SwiftUI
@testable import Traveling_Snails

@Suite("Basic AppSettings Tests")
struct BasicAppSettingsTests {
    
    @Test("AppSettings should not crash and should return valid values")
    @MainActor func testBasicFunctionality() {
        let appSettings = AppSettings.shared
        
        // Should not crash when accessing properties
        let currentScheme = appSettings.colorScheme
        let currentTimeout = appSettings.biometricTimeoutMinutes
        
        // Should return valid values
        let validSchemes: [ColorSchemePreference] = [.system, .light, .dark]
        #expect(validSchemes.contains(currentScheme), "Should return a valid color scheme")
        #expect(currentTimeout > 0, "Should return a positive timeout value")
        
        // Should be able to set values without crashing
        appSettings.colorScheme = .dark
        appSettings.biometricTimeoutMinutes = 20
        
        // Should be able to read the values back
        #expect(appSettings.colorScheme == .dark)
        #expect(appSettings.biometricTimeoutMinutes == 20)
        
        // Set different values to test change
        appSettings.colorScheme = .light
        appSettings.biometricTimeoutMinutes = 10
        
        #expect(appSettings.colorScheme == .light)
        #expect(appSettings.biometricTimeoutMinutes == 10)
    }
    
    @Test("AppSettings should persist to UserDefaults")
    @MainActor func testUserDefaultsPersistence() {
        let appSettings = AppSettings.shared
        
        // Set a unique value
        let testValue = "dark"
        let testTimeout = 99
        
        appSettings.colorScheme = .dark
        appSettings.biometricTimeoutMinutes = testTimeout
        
        // Should be written to UserDefaults
        let userDefaultsScheme = UserDefaults.standard.string(forKey: "colorScheme")
        let userDefaultsTimeout = UserDefaults.standard.integer(forKey: "biometricTimeoutMinutes")
        
        #expect(userDefaultsScheme == testValue, "Should write color scheme to UserDefaults")
        #expect(userDefaultsTimeout == testTimeout, "Should write timeout to UserDefaults")
    }
    
    @Test("AppSettings should work as singleton")
    @MainActor func testSingletonBehavior() {
        let settings1 = AppSettings.shared
        let settings2 = AppSettings.shared
        
        #expect(settings1 === settings2, "Should return the same instance")
        
        // Setting on one should affect the other
        settings1.colorScheme = .light
        #expect(settings2.colorScheme == .light, "Changes should be visible across references")
        
        settings2.biometricTimeoutMinutes = 42
        #expect(settings1.biometricTimeoutMinutes == 42, "Changes should be visible across references")
    }
    
    @Test("AppSettings should handle notification posting without crashing")
    @MainActor func testNotificationHandling() {
        let appSettings = AppSettings.shared
        
        // Should not crash when notifications are posted
        let userInfo: [String: Any] = [
            NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange,
            NSUbiquitousKeyValueStoreChangedKeysKey: ["colorScheme"]
        ]
        
        NotificationCenter.default.post(
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            userInfo: userInfo
        )
        
        // Should still work after notification
        let scheme = appSettings.colorScheme
        let validSchemes: [ColorSchemePreference] = [.system, .light, .dark]
        #expect(validSchemes.contains(scheme), "Should still return valid values after notification")
    }
}
