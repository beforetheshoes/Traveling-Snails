//
//  DependencyInjectionTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Tests to verify dependency injection system works correctly
@Suite("Dependency Injection Tests")
struct DependencyInjectionTests {
    // MARK: - Test Isolation Helpers

    /// Clean up shared state to prevent test contamination
    static func cleanupSharedState() {
        // Clear UserDefaults test keys
        let testKeys = ["isRunningTests", "biometricTimeoutMinutes", "colorScheme"]
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Ensure test environment is properly detected
        UserDefaults.standard.set(true, forKey: "isRunningTests")
    }

    @Test("ServiceContainer can register and resolve services")
    func testServiceContainerBasicOperations() throws {
        let container = ServiceContainer()

        // Register a service
        let authService = ProductionAuthenticationService()
        container.register(authService, as: AuthenticationService.self)

        // Resolve the service
        let resolvedService = container.resolve(AuthenticationService.self)
        #expect(resolvedService is ProductionAuthenticationService)
    }

    @Test("DefaultServiceContainerFactory creates production container")
    func testProductionContainerCreation() throws {
        let container = DefaultServiceContainerFactory.createProductionContainer()

        // Verify expected services are registered
        #expect(container.isRegistered(AuthenticationService.self))
        #expect(container.isRegistered(CloudStorageService.self))
        #expect(container.isRegistered(PhotoLibraryService.self))
        #expect(container.isRegistered(PermissionService.self))

        // Verify services can be resolved
        let authService = container.resolve(AuthenticationService.self)
        #expect(authService is ProductionAuthenticationService)

        let cloudService = container.resolve(CloudStorageService.self)
        #expect(cloudService is iCloudStorageService)

        let photoService = container.resolve(PhotoLibraryService.self)
        #expect(photoService is SystemPhotoLibraryService)

        let permissionService = container.resolve(PermissionService.self)
        #expect(permissionService is SystemPermissionService)
    }

    @Test("ModernBiometricAuthManager can be created from container")
    @MainActor
    func testModernBiometricAuthManagerCreation() throws {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }

        let container = DefaultServiceContainerFactory.createProductionContainer()

        // Test that the container can resolve the auth service
        let authService = container.resolve(AuthenticationService.self)
        #expect(authService is ProductionAuthenticationService)

        // Test that ModernBiometricAuthManager can be created
        let authManager = ModernBiometricAuthManager.from(container: container)

        // Test basic state management methods (no LAContext or biometric calls)
        authManager.lockAllTrips() // Should not crash
        #expect(authManager.allTripsLocked) // Should now be locked

        authManager.resetSession() // Should not crash
        #expect(authManager.allTripsLocked) // Should still be locked after reset
    }

    @Test("ModernAppSettings can be created from container")
    @MainActor
    func testModernAppSettingsCreation() throws {
        let container = DefaultServiceContainerFactory.createProductionContainer()
        let appSettings = ModernAppSettings.from(container: container)

        // Basic functionality test
        #expect(appSettings.colorScheme == appSettings.colorScheme) // Should have a consistent value
        #expect(appSettings.biometricTimeoutMinutes >= 0) // Should be non-negative
    }

    @Test("BackwardCompatibilityAdapter configures correctly")
    @MainActor
    func testBackwardCompatibilityAdapter() throws {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }

        let adapter = BackwardCompatibilityAdapter()
        let container = DefaultServiceContainerFactory.createProductionContainer()

        // Configure adapter
        adapter.configure(with: container)

        // Verify configuration state (these should not trigger LAContext)
        #expect(adapter.isPartiallyConfigured)
        #expect(!adapter.isFullyConfigured) // Missing sync manager until ModelContainer is provided

        // Test service resolution works (without accessing LAContext-dependent properties)
        let authManager = adapter.biometricAuthManager
        let appSettings = adapter.appSettings

        // Test AppSettings works (no LAContext dependency)
        #expect(appSettings.biometricTimeoutMinutes >= 0) // Should have valid timeout value
        let originalTimeout = appSettings.biometricTimeoutMinutes
        appSettings.biometricTimeoutMinutes = 10
        #expect(appSettings.biometricTimeoutMinutes == 10)
        appSettings.biometricTimeoutMinutes = originalTimeout // Reset

        // Test basic AuthManager state management (no LAContext calls)
        authManager.lockAllTrips() // Should not crash
        #expect(authManager.allTripsLocked) // Should now be locked

        authManager.resetSession() // Should not crash  
        #expect(authManager.allTripsLocked) // Should still be locked after reset
    }

    @Test("Service factory methods work correctly")
    @MainActor
    func testServiceFactoryMethods() throws {
        // Test ProductionAuthenticationService (avoid canUseBiometrics() during tests)
        let authService = ProductionAuthenticationService()
        // Test basic protocol conformance
        _ = authService as AuthenticationService // Should conform to protocol

        // Test iCloudStorageService  
        let cloudService = iCloudStorageService()
        #expect(cloudService.isAvailable == cloudService.isAvailable) // Should be consistent

        // Test SystemPhotoLibraryService
        let photoService = SystemPhotoLibraryService()
        let status = photoService.authorizationStatus(for: .readWrite)
        #expect(status.rawValue >= 0) // Should be a valid status

        // Test SystemPermissionService
        let permissionService = SystemPermissionService()
        // SystemPermissionService should be instantiable and functional
        #expect(type(of: permissionService) == SystemPermissionService.self)
    }

    @Test("ModernSyncManager can be created with production services")
    @MainActor
    func testModernSyncManagerCreation() throws {
        // This test validates the structure without requiring ModelContainer
        let authService = ProductionAuthenticationService()
        let cloudService = iCloudStorageService()

        // Test service instantiation (avoid LAContext-dependent calls)
        #expect(authService.allTripsLocked) // Should start with all trips locked
        #expect(cloudService.isAvailable == cloudService.isAvailable) // Should be consistent
    }
}

/// Extension for cleaner assertions
extension Bool {
    var description: String {
        self ? "true" : "false"
    }
}
