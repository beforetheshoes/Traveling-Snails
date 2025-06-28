//
//  ModernAppStartupTest.swift
//  Traveling Snails Tests
//
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

/// Test to verify ModernTraveling_SnailsApp starts without crashing
@Suite("Modern App Startup Tests")
struct ModernAppStartupTest {
    
    @Test("CloudKit service can be created without immediate CloudKit access")
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
    
    @Test("ServiceContainer creation works in modern app")
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
    
    @Test("BackwardCompatibilityAdapter async configuration")
    @MainActor func testBackwardCompatibilityAsync() async throws {
        // Test the async configuration pattern
        let adapter = BackwardCompatibilityAdapter()
        let container = ServiceContainer()
        
        // Register mock services for testing
        container.register(MockAuthenticationService(), as: AuthenticationService.self)
        container.register(MockCloudStorageService(), as: CloudStorageService.self)
        container.register(MockPhotoLibraryService(), as: PhotoLibraryService.self)
        container.register(MockPermissionService(), as: PermissionService.self)
        
        // Configure adapter
        adapter.configure(with: container)
        
        #expect(adapter.isPartiallyConfigured)
        print("✅ BackwardCompatibilityAdapter async configuration works")
    }
}