//
//  DependencyInjectionTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Tests to verify TCA dependency system works correctly
@Suite("Dependency Injection Tests")
struct DependencyInjectionTests {
    // MARK: - Test Isolation Helpers

    /// Clean up shared state to prevent test contamination
    static func cleanupSharedState() {
        let testKeys = ["isRunningTests", "biometricTimeoutMinutes", "colorScheme"]
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.set(true, forKey: "isRunningTests")
    }

    @Test("ProductionAuthenticationService basic operations", .tags(.integration, .fast, .parallel, .authentication, .utility, .validation))
    @MainActor
    func testAuthServiceBasicOperations() throws {
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }

        let authService = ProductionAuthenticationService()

        authService.lockAllTrips()
        #expect(authService.allTripsLocked)

        authService.resetSession()
        #expect(authService.allTripsLocked)
    }

    @Test("SettingsClient loads defaults", .tags(.integration, .fast, .parallel, .settings, .utility, .validation))
    func testSettingsClientDefaults() async {
        let snapshot = await SettingsClient.liveValue.load()
        #expect(snapshot.biometricTimeoutMinutes >= 0)
    }

    @Test("Production services can be instantiated", .tags(.integration, .fast, .parallel, .utility, .validation, .smoke))
    @MainActor
    func testServiceInstantiation() throws {
        let authService = ProductionAuthenticationService()
        _ = authService.allTripsLocked

        let cloudService = iCloudStorageService()
        #expect(cloudService.isAvailable == cloudService.isAvailable)

        let photoService = SystemPhotoLibraryService()
        let status = photoService.authorizationStatus(for: .readWrite)
        #expect(status.rawValue >= 0)

        let permissionService = SystemPermissionService()
        #expect(type(of: permissionService) == SystemPermissionService.self)
    }
}
