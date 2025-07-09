//
//  MockServiceDemonstrationTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Demonstration tests showing how to use the mock service infrastructure
/// These tests serve as examples and documentation for other developers
@Suite("Mock Service Demonstration Tests")
struct MockServiceDemonstrationTests {
    // MARK: - Basic Mock Service Usage

    @Test("Basic mock service creation and configuration", .tags(.unit, .fast, .parallel, .utility, .validation))
    func testBasicMockServiceUsage() throws {
        // Create a test container with default mock services
        let container = TestServiceContainer.create()

        // Verify all mock services are registered
        TestServiceContainer.verifyAllMockServices(in: container)

        // Resolve and configure individual services
        let mockAuth = container.resolve(AuthenticationService.self) as! MockAuthenticationService
        let mockCloud = container.resolve(CloudStorageService.self) as! MockCloudStorageService

        // Configure mock behavior
        mockAuth.configureSuccessfulAuthentication()
        mockCloud.configureAvailable()

        // Test configured behavior
        #expect(mockAuth.isEnabled)
        #expect(mockAuth.canUseBiometrics())
        #expect(mockCloud.isAvailable)
    }

    @Test("Custom mock service configuration", .tags(.unit, .fast, .parallel, .utility, .validation))
    func testCustomMockConfiguration() throws {
        // Create container with custom configuration
        let container = TestServiceContainer.create { mocks in
            mocks.auth.configureFailedAuthentication()
            mocks.cloud.configureUnavailable()
            mocks.photo.configureDenied()
        }

        let mockServices = MockServices(container: container)

        // Verify custom configuration
        #expect(mockServices.auth.mockAuthenticationResult == false)
        #expect(mockServices.cloud.isAvailable == false)
        #expect(mockServices.photo.mockAuthorizationStatus == .denied)
    }

    // MARK: - Pre-configured Scenarios

    @Test("Successful scenario configuration", .tags(.unit, .fast, .parallel, .utility, .validation))
    func testSuccessfulScenario() throws {
        let container = TestServiceContainer.successfulScenario()
        let mocks = MockServices(container: container)

        // All services should be configured for success
        #expect(mocks.auth.mockAuthenticationResult)
        #expect(mocks.cloud.isAvailable)
        #expect(mocks.photo.mockAuthorizationStatus == .authorized)
        #expect(mocks.sync.mockSyncResult)
    }

    @Test("Failure scenario configuration", .tags(.unit, .fast, .parallel, .utility, .validation, .errorHandling, .negative))
    func testFailureScenario() throws {
        let container = TestServiceContainer.failureScenario()
        let mocks = MockServices(container: container)

        // All services should be configured for failure
        #expect(!mocks.auth.mockAuthenticationResult)
        #expect(!mocks.cloud.isAvailable)
        #expect(mocks.photo.mockAuthorizationStatus == .denied)
        #expect(!mocks.sync.mockSyncResult)
    }

    @Test("No biometrics scenario configuration", .tags(.unit, .fast, .parallel, .utility, .biometric, .validation))
    func testNoBiometricsScenario() throws {
        let container = TestServiceContainer.noBiometricsScenario()
        let mocks = MockServices(container: container)

        // Auth should be disabled, others should work
        #expect(!mocks.auth.mockIsEnabled)
        #expect(mocks.auth.mockBiometricType == .none)
        #expect(mocks.cloud.isAvailable)
        #expect(mocks.photo.mockAuthorizationStatus == .authorized)
    }

    // MARK: - Mock Service Behavior Verification

    @Test("Authentication service mock behavior", .tags(.unit, .medium, .serial, .utility, .authentication, .async, .validation))
    func testAuthenticationServiceMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let authService = container.resolve(AuthenticationService.self)
        let mockAuth = authService as! MockAuthenticationService

        // Configure for successful authentication
        mockAuth.configureSuccessfulAuthentication()

        // Create a test trip (Note: This would need SwiftData context in real usage)
        // For demo purposes, we'll test the mock behavior directly
        #expect(mockAuth.isEnabled)
        #expect(mockAuth.canUseBiometrics())
        #expect(mockAuth.biometricType == .faceID)
        #expect(!mockAuth.allTripsLocked)

        // Test call counting
        #expect(mockAuth.authenticationCallCount == 0)

        // Reset and verify
        mockAuth.resetForTesting()
        #expect(mockAuth.authenticationCallCount == 0)
        #expect(mockAuth.allTripsLocked)
    }

    @Test("Cloud storage service mock behavior", .tags(.unit, .fast, .parallel, .utility, .cloudkit, .validation))
    func testCloudStorageServiceMockBehavior() throws {
        let container = TestServiceContainer.create()
        let cloudService = container.resolve(CloudStorageService.self)
        let mockCloud = cloudService as! MockCloudStorageService

        // Test basic storage operations
        mockCloud.setString("test-value", forKey: "test-key")
        #expect(mockCloud.getString(forKey: "test-key") == "test-value")

        mockCloud.setInteger(42, forKey: "number-key")
        #expect(mockCloud.getInteger(forKey: "number-key") == 42)

        mockCloud.setBoolean(true, forKey: "bool-key")
        #expect(mockCloud.getBoolean(forKey: "bool-key") == true)

        // Test synchronization tracking
        #expect(mockCloud.synchronizeCallCount == 0)
        let syncResult = mockCloud.synchronize()
        #expect(syncResult == true)
        #expect(mockCloud.synchronizeCallCount == 1)

        // Test storage verification methods
        #expect(mockCloud.hasKey("test-key"))
        #expect(!mockCloud.hasKey("nonexistent-key"))
        #expect(mockCloud.itemCount == 3)

        // Test reset
        mockCloud.resetForTesting()
        #expect(mockCloud.itemCount == 0)
        #expect(mockCloud.synchronizeCallCount == 0)
    }

    @Test("Permission service mock behavior", .tags(.unit, .medium, .serial, .utility, .permissions, .async, .validation))
    func testPermissionServiceMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let permissionService = container.resolve(PermissionService.self)
        let mockPermission = permissionService as! MockPermissionService

        // Test default configuration (all granted)
        #expect(mockPermission.getPhotoLibraryAuthorizationStatus(for: .readWrite) == .authorized)
        #expect(mockPermission.getCameraAuthorizationStatus())
        #expect(mockPermission.getMicrophoneAuthorizationStatus())

        // Test permission request tracking
        #expect(mockPermission.getRequestCallCount(for: "camera") == 0)
        let cameraResult = await mockPermission.requestCameraAccess()
        #expect(cameraResult == true)
        #expect(mockPermission.getRequestCallCount(for: "camera") == 1)

        // Test custom configuration
        mockPermission.setMicrophoneAuthorized(false)
        #expect(!mockPermission.getMicrophoneAuthorizationStatus())

        // Test reset
        mockPermission.resetForTesting()
        #expect(mockPermission.getTotalRequestCallCount() == 0)
        #expect(mockPermission.getMicrophoneAuthorizationStatus()) // Should be back to default granted
    }

    @Test("Sync service mock behavior", .tags(.unit, .medium, .serial, .utility, .sync, .async, .mainActor, .validation))
    @MainActor func testSyncServiceMockBehavior() async throws {
        let container = TestServiceContainer.create()
        let syncService = container.resolve(SyncService.self)
        let mockSync = syncService as! MockSyncService

        // Test default configuration  
        #expect(!mockSync.isSyncing)
        #expect(mockSync.syncCallCount == 0)

        // Test successful sync
        let progress = await mockSync.syncWithProgress()
        #expect(mockSync.syncCallCount == 1)
        #expect(!mockSync.isSyncing) // Should be false after completion
        #expect(mockSync.didReachCompletion())
        #expect(progress.isCompleted)

        // Test sync and wait
        await mockSync.triggerSyncAndWait()
        #expect(mockSync.triggerSyncAndWaitCallCount == 1)

        // Test progress tracking
        let progressUpdates = mockSync.getProgressUpdates()
        #expect(!progressUpdates.isEmpty)
        #expect(mockSync.getFinalProgressPercentage() == 1.0)

        // Test failure configuration
        mockSync.configureSyncFailure(SyncError.networkUnavailable)
        await mockSync.triggerSyncAndWait()
        #expect(mockSync.syncError != nil)
    }

    // MARK: - Integration with MockServiceTestBase

    @Test("MockServiceTestBase usage example", .tags(.unit, .fast, .parallel, .utility, .mainActor, .validation))
    @MainActor func testMockServiceTestBase() throws {
        // Create a test instance that uses MockServiceTestBase
        let testInstance = ExampleMockServiceTest()

        // Setup with custom configuration
        try testInstance.setupMockServices { mocks in
            mocks.auth.configureNoBiometrics()
            mocks.cloud.configureUnavailable()
        }

        // Use the configured services
        #expect(!testInstance.auth.isEnabled)
        #expect(!testInstance.cloud.isAvailable)

        // Cleanup
        testInstance.cleanupMockServices()
    }
}

// MARK: - Example Test Class Using MockServiceTestBase

/// Example test class demonstrating MockServiceTestBase usage
private class ExampleMockServiceTest: MockServiceTestBase {
    func performTestWithMockServices() {
        // In a real test, you would call setupMockServices() in your setup
        // and cleanupMockServices() in your cleanup

        // Direct access to mock services through computed properties
        _ = auth.isEnabled
        _ = cloud.isAvailable
        _ = photo.mockAuthorizationStatus
        _ = permission.getTotalRequestCallCount()
        _ = sync.isSyncing
    }
}
