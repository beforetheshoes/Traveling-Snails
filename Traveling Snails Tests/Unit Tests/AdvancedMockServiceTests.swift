//
//  AdvancedMockServiceTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Advanced tests for mock service behavior and reliability
@Suite("Advanced Mock Service Tests")
@MainActor
struct AdvancedMockServiceTests {
    @Test("Mock authentication service state transitions", .tags(.unit, .fast, .parallel, .utility, .authentication, .validation))
    func testAuthenticationStateTransitions() throws {
        let container = TestServiceContainer.create()
        let mockAuth = container.resolve(AuthenticationService.self) as! MockAuthenticationService

        // Test initial state
        #expect(mockAuth.allTripsLocked)

        // Test configuration methods
        mockAuth.configureSuccessfulAuthentication()
        #expect(!mockAuth.allTripsLocked)

        mockAuth.configureFailedAuthentication()
        #expect(mockAuth.allTripsLocked)

        mockAuth.configureNoBiometrics()
        #expect(mockAuth.allTripsLocked)

        // Reset to clean state for individual trip testing
        mockAuth.resetForTesting()

        // Test individual trip handling (using Trip objects instead of UUID)
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: true)

        // Test authentication for trip
        let isAuthenticated = mockAuth.isAuthenticated(for: trip)
        #expect(!isAuthenticated) // Should start unauthenticated

        // Test protection status
        let isProtected = mockAuth.isProtected(trip)
        #expect(isProtected) // Trip was created as protected

        // Test reset functionality
        mockAuth.resetForTesting()
        #expect(mockAuth.allTripsLocked) // Should return to default state
    }

    @Test("Mock sync service behavior under different conditions", .tags(.unit, .medium, .serial, .utility, .sync, .async, .validation))
    func testSyncServiceMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let mockSync = container.resolve(SyncService.self) as! MockSyncService

        // Test successful sync configuration
        mockSync.configureSuccessfulSync()
        #expect(!mockSync.isSyncing)
        #expect(mockSync.lastSyncDate == nil)

        await mockSync.triggerSyncAndWait()
        #expect(!mockSync.isSyncing) // Should not be syncing after completion
        #expect(mockSync.lastSyncDate != nil) // Should have sync date
        #expect(mockSync.syncError == nil) // Should have no error

        // Test sync failure configuration
        let testError = SyncError.networkUnavailable
        mockSync.configureSyncFailure(testError)

        await mockSync.triggerSyncAndWait()
        #expect(!mockSync.isSyncing)
        #expect(mockSync.syncError != nil) // Should have error

        // Test sync with progress
        mockSync.configureSuccessfulSync()
        let progress = await mockSync.syncWithProgress()
        #expect(progress.isCompleted)
        #expect(progress.totalBatches > 0)
        #expect(progress.completedBatches == progress.totalBatches)

        // Test reset functionality
        mockSync.resetForTesting()
        #expect(!mockSync.isSyncing)
        #expect(mockSync.lastSyncDate == nil)
        #expect(mockSync.syncError == nil)
    }

    @Test("Mock cloud storage service state management", .tags(.unit, .fast, .parallel, .utility, .cloudkit, .validation))
    func testCloudStorageMockBehavior() throws {
        let container = TestServiceContainer.create()
        let mockCloud = container.resolve(CloudStorageService.self) as! MockCloudStorageService

        // Test availability configuration
        mockCloud.configureAvailable()
        #expect(mockCloud.isAvailable)

        mockCloud.configureUnavailable()
        #expect(!mockCloud.isAvailable)

        // Test reset functionality
        mockCloud.resetForTesting()
        // Default state should be available for easier testing
        #expect(mockCloud.isAvailable)
    }

    @Test("Mock photo library service authorization states", .tags(.unit, .medium, .serial, .utility, .permissions, .async, .validation))
    func testPhotoLibraryMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let mockPhoto = container.resolve(PhotoLibraryService.self) as! MockPhotoLibraryService

        // Test authorized configuration
        mockPhoto.configureAuthorized()
        #expect(mockPhoto.authorizationStatus(for: .readWrite) == .authorized)

        let authorizedStatus = await mockPhoto.requestAuthorization(for: .readWrite)
        #expect(authorizedStatus == .authorized)

        // Test denied configuration
        mockPhoto.configureDenied()
        #expect(mockPhoto.authorizationStatus(for: .readWrite) == .denied)

        let deniedStatus = await mockPhoto.requestAuthorization(for: .readWrite)
        #expect(deniedStatus == .denied)

        // Test restricted configuration
        mockPhoto.configureRestricted()
        #expect(mockPhoto.authorizationStatus(for: .readWrite) == .restricted)

        // Test reset functionality
        mockPhoto.resetForTesting()
        // Should return to default state (authorized for easier testing)
        #expect(mockPhoto.authorizationStatus(for: .readWrite) == .authorized)
    }

    @Test("Mock permission service comprehensive testing", .tags(.unit, .medium, .serial, .utility, .permissions, .async, .validation))
    func testPermissionServiceMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let mockPermission = container.resolve(PermissionService.self) as! MockPermissionService

        // Test all permissions granted
        mockPermission.configureAllPermissionsGranted()

        let photoStatus = mockPermission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(photoStatus == .authorized)

        // Test all permissions denied
        mockPermission.configureAllPermissionsDenied()

        let deniedPhotoStatus = mockPermission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(deniedPhotoStatus == .denied)

        // Test realistic permissions (mix of granted/denied)
        mockPermission.configureRealisticPermissions()

        let realisticPhotoStatus = mockPermission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(realisticPhotoStatus.rawValue >= 0) // Should have valid status

        // Test reset functionality
        mockPermission.resetForTesting()
        let resetPhotoStatus = mockPermission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(resetPhotoStatus == .authorized) // Default should be granted for easier testing
    }

    @Test("Mock service interaction consistency", .tags(.unit, .medium, .serial, .utility, .integration, .async, .validation))
    func testMockServiceInteractionConsistency() async throws {
        let container = TestServiceContainer.create { mocks in
            // Configure all mocks for successful scenario
            mocks.auth.configureSuccessfulAuthentication()
            mocks.cloud.configureAvailable()
            mocks.photo.configureAuthorized()
            mocks.permission.configureAllPermissionsGranted()
            mocks.sync.configureSuccessfulSync()
        }

        let auth = container.resolve(AuthenticationService.self)
        let cloud = container.resolve(CloudStorageService.self)
        let photo = container.resolve(PhotoLibraryService.self)
        let permission = container.resolve(PermissionService.self)
        let sync = container.resolve(SyncService.self)

        // Test that all services are in expected states
        #expect(!auth.allTripsLocked) // Should be unlocked
        #expect(cloud.isAvailable) // Should be available
        #expect(photo.authorizationStatus(for: .readWrite) == .authorized) // Should be authorized

        let photoStatus = permission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(photoStatus == .authorized) // Should have access

        // Test sync operation
        await sync.triggerSyncAndWait()
        #expect(sync.syncError == nil) // Should have no error
        #expect(sync.lastSyncDate != nil) // Should have completed
    }

    @Test("Mock service failure scenario consistency", .tags(.unit, .medium, .serial, .utility, .integration, .async, .errorHandling, .negative))
    func testMockServiceFailureScenario() async throws {
        let container = TestServiceContainer.create { mocks in
            // Configure all mocks for failure scenario
            mocks.auth.configureFailedAuthentication()
            mocks.cloud.configureUnavailable()
            mocks.photo.configureDenied()
            mocks.permission.configureAllPermissionsDenied()
            mocks.sync.configureSyncFailure()
        }

        let auth = container.resolve(AuthenticationService.self)
        let cloud = container.resolve(CloudStorageService.self)
        let photo = container.resolve(PhotoLibraryService.self)
        let permission = container.resolve(PermissionService.self)
        let sync = container.resolve(SyncService.self)

        // Test that all services are in expected failure states
        #expect(auth.allTripsLocked) // Should be locked
        #expect(!cloud.isAvailable) // Should be unavailable
        #expect(photo.authorizationStatus(for: .readWrite) == .denied) // Should be denied

        let photoStatus = permission.getPhotoLibraryAuthorizationStatus(for: .readWrite)
        #expect(photoStatus == .denied) // Should not have access

        // Test sync operation fails appropriately
        await sync.triggerSyncAndWait()
        #expect(sync.syncError != nil) // Should have error
    }

    @Test("Mock service state isolation between tests", .tags(.unit, .fast, .parallel, .utility, .validation, .boundary))
    func testMockServiceStateIsolation() throws {
        // Create first container and modify state
        let container1 = TestServiceContainer.create()
        let mockAuth1 = container1.resolve(AuthenticationService.self) as! MockAuthenticationService

        mockAuth1.configureFailedAuthentication()
        #expect(mockAuth1.allTripsLocked)

        // Create second container - should be independent
        let container2 = TestServiceContainer.create()
        let mockAuth2 = container2.resolve(AuthenticationService.self) as! MockAuthenticationService

        // Second container should start with default state, not affected by first
        #expect(mockAuth2.allTripsLocked) // Default state

        mockAuth2.configureSuccessfulAuthentication()
        #expect(!mockAuth2.allTripsLocked)

        // First container should be unchanged
        #expect(mockAuth1.allTripsLocked) // Should still be in failure state
    }

    @Test("Mock service concurrent access safety", .tags(.unit, .medium, .serial, .utility, .concurrent, .async, .stress, .validation))
    func testMockServiceConcurrentAccess() async throws {
        let container = TestServiceContainer.create()
        let mockSync = container.resolve(SyncService.self) as! MockSyncService

        mockSync.configureSuccessfulSync()

        // Test concurrent sync operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    await mockSync.triggerSyncAndWait()
                }
            }

            for await _ in group {
                // Wait for all tasks to complete
            }
        }

        // All operations should complete successfully
        #expect(mockSync.syncError == nil)
        #expect(mockSync.lastSyncDate != nil)
        #expect(!mockSync.isSyncing)
    }

    @Test("TestServiceContainer scenario configurations", .tags(.unit, .medium, .serial, .utility, .integration, .async, .validation))
    func testScenarioConfigurations() async throws {
        // Test successful scenario
        let successContainer = TestServiceContainer.successfulScenario()
        TestServiceContainer.verifyAllMockServices(in: successContainer)

        let auth = successContainer.resolve(AuthenticationService.self)
        #expect(!auth.allTripsLocked)

        // Test failure scenario
        let failureContainer = TestServiceContainer.failureScenario()
        TestServiceContainer.verifyAllMockServices(in: failureContainer)

        let authFail = failureContainer.resolve(AuthenticationService.self)
        #expect(authFail.allTripsLocked)

        // Test offline scenario
        let offlineContainer = TestServiceContainer.offlineScenario()
        let cloud = offlineContainer.resolve(CloudStorageService.self)
        #expect(!cloud.isAvailable)

        // Test no biometrics scenario
        let noBiometricsContainer = TestServiceContainer.noBiometricsScenario()
        let authNoBio = noBiometricsContainer.resolve(AuthenticationService.self)
        #expect(authNoBio.allTripsLocked) // Should be locked without biometrics
    }
}
