//
//  TestServiceContainer.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Utility class for setting up service containers in tests
/// Provides convenient methods for creating and configuring mock services
final class TestServiceContainer {
    
    // MARK: - Container Creation
    
    /// Create a test container with default mock services
    /// - Returns: ServiceContainer configured with mock services
    static func create() -> ServiceContainer {
        return DefaultServiceContainerFactory.createTestContainer()
    }
    
    /// Create a test container with custom mock configuration
    /// - Parameter configure: Closure to configure mock services
    /// - Returns: ServiceContainer with customized mock services
    static func create(configure: (MockServices) throws -> Void) rethrows -> ServiceContainer {
        let container = DefaultServiceContainerFactory.createTestContainer()
        let mockServices = MockServices(container: container)
        try configure(mockServices)
        return container
    }
    
    /// Create a test container with specific mock services
    /// - Parameters:
    ///   - authService: Custom mock authentication service
    ///   - cloudService: Custom mock cloud storage service
    ///   - photoService: Custom mock photo library service
    ///   - permissionService: Custom mock permission service
    ///   - syncService: Custom mock sync service
    /// - Returns: ServiceContainer with custom mock services
    static func create(
        authService: MockAuthenticationService? = nil,
        cloudService: MockCloudStorageService? = nil,
        photoService: MockPhotoLibraryService? = nil,
        permissionService: MockPermissionService? = nil,
        syncService: MockSyncService? = nil
    ) -> ServiceContainer {
        let container = ServiceContainer()
        
        container.register(authService ?? MockAuthenticationService(), as: AuthenticationService.self)
        container.register(cloudService ?? MockCloudStorageService(), as: CloudStorageService.self)
        container.register(photoService ?? MockPhotoLibraryService(), as: PhotoLibraryService.self)
        container.register(permissionService ?? MockPermissionService(), as: PermissionService.self)
        container.register(syncService ?? MockSyncService(), as: SyncService.self)
        
        return container
    }
    
    // MARK: - Pre-configured Scenarios
    
    /// Create a container configured for successful operations
    static func successfulScenario() -> ServiceContainer {
        return create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.cloud.configureAvailable()
            mocks.photo.configureAuthorized()
            mocks.permission.configureAllPermissionsGranted()
            mocks.sync.configureSuccessfulSync()
        }
    }
    
    /// Create a container configured for failure scenarios
    static func failureScenario() -> ServiceContainer {
        return create { mocks in
            mocks.auth.configureFailedAuthentication()
            mocks.cloud.configureUnavailable()
            mocks.photo.configureDenied()
            mocks.permission.configureAllPermissionsDenied()
            mocks.sync.configureSyncFailure()
        }
    }
    
    /// Create a container configured for no biometrics scenarios
    static func noBiometricsScenario() -> ServiceContainer {
        return create { mocks in
            mocks.auth.configureNoBiometrics()
            mocks.cloud.configureAvailable()
            mocks.photo.configureAuthorized()
            mocks.permission.configureRealisticPermissions()
            mocks.sync.configureSuccessfulSync()
        }
    }
    
    /// Create a container configured for offline scenarios
    static func offlineScenario() -> ServiceContainer {
        return create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.cloud.configureUnavailable()
            mocks.photo.configureAuthorized()
            mocks.permission.configureAllPermissionsGranted()
            mocks.sync.configureSyncFailure(SyncError.networkUnavailable)
        }
    }
    
    /// Create a container configured for restricted permissions scenario
    static func restrictedPermissionsScenario() -> ServiceContainer {
        return create { mocks in
            mocks.auth.configureSuccessfulAuthentication()
            mocks.cloud.configureAvailable()
            mocks.photo.configureRestricted()
            mocks.permission.configureRealisticPermissions()
            mocks.sync.configureSuccessfulSync()
        }
    }
}

// MARK: - Mock Services Accessor

/// Provides easy access to mock services for configuration
final class MockServices {
    
    let auth: MockAuthenticationService
    let cloud: MockCloudStorageService
    let photo: MockPhotoLibraryService
    let permission: MockPermissionService
    let sync: MockSyncService
    
    init(container: ServiceContainer) {
        self.auth = container.resolve(AuthenticationService.self) as! MockAuthenticationService
        self.cloud = container.resolve(CloudStorageService.self) as! MockCloudStorageService
        self.photo = container.resolve(PhotoLibraryService.self) as! MockPhotoLibraryService
        self.permission = container.resolve(PermissionService.self) as! MockPermissionService
        self.sync = container.resolve(SyncService.self) as! MockSyncService
    }
    
    /// Reset all mock services to clean state
    func resetAll() {
        auth.resetForTesting()
        cloud.resetForTesting()
        photo.resetForTesting()
        permission.resetForTesting()
        sync.resetForTesting()
    }
}

// MARK: - Test Base Class with Mock Services

/// Base class for tests that need mock services
/// Provides automatic setup and cleanup of mock services
@MainActor
class MockServiceTestBase {
    
    private(set) var container: ServiceContainer!
    private(set) var mockServices: MockServices!
    
    /// Setup method - call this in your test setup
    func setupMockServices(configure: ((MockServices) throws -> Void)? = nil) throws {
        container = TestServiceContainer.create()
        mockServices = MockServices(container: container)
        
        if let configure = configure {
            try configure(mockServices)
        }
    }
    
    /// Cleanup method - call this in your test cleanup
    func cleanupMockServices() {
        mockServices?.resetAll()
        container = nil
        mockServices = nil
    }
    
    /// Convenient access to mock services
    var auth: MockAuthenticationService { mockServices.auth }
    var cloud: MockCloudStorageService { mockServices.cloud }
    var photo: MockPhotoLibraryService { mockServices.photo }
    var permission: MockPermissionService { mockServices.permission }
    var sync: MockSyncService { mockServices.sync }
}

// MARK: - Test Utilities

extension TestServiceContainer {
    
    /// Assert that a service is registered and is the expected mock type
    /// - Parameters:
    ///   - container: The service container to check
    ///   - serviceType: The service protocol type
    ///   - mockType: The expected mock implementation type
    static func assertMockService<ServiceType, MockType>(
        in container: ServiceContainer,
        serviceType: ServiceType.Type,
        mockType: MockType.Type,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let service = container.resolve(serviceType)
        #expect(service is MockType)
    }
    
    /// Verify that all expected mock services are registered
    /// - Parameter container: The service container to verify
    static func verifyAllMockServices(
        in container: ServiceContainer,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertMockService(in: container, serviceType: AuthenticationService.self, mockType: MockAuthenticationService.self, file: file, line: line)
        assertMockService(in: container, serviceType: CloudStorageService.self, mockType: MockCloudStorageService.self, file: file, line: line)
        assertMockService(in: container, serviceType: PhotoLibraryService.self, mockType: MockPhotoLibraryService.self, file: file, line: line)
        assertMockService(in: container, serviceType: PermissionService.self, mockType: MockPermissionService.self, file: file, line: line)
        assertMockService(in: container, serviceType: SyncService.self, mockType: MockSyncService.self, file: file, line: line)
    }
}