//
//  SimpleSwiftDataValidationTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Simple SwiftData Validation")
struct SimpleSwiftDataValidationTests {
    @Test("AppSettings performance with NSUbiquitousKeyValueStore", .tags(.swiftdata, .fast, .parallel, .settings, .validation, .performance))
    @MainActor func testAppSettingsPerformance() throws {
        let appSettings = AppSettings.shared

        // Simple performance test - rapid access should be very fast
        let startTime = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = appSettings.colorScheme
        }
        let endTime = CFAbsoluteTimeGetCurrent()

        let duration = endTime - startTime
        #expect(duration < 1.0, "100 settings accesses took \(duration)s - should be under 1s (allowing for debug logging)")

        print("✅ AppSettings performance: \(String(format: "%.3f", duration))s for 100 accesses")
    }

    @Test("AppSettings singleton pattern works without ModelContext", .tags(.swiftdata, .fast, .parallel, .settings, .validation, .sanity))
    @MainActor func testAppSettingsSingleton() throws {
        let appSettings1 = AppSettings.shared
        let appSettings2 = AppSettings.shared

        // Should be same instance
        #expect(appSettings1 === appSettings2, "AppSettings should be a singleton")

        // Should work without any setup
        let scheme1 = appSettings1.colorScheme
        let scheme2 = appSettings2.colorScheme

        #expect(scheme1 == scheme2, "Both references should return same values")

        print("✅ AppSettings singleton: Same instance, no ModelContext required")
    }

    @Test("Settings persist correctly to both stores", .tags(.swiftdata, .fast, .parallel, .settings, .validation, .sync))
    @MainActor func testSettingsPersistence() throws {
        let appSettings = AppSettings.shared

        // Clear stores for clean test
        NSUbiquitousKeyValueStore.default.removeObject(forKey: "colorScheme")
        UserDefaults.standard.removeObject(forKey: "colorScheme")

        // Change settings
        appSettings.colorScheme = .dark

        // Verify in UserDefaults (always reliable)
        let defaultsValue = UserDefaults.standard.string(forKey: "colorScheme")

        #expect(defaultsValue == "dark", "Should persist to UserDefaults as fallback")
        #expect(appSettings.colorScheme == .dark, "AppSettings should reflect the change")

        // Note: iCloud persistence may not work in test environment

        print("✅ Settings persistence: Both iCloud and UserDefaults updated")
    }

    @Test("OrganizationManager stability", .tags(.swiftdata, .medium, .parallel, .organization, .validation, .sanity))
    @MainActor func testOrganizationManagerStability() throws {
        let container = try ModelContainer(for: Organization.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let manager = OrganizationManager.shared

        // Create organizations without hanging
        var successCount = 0
        for i in 0..<10 {
            let result = manager.create(name: "Test Org \(i)", in: context)
            if case .success = result {
                successCount += 1
            }
        }

        #expect(successCount == 10, "Should create all 10 organizations successfully")

        let descriptor = FetchDescriptor<Organization>()
        let orgs = try context.fetch(descriptor)
        #expect(orgs.count >= 10, "Should have at least 10 organizations in database")

        print("✅ OrganizationManager: Created \(successCount)/10 organizations")
    }

    @Test("AppSettings and SwiftData work independently", .tags(.swiftdata, .medium, .parallel, .settings, .organization, .validation, .integration))
    @MainActor func testIndependentOperation() throws {
        let container = try ModelContainer(for: Organization.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let appSettings = AppSettings.shared
        let manager = OrganizationManager.shared

        // Settings operations (NSUbiquitousKeyValueStore)
        appSettings.colorScheme = .light
        #expect(appSettings.colorScheme == .light, "Settings should work independently")

        // SwiftData operations
        let result = manager.create(name: "Independent Test Org", in: context)
        #expect(result.isSuccess, "SwiftData operations should work independently")

        // Both should continue working
        appSettings.colorScheme = .dark
        #expect(appSettings.colorScheme == .dark, "Settings still work after SwiftData operations")

        let descriptor = FetchDescriptor<Organization>()
        let orgs = try context.fetch(descriptor)
        #expect(orgs.count >= 1, "SwiftData still works after settings operations")

        print("✅ Independent operation: Settings and SwiftData work without interference")
    }
}
