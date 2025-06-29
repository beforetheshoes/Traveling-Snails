//
//  BackwardCompatibilityAdapter.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import SwiftUI

/// Adapter to maintain backward compatibility during migration
/// Provides singleton-like access to dependency-injected services
/// This will be removed after full migration is complete
@MainActor
class BackwardCompatibilityAdapter {
    // MARK: - Singleton Instance

    static let shared = BackwardCompatibilityAdapter()

    // MARK: - Service Container

    private var serviceContainer: ServiceContainer?
    private var modernManagers: ModernManagers?

    // MARK: - Configuration

    /// Configure the adapter with a service container
    /// - Parameter container: The service container to use
    func configure(with container: ServiceContainer) {
        self.serviceContainer = container
        self.modernManagers = ModernManagers(
            authManager: ModernBiometricAuthManager.from(container: container),
            appSettings: ModernAppSettings.from(container: container),
            syncManager: nil // Will be set when ModelContainer is available
        )
    }

    /// Configure the sync manager when ModelContainer is available
    /// - Parameter modelContainer: The model container for sync operations
    func configureSyncManager(with modelContainer: ModelContainer) {
        guard let container = serviceContainer else {
            fatalError("BackwardCompatibilityAdapter must be configured with service container first")
        }

        // Register CloudKitSyncService with the model container
        let syncService = CloudKitSyncService(modelContainer: modelContainer)
        container.register(syncService, as: SyncService.self)

        // Update the sync manager
        modernManagers?.syncManager = ModernSyncManager.from(container: container)
    }

    /// Configure the sync manager asynchronously when ModelContainer is available
    /// - Parameter modelContainer: The model container for sync operations
    func configureSyncManagerAsync(with modelContainer: ModelContainer) async {
        guard let container = serviceContainer else {
            fatalError("BackwardCompatibilityAdapter must be configured with service container first")
        }

        // Register CloudKitSyncService with the model container asynchronously
        let syncService = CloudKitSyncService(modelContainer: modelContainer)
        await container.registerAsync(syncService, as: SyncService.self)

        // Update the sync manager
        modernManagers?.syncManager = ModernSyncManager.from(container: container)
    }

    // MARK: - Backward Compatibility Properties

    /// Access to the modern BiometricAuthManager
    var biometricAuthManager: ModernBiometricAuthManager {
        guard let manager = modernManagers?.authManager else {
            fatalError("BackwardCompatibilityAdapter not configured. Call configure(with:) first.")
        }
        return manager
    }

    /// Access to the modern AppSettings
    var appSettings: ModernAppSettings {
        guard let settings = modernManagers?.appSettings else {
            fatalError("BackwardCompatibilityAdapter not configured. Call configure(with:) first.")
        }
        return settings
    }

    /// Access to the modern SyncManager
    var syncManager: ModernSyncManager {
        guard let manager = modernManagers?.syncManager else {
            fatalError("BackwardCompatibilityAdapter not configured with ModelContainer. Call configureSyncManager(with:) first.")
        }
        return manager
    }

    // MARK: - Service Access

    /// Get a service from the container
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance
    func getService<T>(_ type: T.Type) -> T {
        guard let container = serviceContainer else {
            fatalError("BackwardCompatibilityAdapter not configured. Call configure(with:) first.")
        }
        return container.resolve(type)
    }

    /// Safely get a service from the container
    /// - Parameter type: The service type to resolve
    /// - Returns: The service instance, or nil if not registered
    func tryGetService<T>(_ type: T.Type) -> T? {
        guard let container = serviceContainer else {
            return nil
        }
        return container.tryResolve(type)
    }

    // MARK: - Private Storage

    private struct ModernManagers {
        let authManager: ModernBiometricAuthManager
        let appSettings: ModernAppSettings
        var syncManager: ModernSyncManager?
    }
}

// MARK: - Migration Helpers

extension BackwardCompatibilityAdapter {
    /// Create a production-configured adapter
    /// - Returns: Adapter with production services
    static func production() -> BackwardCompatibilityAdapter {
        let adapter = BackwardCompatibilityAdapter()
        let container = DefaultServiceContainerFactory.createProductionContainer()
        adapter.configure(with: container)
        return adapter
    }

    /// Create a test-configured adapter
    /// - Returns: Adapter with test services
    static func testing() -> BackwardCompatibilityAdapter {
        let adapter = BackwardCompatibilityAdapter()
        let container = DefaultServiceContainerFactory.createTestContainer()
        adapter.configure(with: container)
        return adapter
    }

    /// Check if the adapter is fully configured
    var isFullyConfigured: Bool {
        serviceContainer != nil &&
               modernManagers?.authManager != nil &&
               modernManagers?.appSettings != nil &&
               modernManagers?.syncManager != nil
    }

    /// Check if the adapter is partially configured (missing sync manager)
    var isPartiallyConfigured: Bool {
        serviceContainer != nil &&
               modernManagers?.authManager != nil &&
               modernManagers?.appSettings != nil &&
               modernManagers?.syncManager == nil
    }
}

// MARK: - Singleton Replacement Extensions

/// Extensions to provide direct singleton-like access during migration
extension BackwardCompatibilityAdapter {
    /// Temporary singleton access to BiometricAuthManager
    /// This will be removed after full migration
    static var legacyBiometricAuthManager: ModernBiometricAuthManager {
        shared.biometricAuthManager
    }

    /// Temporary singleton access to AppSettings
    /// This will be removed after full migration
    static var legacyAppSettings: ModernAppSettings {
        shared.appSettings
    }

    /// Temporary singleton access to SyncManager
    /// This will be removed after full migration
    static var legacySyncManager: ModernSyncManager {
        shared.syncManager
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for accessing the backward compatibility adapter
struct BackwardCompatibilityAdapterKey: EnvironmentKey {
    static let defaultValue: BackwardCompatibilityAdapter? = nil
}

extension EnvironmentValues {
    /// Access the backward compatibility adapter from the SwiftUI environment
    var backwardCompatibilityAdapter: BackwardCompatibilityAdapter? {
        get { self[BackwardCompatibilityAdapterKey.self] }
        set { self[BackwardCompatibilityAdapterKey.self] = newValue }
    }
}

extension View {
    /// Inject the backward compatibility adapter into the environment
    /// - Parameter adapter: The adapter to inject
    /// - Returns: A view with the adapter in its environment
    func backwardCompatibilityAdapter(_ adapter: BackwardCompatibilityAdapter) -> some View {
        environment(\.backwardCompatibilityAdapter, adapter)
    }
}
