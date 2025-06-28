//
//  ServiceContainer.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI

/// Dependency injection container for managing services
/// Uses modern SwiftUI environment patterns for service provision
/// Thread-safe with proper synchronization
@Observable
class ServiceContainer {
    
    // MARK: - Service Storage
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let lock = NSLock()
    
    // MARK: - Service Registration
    
    /// Register a singleton service instance
    /// - Parameters:
    ///   - service: The service instance to register
    ///   - type: The service type to register as
    func register<T>(_ service: T, as type: T.Type) {
        let key = String(describing: type)
        lock.withLock {
            services[key] = service
        }
    }
    
    /// Register a singleton service instance asynchronously (for background services)
    /// - Parameters:
    ///   - service: The service instance to register
    ///   - type: The service type to register as
    func registerAsync<T: Sendable>(_ service: T, as type: T.Type) async {
        let key = String(describing: type)
        lock.withLock {
            services[key] = service
        }
    }
    
    /// Register a service factory
    /// - Parameters:
    ///   - factory: Factory closure that creates the service
    ///   - type: The service type to register as
    func registerFactory<T>(_ factory: @escaping () -> T, as type: T.Type) {
        let key = String(describing: type)
        lock.withLock {
            factories[key] = factory
        }
    }
    
    /// Register a service factory with async initialization
    /// - Parameters:
    ///   - factory: Async factory closure that creates the service
    ///   - type: The service type to register as
    func registerAsyncFactory<T: Sendable>(_ factory: @escaping () async -> T, as type: T.Type) {
        let key = String(describing: type)
        factories[key] = {
            // For async factories, we need to handle the async nature properly
            // This is a simplified approach - in production, you might want more sophisticated handling
            fatalError("Async factory for \(type) requires async resolution. Use resolveAsync instead.")
        }
        // Store async factory separately if needed for future async resolution
    }
    
    /// Register a service with lazy initialization
    /// - Parameters:
    ///   - factory: Factory closure that creates the service (called only once)
    ///   - type: The service type to register as
    func registerLazy<T>(_ factory: @escaping () -> T, as type: T.Type) {
        let key = String(describing: type)
        
        // Create a wrapper that ensures the factory is only called once
        var instance: T?
        let lazyFactory = {
            if let existing = instance {
                return existing
            }
            let newInstance = factory()
            instance = newInstance
            return newInstance
        }
        
        lock.withLock {
            factories[key] = lazyFactory
        }
    }
    
    // MARK: - Service Resolution
    
    /// Resolve a service instance
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        return lock.withLock {
            // First check for existing singleton instance
            if let service = services[key] as? T {
                return service
            }
            
            // Then check for factory
            if let factory = factories[key] {
                if let service = factory() as? T {
                    return service
                }
            }
            
            fatalError("Service of type \(type) is not registered in the container")
        }
    }
    
    /// Safely resolve a service instance
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance, or nil if not registered
    func tryResolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        
        return lock.withLock {
            // First check for existing singleton instance
            if let service = services[key] as? T {
                return service
            }
            
            // Then check for factory
            if let factory = factories[key] {
                return factory() as? T
            }
            
            return nil
        }
    }
    
    /// Check if a service is registered
    /// - Parameter type: The service type to check
    /// - Returns: True if the service is registered
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let key = String(describing: type)
        return lock.withLock {
            return services[key] != nil || factories[key] != nil
        }
    }
    
    // MARK: - Container Management
    
    /// Clear all registered services (useful for testing)
    func clear() {
        lock.withLock {
            services.removeAll()
            factories.removeAll()
        }
    }
    
    /// Get all registered service types
    var registeredServiceTypes: [String] {
        return lock.withLock {
            let serviceKeys = services.keys
            let factoryKeys = factories.keys
            return Array(Set(serviceKeys).union(Set(factoryKeys))).sorted()
        }
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for accessing the service container
struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue = ServiceContainer()
}

extension EnvironmentValues {
    /// Access the service container from the SwiftUI environment
    var serviceContainer: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - Convenience Environment Keys for Services

/// Environment key for AuthenticationService
struct AuthenticationServiceKey: EnvironmentKey {
    static let defaultValue: AuthenticationService? = nil
}

/// Environment key for CloudStorageService
struct CloudStorageServiceKey: EnvironmentKey {
    static let defaultValue: CloudStorageService? = nil
}

/// Environment key for PhotoLibraryService
struct PhotoLibraryServiceKey: EnvironmentKey {
    static let defaultValue: PhotoLibraryService? = nil
}

/// Environment key for SyncService
struct SyncServiceKey: EnvironmentKey {
    static let defaultValue: SyncService? = nil
}

/// Environment key for PermissionService
struct PermissionServiceKey: EnvironmentKey {
    static let defaultValue: PermissionService? = nil
}

extension EnvironmentValues {
    /// Direct access to AuthenticationService from environment
    var authenticationService: AuthenticationService? {
        get { self[AuthenticationServiceKey.self] }
        set { self[AuthenticationServiceKey.self] = newValue }
    }
    
    /// Direct access to CloudStorageService from environment
    var cloudStorageService: CloudStorageService? {
        get { self[CloudStorageServiceKey.self] }
        set { self[CloudStorageServiceKey.self] = newValue }
    }
    
    /// Direct access to PhotoLibraryService from environment
    var photoLibraryService: PhotoLibraryService? {
        get { self[PhotoLibraryServiceKey.self] }
        set { self[PhotoLibraryServiceKey.self] = newValue }
    }
    
    /// Direct access to SyncService from environment
    var syncService: SyncService? {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
    
    /// Direct access to PermissionService from environment
    var permissionService: PermissionService? {
        get { self[PermissionServiceKey.self] }
        set { self[PermissionServiceKey.self] = newValue }
    }
}

// MARK: - View Extensions for Service Injection

extension View {
    /// Inject a service container into the environment
    /// - Parameter container: The service container to inject
    /// - Returns: A view with the container in its environment
    func serviceContainer(_ container: ServiceContainer) -> some View {
        environment(\.serviceContainer, container)
    }
    
    /// Inject services directly into the environment
    /// - Parameters:
    ///   - authService: Authentication service
    ///   - cloudService: Cloud storage service
    ///   - photoService: Photo library service
    ///   - syncService: Sync service
    ///   - permissionService: Permission service
    /// - Returns: A view with services in its environment
    func services(
        auth: AuthenticationService? = nil,
        cloud: CloudStorageService? = nil,
        photo: PhotoLibraryService? = nil,
        sync: SyncService? = nil,
        permission: PermissionService? = nil
    ) -> some View {
        self
            .environment(\.authenticationService, auth)
            .environment(\.cloudStorageService, cloud)
            .environment(\.photoLibraryService, photo)
            .environment(\.syncService, sync)
            .environment(\.permissionService, permission)
    }
}

// MARK: - Service Factory Protocol

/// Protocol for creating configured service containers
protocol ServiceContainerFactory {
    /// Create a service container with production services
    static func createProductionContainer() -> ServiceContainer
    
    /// Create a service container with test/mock services
    static func createTestContainer() -> ServiceContainer
    
    /// Create a service container for SwiftUI previews
    static func createPreviewContainer() -> ServiceContainer
}

// MARK: - Default Service Container Factory

/// Default implementation of service container factory
struct DefaultServiceContainerFactory: ServiceContainerFactory {
    
    static func createProductionContainer() -> ServiceContainer {
        let container = ServiceContainer()
        
        // Register production services using factory methods to avoid @MainActor issues
        container.registerLazy({
            ProductionAuthenticationService()
        }, as: AuthenticationService.self)
        
        container.registerLazy({
            iCloudStorageService()
        }, as: CloudStorageService.self)
        
        container.registerLazy({
            SystemPhotoLibraryService()
        }, as: PhotoLibraryService.self)
        
        container.registerLazy({
            SystemPermissionService()
        }, as: PermissionService.self)
        
        // SyncService requires ModelContainer, so we'll register it as a factory
        // that will be configured when the container is available
        
        return container
    }
    
    static func createTestContainer() -> ServiceContainer {
        let container = ServiceContainer()
        
        // Register mock services for testing
        container.register(MockAuthenticationService(), as: AuthenticationService.self)
        container.register(MockCloudStorageService(), as: CloudStorageService.self)
        container.register(MockPhotoLibraryService(), as: PhotoLibraryService.self)
        container.register(MockSyncService(), as: SyncService.self)
        container.register(MockPermissionService(), as: PermissionService.self)
        
        return container
    }
    
    static func createPreviewContainer() -> ServiceContainer {
        let container = ServiceContainer()
        
        // Register preview-friendly services (will be implemented in Phase 4)
        // container.register(PreviewAuthenticationService(), as: AuthenticationService.self)
        // container.register(PreviewCloudStorageService(), as: CloudStorageService.self)
        // container.register(PreviewPhotoLibraryService(), as: PhotoLibraryService.self)
        // container.register(PreviewSyncService(), as: SyncService.self)
        // container.register(PreviewPermissionService(), as: PermissionService.self)
        
        return container
    }
}