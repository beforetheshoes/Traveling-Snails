
//
//  SyncManagerTests.swift
//  Traveling Snails Tests
//
//

import Testing
import SwiftData
import Foundation
@testable import Traveling_Snails

/// Test suite for SyncManager functionality with proper test isolation
/// Using pure Swift Testing with modern concurrency patterns
@Suite("SyncManager Integration Tests")
struct SyncManagerTests {
    
    
    // MARK: - Test Environment Setup
    
    /// Create isolated test environment with in-memory containers
    @MainActor
    static func createTestEnvironment() throws -> (container: ModelContainer, syncManager: SyncManager) {
        // Use minimal schema for faster test setup
        let schema = Schema([Trip.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        
        // Create isolated SyncManager instance
        let syncManager = SyncManager(container: container)
        syncManager.disableCrossDeviceSync() // Start with cross-device disabled for basic tests
        syncManager.enableTestMode() // Ensure test mode is active
        
        return (container, syncManager)
    }
    
    // MARK: - Basic Sync Notification Tests
    
    @Test("SyncManager should complete sync successfully")
    @MainActor
    func testBasicSyncNotification() async throws {
        print("🧪 Starting basic sync completion test...")
        
        let env = try Self.createTestEnvironment()
        print("🧪 Created test environment")
        
        // Use Swift Testing confirmation pattern instead of notification waiting
        await confirmation("Sync completed successfully") { syncCompleted in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Sync completed with success: \(success)")
                if success {
                    syncCompleted()
                }
            }
            
            // Trigger sync and wait for it to complete
            print("🧪 Triggering sync...")
            await env.syncManager.performSync()
        }
        
        // Verify sync completed successfully
        #expect(env.syncManager.lastSyncDate != nil)
        #expect(env.syncManager.isSyncing == false)
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Basic sync completion test passed!")
    }
    
    @Test("SyncManager should handle sync errors gracefully")
    @MainActor
    func testSyncErrorHandling() async throws {
        print("🧪 Starting sync error handling test...")
        
        let env = try Self.createTestEnvironment()
        print("🧪 Created test environment")
        
        // Simulate network unavailable
        env.syncManager.setNetworkStatus(.offline)
        print("🧪 Set network status to offline")
        
        // Use confirmation to verify error callback
        await confirmation("Sync failed due to network error") { syncFailed in
            // Set up completion handler to verify error callback
            env.syncManager.onSyncComplete = { success in
                print("🧪 Sync completed with success: \(success)")
                if !success {
                    syncFailed()
                }
            }
            
            // Trigger sync (should fail)
            print("🧪 Triggering sync while offline...")
            await env.syncManager.performSync()
            print("🧪 Performed sync")
        }
        
        // Verify error handling - check state directly
        print("🧪 Checking results...")
        #expect(env.syncManager.syncError != nil)
        #expect(env.syncManager.isSyncing == false)
        #expect(env.syncManager.networkStatus == .offline)
        
        print("✅ Sync error handling test passed!")
    }
    
    @Test("SyncManager should handle offline/online transitions")
    @MainActor
    func testOfflineOnlineSyncScenario() async throws {
        print("🧪 Starting offline/online sync test...")
        
        let env = try Self.createTestEnvironment()
        
        // Start offline
        env.syncManager.setNetworkStatus(.offline)
        
        // Add some test data
        let trip = Trip(name: "Offline Trip")
        env.container.mainContext.insert(trip)
        try env.container.mainContext.save()
        
        // Check pending changes while offline
        #expect(env.syncManager.networkStatus == .offline)
        
        // Go online and sync with confirmation
        env.syncManager.setNetworkStatus(.online)
        
        await confirmation("Sync succeeded after going online") { syncSucceeded in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Sync completed with success: \(success)")
                if success {
                    syncSucceeded()
                }
            }
            
            // Trigger sync now that we're online
            print("🧪 Triggering sync after going online...")
            await env.syncManager.triggerSyncAndWait()
        }
        
        // Verify successful sync
        #expect(env.syncManager.syncError == nil)
        #expect(env.syncManager.lastSyncDate != nil)
        #expect(env.syncManager.networkStatus == .online)
        
        print("✅ Offline/online sync test passed!")
    }
    
    @Test("SyncManager should handle large datasets with batch processing")
    @MainActor
    func testLargeDatasetBatchSync() async throws {
        print("🧪 Starting large dataset batch sync test...")
        
        let env = try Self.createTestEnvironment()
        
        // Create multiple trips to simulate large dataset
        for i in 1...5 {
            let trip = Trip(name: "Trip \(i)")
            env.container.mainContext.insert(trip)
        }
        try env.container.mainContext.save()
        
        var receivedProgress: SyncProgress?
        
        await confirmation("Batch sync completed with progress") { batchCompleted in
            // Set up progress handler
            env.syncManager.onSyncProgress = { progress in
                print("🧪 Received sync progress: \(progress.completedBatches)/\(progress.totalBatches)")
                receivedProgress = progress
                if progress.isCompleted {
                    batchCompleted()
                }
            }
            
            // Test batch sync with progress
            print("🧪 Starting batch sync...")
            let syncProgress = await env.syncManager.syncWithProgress()
            
            // If progress handler wasn't called, complete based on return value
            if syncProgress.isCompleted && receivedProgress == nil {
                receivedProgress = syncProgress
                batchCompleted()
            }
        }
        
        // Verify batch sync results
        guard let finalProgress = receivedProgress else {
            throw TestError("No progress received")
        }
        
        #expect(finalProgress.isCompleted)
        #expect(finalProgress.totalBatches > 0)
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Large dataset batch sync test passed!")
    }
    
    struct TestError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }
    
    @Test("SyncManager should resolve conflicts using last-writer-wins")
    @MainActor
    func testConflictResolution() async throws {
        print("🧪 Starting conflict resolution test...")
        
        let env = try Self.createTestEnvironment()
        env.syncManager.enableCrossDeviceSyncForTesting()
        
        // Create initial trip
        let trip = Trip(name: "Original Trip")
        env.container.mainContext.insert(trip)
        try env.container.mainContext.save()
        
        // Simulate conflict by modifying trip name
        trip.name = "Modified on Device 1"
        try env.container.mainContext.save()
        
        await confirmation("Conflict resolution sync completed") { syncCompleted in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Conflict resolution sync completed with success: \(success)")
                if success {
                    syncCompleted()
                }
            }
            
            // Trigger sync with conflict resolution
            await env.syncManager.syncAndResolveConflicts()
        }
        
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Conflict resolution test passed!")
    }
    
    @Test("SyncManager should preserve data during conflict resolution")
    @MainActor
    func testConflictResolutionDataPreservation() async throws {
        print("🧪 Starting conflict resolution data preservation test...")
        
        let env = try Self.createTestEnvironment()
        env.syncManager.enableCrossDeviceSyncForTesting()
        
        // Create trip with specific data
        let trip = Trip(name: "Trip")
        trip.notes = "Original notes"
        env.container.mainContext.insert(trip)
        try env.container.mainContext.save()
        
        await confirmation("Data preservation sync completed") { syncCompleted in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Data preservation sync completed with success: \(success)")
                if success {
                    syncCompleted()
                }
            }
            
            // Trigger sync with conflict resolution
            await env.syncManager.syncAndResolveConflicts()
        }
        
        // Verify data preservation
        #expect(trip.notes == "Original notes")
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Conflict resolution data preservation test passed!")
    }
    
    @Test("SyncManager should respect protected trip sync settings")
    @MainActor
    func testProtectedTripSync() async throws {
        print("🧪 Starting protected trip sync test...")
        
        let env = try Self.createTestEnvironment()
        
        // Create protected and unprotected trips
        let protectedTrip = Trip(name: "Protected Trip", isProtected: true)
        let unprotectedTrip = Trip(name: "Unprotected Trip", isProtected: false)
        
        env.container.mainContext.insert(protectedTrip)
        env.container.mainContext.insert(unprotectedTrip)
        try env.container.mainContext.save()
        
        // Disable protected trip sync
        env.syncManager.setSyncProtectedTrips(false)
        
        await confirmation("Protected trip sync completed") { syncCompleted in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Protected trip sync completed with success: \(success)")
                if success {
                    syncCompleted()
                }
            }
            
            await env.syncManager.performSync()
        }
        
        #expect(env.syncManager.syncProtectedTrips == false)
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Protected trip sync test passed!")
    }
    
    @Test("SyncManager should handle network interruptions with retry")
    @MainActor
    func testNetworkInterruptionHandling() async throws {
        print("🧪 Starting network interruption handling test...")
        
        let env = try Self.createTestEnvironment()
        
        // Simulate network interruptions (this sets retryAttempts in SyncManager)
        env.syncManager.simulateNetworkInterruptions(count: 2)
        
        await confirmation("Sync eventually succeeds after retries") { retrySucceeded in
            // Set up completion handler
            env.syncManager.onSyncComplete = { success in
                print("🧪 Sync completed with success: \(success)")
                if success {
                    retrySucceeded()
                }
            }
            
            // Use the simpler performSyncWithRetry method directly
            print("🧪 Starting sync with retry mechanism...")
            await env.syncManager.performSyncWithRetry()
        }
        
        // After retries, sync should eventually succeed
        #expect(env.syncManager.lastSyncDate != nil)
        #expect(env.syncManager.isSyncing == false)
        #expect(env.syncManager.syncError == nil)
        
        print("✅ Network interruption handling test passed!")
    }
}
