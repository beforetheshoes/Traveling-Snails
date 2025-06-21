//
//  ICloudSyncDiagnosticTests.swift
//  Traveling Snails Tests
//
//  Created by Ryan Williams on 6/20/25 - Diagnose iCloud sync issues
//

import Testing
import SwiftUI
@testable import Traveling_Snails

@Suite("iCloud Sync Diagnostic Tests")
struct ICloudSyncDiagnosticTests {
    
    @Test("Check iCloud availability and entitlements")
    @MainActor func testICloudAvailability() {
        print("🔍 Diagnosing iCloud availability...")
        
        // Check if iCloud is available
        let fileManager = FileManager.default
        let ubiquityIdentityToken = fileManager.ubiquityIdentityToken
        
        if let token = ubiquityIdentityToken {
            print("✅ iCloud is available")
            print("   Token: \(token)")
        } else {
            print("❌ iCloud is NOT available")
            print("   Possible causes:")
            print("   - User not signed into iCloud")
            print("   - iCloud Drive disabled")
            print("   - App not enabled in iCloud settings")
        }
        
        // Check bundle identifier
        let bundleId = Bundle.main.bundleIdentifier
        print("📱 Bundle ID: \(bundleId ?? "unknown")")
        
        // Test NSUbiquitousKeyValueStore
        let store = NSUbiquitousKeyValueStore.default
        print("🏪 NSUbiquitousKeyValueStore created successfully")
        
        // Test basic operations
        let testKey = "test_sync_key"
        let testValue = "test_value_\(Date().timeIntervalSince1970)"
        
        store.set(testValue, forKey: testKey)
        let retrieved = store.string(forKey: testKey)
        
        if retrieved == testValue {
            print("✅ Basic store operations work")
        } else {
            print("❌ Basic store operations failed")
            print("   Set: \(testValue)")
            print("   Got: \(retrieved ?? "nil")")
        }
        
        // Test synchronize
        let syncResult = store.synchronize()
        print("🔄 Synchronize result: \(syncResult)")
        
        // Cleanup
        store.removeObject(forKey: testKey)
    }
    
    @Test("Test AppSettings iCloud integration")
    @MainActor func testAppSettingsICloudIntegration() {
        print("🔍 Testing AppSettings iCloud integration...")
        
        // Clear stores
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
        
        let appSettings = AppSettings.shared
        
        print("📝 Setting colorScheme to .light...")
        appSettings.colorScheme = .light
        
        // Check what's in each store
        let cloudValue = NSUbiquitousKeyValueStore.default.string(forKey: "colorScheme")
        let userDefaultsValue = UserDefaults.standard.string(forKey: "colorScheme")
        
        print("📊 Store values after setting:")
        print("   iCloud: \(cloudValue ?? "nil")")
        print("   UserDefaults: \(userDefaultsValue ?? "nil")")
        print("   AppSettings returns: \(appSettings.colorScheme)")
        
        #expect(userDefaultsValue == "light", "UserDefaults should have 'light'")
        #expect(cloudValue == "light", "iCloud should have 'light'")
        #expect(appSettings.colorScheme == .light, "AppSettings should return .light")
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
    }
    
    @Test("Test manual iCloud notification simulation")
    @MainActor func testICloudNotificationSimulation() {
        print("🔍 Testing iCloud notification handling...")
        
        // Clear stores
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
        
        let store = NSUbiquitousKeyValueStore.default
        
        // Simulate an external change (like from another device)
        print("📝 Simulating external iCloud change...")
        store.set("dark", forKey: "colorScheme")
        
        // Manually trigger synchronize
        let syncResult = store.synchronize()
        print("🔄 Manual sync result: \(syncResult)")
        
        // Check what AppSettings sees
        let appSettings = AppSettings.shared
        let currentScheme = appSettings.colorScheme
        
        print("📊 After simulated external change:")
        print("   iCloud value: \(store.string(forKey: "colorScheme") ?? "nil")")
        print("   UserDefaults value: \(UserDefaults.standard.string(forKey: "colorScheme") ?? "nil")")
        print("   AppSettings returns: \(currentScheme)")
        
        // In a real scenario, we'd expect the notification to fire
        // But in tests, we may need to manually call the sync method
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: "colorScheme")
        store.removeObject(forKey: "colorScheme")
    }
}
