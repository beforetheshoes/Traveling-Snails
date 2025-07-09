//
//  ModernAppStartupTest.swift
//  Traveling Snails Tests
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

/// Test to verify ModernTraveling_SnailsApp starts without crashing
@Suite("Modern App Startup Tests")
struct ModernAppStartupTest {
    @Test("CloudKit service can be created without immediate CloudKit access", .tags(.integration, .fast, .parallel, .cloudkit, .sync, .validation, .smoke))
    @MainActor func testCloudKitServiceDeferredInitialization() throws {
        // Create a test ModelContainer (safe - no CloudKit during init)
        let schema = Schema([Trip.self, Activity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Creating CloudKitSyncService should not crash (lazy initialization)
        let syncService = CloudKitSyncService(modelContainer: container)

        // Service should exist (CloudKitSyncService is a class, so always non-nil)
        #expect(syncService.isSyncing == false)
        print("✅ CloudKitSyncService created with deferred initialization")
    }

    @Test("ServiceContainer creation works in modern app", .tags(.integration, .fast, .parallel, .utility, .validation, .smoke))
    func testServiceContainerCreation() throws {
        // Test that ServiceContainer can be created without issues
        let container = ServiceContainer()

        // Register a test service
        let testService = MockAuthenticationService()
        container.register(testService, as: AuthenticationService.self)

        // Verify service registration works
        let resolved = container.resolve(AuthenticationService.self)
        #expect(resolved is MockAuthenticationService)

        print("✅ ServiceContainer works correctly")
    }

    // BackwardCompatibilityAdapter test removed - adapter no longer exists after migration to pure dependency injection
}
