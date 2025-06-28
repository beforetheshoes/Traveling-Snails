//
//  ModernSyncManager.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import Observation

/// Modern SyncManager using dependency injection
/// Replaces the singleton-based SyncManager for better testability and eliminates infinite recursion
@MainActor
@Observable
class ModernSyncManager {
    
    // MARK: - Properties
    
    private let syncService: SyncService
    private let cloudStorageService: CloudStorageService?
    
    // MARK: - Initialization
    
    /// Initialize with injected services
    /// - Parameters:
    ///   - syncService: The sync service to use
    ///   - cloudStorageService: Optional cloud storage service
    init(syncService: SyncService, cloudStorageService: CloudStorageService? = nil) {
        self.syncService = syncService
        self.cloudStorageService = cloudStorageService
    }
    
    // MARK: - Public API (Mirrors SyncManager for compatibility)
    
    /// Current sync status
    var isSyncing: Bool {
        return syncService.isSyncing
    }
    
    /// Date of last successful sync
    var lastSyncDate: Date? {
        return syncService.lastSyncDate
    }
    
    /// Current sync error, if any
    var syncError: Error? {
        return syncService.syncError
    }
    
    /// Number of pending changes waiting to sync
    var pendingChangesCount: Int {
        return syncService.pendingChangesCount
    }
    
    /// Whether protected trips should be synced
    var syncProtectedTrips: Bool {
        get { return syncService.syncProtectedTrips }
        set { 
            // Create a mutable reference to modify the service
            if let mutableService = syncService as? CloudKitSyncService {
                mutableService.syncProtectedTrips = newValue
            }
        }
    }
    
    /// Trigger a sync operation
    func triggerSync() {
        syncService.triggerSync()
    }
    
    /// Trigger a sync operation and wait for completion
    func triggerSyncAndWait() async {
        await syncService.triggerSyncAndWait()
    }
    
    /// Process pending changes when coming back online
    func processPendingChanges() async {
        await syncService.processPendingChanges()
    }
    
    /// Sync with progress tracking for large datasets
    /// - Returns: Progress information about the sync operation
    func syncWithProgress() async -> SyncProgress {
        return await syncService.syncWithProgress()
    }
    
    /// Sync and resolve any conflicts that arise
    func syncAndResolveConflicts() async {
        await syncService.syncAndResolveConflicts()
    }
    
    /// Trigger sync with retry logic for network interruptions
    func triggerSyncWithRetry() async {
        await syncService.triggerSyncWithRetry()
    }
    
    /// Set the network status for testing offline scenarios
    /// - Parameter status: The network status to simulate
    func setNetworkStatus(_ status: NetworkStatus) {
        syncService.setNetworkStatus(status)
    }
    
    /// Simulate network error for testing
    func simulateNetworkError() async {
        await syncService.simulateNetworkError()
    }
    
    /// Simulate network interruptions for testing
    /// - Parameter count: Number of interruptions to simulate
    func simulateNetworkInterruptions(count: Int) {
        syncService.simulateNetworkInterruptions(count: count)
    }
    
    // MARK: - Advanced Features
    
    /// Add an observer for sync events (if supported by the service)
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: SyncServiceObserver) {
        if let advancedService = syncService as? AdvancedSyncService {
            advancedService.addObserver(observer)
        }
    }
    
    /// Remove an observer for sync events (if supported by the service)
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: SyncServiceObserver) {
        if let advancedService = syncService as? AdvancedSyncService {
            advancedService.removeObserver(observer)
        }
    }
    
    /// Force a full sync (if supported by the service)
    func forceFullSync() async {
        if let advancedService = syncService as? AdvancedSyncService {
            await advancedService.forceFullSync()
        }
    }
    
    /// Get detailed sync statistics (if supported by the service)
    /// - Returns: Statistics about sync operations
    func getSyncStatistics() async -> SyncStatistics? {
        if let advancedService = syncService as? AdvancedSyncService {
            return await advancedService.getSyncStatistics()
        }
        return nil
    }
    
    /// Reset sync state (if supported by the service)
    func resetSyncState() async {
        if let advancedService = syncService as? AdvancedSyncService {
            await advancedService.resetSyncState()
        }
    }
}

// MARK: - Convenience Factory Methods

extension ModernSyncManager {
    
    /// Create a SyncManager with production services
    /// - Parameter modelContainer: The model container for CloudKit sync
    /// - Returns: Configured manager with production services
    static func production(modelContainer: ModelContainer) -> ModernSyncManager {
        let syncService = CloudKitSyncService(modelContainer: modelContainer)
        let cloudStorageService = iCloudStorageService()
        return ModernSyncManager(syncService: syncService, cloudStorageService: cloudStorageService)
    }
    
    /// Create a SyncManager from a service container
    /// - Parameter container: The service container to resolve from
    /// - Returns: Configured manager with services from container
    static func from(container: ServiceContainer) -> ModernSyncManager {
        let syncService = container.resolve(SyncService.self)
        let cloudStorageService = container.tryResolve(CloudStorageService.self)
        return ModernSyncManager(syncService: syncService, cloudStorageService: cloudStorageService)
    }
    
    /// Create a SyncManager for testing
    /// - Parameter syncService: The sync service to use (typically a mock)
    /// - Returns: Configured manager for testing
    static func testing(syncService: SyncService) -> ModernSyncManager {
        return ModernSyncManager(syncService: syncService, cloudStorageService: nil)
    }
}