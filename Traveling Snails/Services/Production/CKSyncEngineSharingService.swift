//
//  CKSyncEngineSharingService.swift
//  Traveling Snails
//
//

import CloudKit
import Foundation
import Observation
import SwiftData

/// CKSyncEngine-based implementation for CloudKit sharing with SwiftData
/// This service provides sharing capabilities while maintaining compatibility with SwiftData
@MainActor
@Observable
final class CKSyncEngineSharingService: CloudKitSyncService {
    
    // MARK: - Sharing Properties
    
    /// The CKSyncEngine instance for managing CloudKit sync and sharing
    private var syncEngine: CKSyncEngine?
    
    /// CloudKit container for sharing operations
    private let cloudKitContainer: CKContainer
    
    /// Custom zone for shared records (default zone doesn't support sharing)
    private let customZone = CKRecordZone(zoneName: "TripSharing")
    
    /// Track active shares by trip ID
    private var activeShares: [UUID: CKShare] = [:]
    
    /// Track share operations in progress
    private var shareOperations: [UUID: Task<CKShare, Error>] = [:]
    
    // MARK: - Initialization
    
    override init(modelContainer: ModelContainer) {
        self.cloudKitContainer = CKContainer.default()
        super.init(modelContainer: modelContainer)
    }
    
    // MARK: - CKSyncEngine Setup
    
    /// Initialize the CKSyncEngine with sharing configuration
    private func setupSyncEngine() async throws {
        guard syncEngine == nil else { return }
        
        Logger.shared.info("Setting up CKSyncEngine for sharing", category: .cloudKit)
        
        // Create the custom zone for sharing
        try await createCustomZoneIfNeeded()
        
        // Configure CKSyncEngine
        let configuration = CKSyncEngine.Configuration(
            database: cloudKitContainer.privateCloudDatabase,
            stateSerialization: nil,
            delegate: self
        )
        
        syncEngine = CKSyncEngine(configuration)
        
        Logger.shared.info("CKSyncEngine configured successfully for sharing", category: .cloudKit)
    }
    
    /// Create the custom zone required for sharing
    private func createCustomZoneIfNeeded() async throws {
        let database = cloudKitContainer.privateCloudDatabase
        
        do {
            // Check if zone already exists
            _ = try await database.recordZone(for: customZone.zoneID)
            Logger.shared.info("Custom zone '\(customZone.zoneID.zoneName)' already exists", category: .cloudKit)
        } catch {
            // Zone doesn't exist, create it
            Logger.shared.info("Creating custom zone '\(customZone.zoneID.zoneName)' for sharing", category: .cloudKit)
            _ = try await database.save(customZone)
            Logger.shared.info("Custom zone '\(customZone.zoneID.zoneName)' created successfully", category: .cloudKit)
        }
    }
    
    // MARK: - Sharing Interface
    
    /// Create a share for a trip
    /// - Parameter trip: The trip to share
    /// - Returns: The created CKShare
    func createShare(for trip: Trip) async throws -> CKShare {
        // Ensure CKSyncEngine is set up
        try await setupSyncEngine()
        
        // Check if share already exists
        if let existingShare = activeShares[trip.id] {
            Logger.shared.info("Share already exists for trip: \(trip.id)", category: .cloudKit)
            return existingShare
        }
        
        // Check if share operation is already in progress
        if let ongoingOperation = shareOperations[trip.id] {
            Logger.shared.info("Share creation already in progress for trip: \(trip.id)", category: .cloudKit)
            return try await ongoingOperation.value
        }
        
        // Start new share creation
        let shareTask = Task<CKShare, Error> {
            try await performShareCreation(for: trip)
        }
        
        shareOperations[trip.id] = shareTask
        
        do {
            let share = try await shareTask.value
            shareOperations.removeValue(forKey: trip.id)
            activeShares[trip.id] = share
            
            // Update trip with share metadata
            trip.shareID = share.recordID
            
            Logger.shared.info("Share created successfully for trip: \(trip.id)", category: .cloudKit)
            return share
        } catch {
            shareOperations.removeValue(forKey: trip.id)
            Logger.shared.logError(error, message: "Failed to create share for trip: \(trip.id)", category: .cloudKit)
            throw error
        }
    }
    
    /// Remove sharing for a trip
    /// - Parameter trip: The trip to stop sharing
    func removeShare(for trip: Trip) async throws {
        guard let shareID = trip.shareID else {
            Logger.shared.warning("No share to remove for trip: \(trip.id)", category: .cloudKit)
            return
        }
        
        try await setupSyncEngine()
        
        Logger.shared.info("Removing share for trip: \(trip.id)", category: .cloudKit)
        
        let database = cloudKitContainer.privateCloudDatabase
        
        do {
            // Delete the share record
            _ = try await database.deleteRecord(withID: shareID)
            
            // Clean up local tracking
            activeShares.removeValue(forKey: trip.id)
            trip.shareID = nil
            
            Logger.shared.info("Share removed successfully for trip: \(trip.id)", category: .cloudKit)
        } catch {
            Logger.shared.logError(error, message: "Failed to remove share for trip: \(trip.id)", category: .cloudKit)
            throw error
        }
    }
    
    /// Accept a shared trip from an invitation
    /// - Parameter shareMetadata: The share metadata from the invitation
    /// - Returns: The accepted trip
    func acceptShare(with shareMetadata: CKShare.Metadata) async throws -> Trip? {
        try await setupSyncEngine()
        
        Logger.shared.info("Accepting share with metadata: \(shareMetadata.share.recordID)", category: .cloudKit)
        
        let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
        
        return try await withCheckedThrowingContinuation { continuation in
            acceptOperation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    Logger.shared.info("Share accepted successfully", category: .cloudKit)
                    // Here we would fetch the shared trip data
                    // For now, return nil as this requires additional implementation
                    continuation.resume(returning: nil)
                case .failure(let error):
                    Logger.shared.logError(error, message: "Failed to accept share", category: .cloudKit)
                    continuation.resume(throwing: error)
                }
            }
            
            cloudKitContainer.add(acceptOperation)
        }
    }
    
    /// Get sharing status for a trip
    /// - Parameter trip: The trip to check
    /// - Returns: Sharing information
    func getSharingInfo(for trip: Trip) async -> TripSharingInfo {
        guard let shareID = trip.shareID else {
            return TripSharingInfo(
                isShared: false,
                participants: [],
                shareURL: nil,
                permissions: []
            )
        }
        
        // Check if we have the share cached
        if let share = activeShares[trip.id] {
            return TripSharingInfo(
                isShared: true,
                participants: share.participants.map { $0.userIdentity.nameComponents?.formatted() ?? "Unknown" },
                shareURL: share.url,
                permissions: share.participants.map { participant in
                    switch participant.permission {
                    case .readOnly:
                        return .readOnly
                    case .readWrite:
                        return .readWrite
                    default:
                        return .readOnly
                    }
                }
            )
        }
        
        // Fetch share from CloudKit if not cached
        do {
            try await setupSyncEngine()
            let database = cloudKitContainer.privateCloudDatabase
            let share = try await database.record(for: shareID) as? CKShare
            
            if let share = share {
                activeShares[trip.id] = share
                return TripSharingInfo(
                    isShared: true,
                    participants: share.participants.map { $0.userIdentity.nameComponents?.formatted() ?? "Unknown" },
                    shareURL: share.url,
                    permissions: share.participants.map { participant in
                        switch participant.permission {
                        case .readOnly:
                            return .readOnly
                        case .readWrite:
                            return .readWrite
                        default:
                            return .readOnly
                        }
                    }
                )
            }
        } catch {
            Logger.shared.logError(error, message: "Failed to fetch sharing info for trip: \(trip.id)", category: .cloudKit)
        }
        
        return TripSharingInfo(
            isShared: false,
            participants: [],
            shareURL: nil,
            permissions: []
        )
    }
    
    // MARK: - Private Implementation
    
    /// Perform the actual share creation
    private func performShareCreation(for trip: Trip) async throws -> CKShare {
        guard syncEngine != nil else {
            throw CloudKitSharingError.syncEngineNotInitialized
        }
        
        Logger.shared.info("Creating CKRecord for trip: \(trip.id)", category: .cloudKit)
        
        // Create CKRecord for the trip in the custom zone
        let tripRecord = CKRecord(
            recordType: "Trip",
            recordID: CKRecord.ID(recordName: trip.id.uuidString, zoneID: customZone.zoneID)
        )
        
        // Populate record fields
        tripRecord["name"] = trip.name as CKRecordValue
        tripRecord["notes"] = trip.notes as CKRecordValue
        tripRecord["isProtected"] = trip.isProtected as CKRecordValue
        
        if trip.hasStartDate {
            tripRecord["startDate"] = trip.startDate as CKRecordValue
        }
        
        if trip.hasEndDate {
            tripRecord["endDate"] = trip.endDate as CKRecordValue
        }
        
        // Save the record first
        let database = cloudKitContainer.privateCloudDatabase
        let savedRecord = try await database.save(tripRecord)
        
        Logger.shared.info("Trip record saved, creating share", category: .cloudKit)
        
        // Create the share
        let share = CKShare(rootRecord: savedRecord)
        share[CKShare.SystemFieldKey.title] = trip.name as CKRecordValue
        share.publicPermission = .none // Private sharing only
        
        // Save the share
        let savedShareRecord = try await database.save(share)
        
        guard let savedShare = savedShareRecord as? CKShare else {
            throw CloudKitSharingError.shareCreationFailed("Failed to save share record")
        }
        
        Logger.shared.info("Share created successfully for trip: \(trip.id)", category: .cloudKit)
        
        return savedShare
    }
}

// MARK: - CKSyncEngineDelegate

extension CKSyncEngineSharingService: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let stateUpdate):
            await handleStateUpdate(stateUpdate)
        case .accountChange(let accountChange):
            await handleAccountChange(accountChange)
        case .fetchedDatabaseChanges(let databaseChanges):
            await handleFetchedDatabaseChanges(databaseChanges)
        case .fetchedRecordZoneChanges(let zoneChanges):
            await handleFetchedRecordZoneChanges(zoneChanges)
        case .sentDatabaseChanges(let sentChanges):
            await handleSentDatabaseChanges(sentChanges)
        case .sentRecordZoneChanges(let sentZoneChanges):
            await handleSentRecordZoneChanges(sentZoneChanges)
        case .willFetchChanges:
            Logger.shared.info("CKSyncEngine will fetch changes", category: .cloudKit)
        case .willFetchRecordZoneChanges(let zoneIDs):
            Logger.shared.info("CKSyncEngine will fetch zone changes: \(zoneIDs)", category: .cloudKit)
        case .didFetchChanges:
            Logger.shared.info("CKSyncEngine did fetch changes", category: .cloudKit)
        case .didFetchRecordZoneChanges(let zoneIDs):
            Logger.shared.info("CKSyncEngine did fetch zone changes: \(zoneIDs)", category: .cloudKit)
        case .willSendChanges:
            Logger.shared.info("CKSyncEngine will send changes", category: .cloudKit)
        case .didSendChanges:
            Logger.shared.info("CKSyncEngine did send changes", category: .cloudKit)
        @unknown default:
            Logger.shared.warning("Unknown CKSyncEngine event received", category: .cloudKit)
        }
    }
    
    private func handleStateUpdate(_ stateUpdate: CKSyncEngine.Event.StateUpdate) async {
        Logger.shared.info("CKSyncEngine state update received", category: .cloudKit)
    }
    
    private func handleAccountChange(_ accountChange: CKSyncEngine.Event.AccountChange) async {
        Logger.shared.info("CKSyncEngine account change: \(accountChange.changeType)", category: .cloudKit)
        
        // Clear active shares if account changed
        // Note: The exact change type enum values may differ in actual CloudKit API
        Logger.shared.info("Clearing shares due to account change", category: .cloudKit)
        activeShares.removeAll()
    }
    
    private func handleFetchedDatabaseChanges(_ databaseChanges: CKSyncEngine.Event.FetchedDatabaseChanges) async {
        Logger.shared.info("CKSyncEngine fetched database changes: \(databaseChanges.modifications.count) modifications, \(databaseChanges.deletions.count) deletions", category: .cloudKit)
    }
    
    private func handleFetchedRecordZoneChanges(_ zoneChanges: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        Logger.shared.info("CKSyncEngine fetched zone changes", category: .cloudKit)
        
        // Process share modifications
        for modification in zoneChanges.modifications {
            if let share = modification.record as? CKShare {
                await processShareModification(share)
            }
        }
        
        // Process share deletions
        for deletion in zoneChanges.deletions {
            await processShareDeletion(deletion.recordID)
        }
    }
    
    private func handleSentDatabaseChanges(_ sentChanges: CKSyncEngine.Event.SentDatabaseChanges) async {
        Logger.shared.info("CKSyncEngine sent database changes", category: .cloudKit)
    }
    
    private func handleSentRecordZoneChanges(_ sentZoneChanges: CKSyncEngine.Event.SentRecordZoneChanges) async {
        Logger.shared.info("CKSyncEngine sent zone changes", category: .cloudKit)
    }
    
    private func processShareModification(_ share: CKShare) async {
        Logger.shared.info("Processing share modification: \(share.recordID)", category: .cloudKit)
        
        // Find the trip associated with this share
        // Note: In the actual implementation, you would need to fetch the root record
        // For now, we'll use a simplified approach
        guard let tripUUID = UUID(uuidString: share.recordID.recordName) else {
            Logger.shared.warning("Could not extract trip ID from share record", category: .cloudKit)
            return
        }
        
        // Update the cached share
        activeShares[tripUUID] = share
        
        Logger.shared.info("Updated cached share for trip: \(tripUUID)", category: .cloudKit)
    }
    
    private func processShareDeletion(_ recordID: CKRecord.ID) async {
        Logger.shared.info("Processing share deletion: \(recordID)", category: .cloudKit)
        
        // Find and remove the share from cache
        for (tripID, share) in activeShares {
            if share.recordID == recordID {
                activeShares.removeValue(forKey: tripID)
                Logger.shared.info("Removed cached share for trip: \(tripID)", category: .cloudKit)
                break
            }
        }
    }
    
    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        // For now, return nil as we're not implementing custom sync logic
        // This would be used for more advanced sync scenarios
        return nil
    }
}

// MARK: - Supporting Types

/// Information about a trip's sharing status
struct TripSharingInfo: Sendable {
    let isShared: Bool
    let participants: [String]
    let shareURL: URL?
    let permissions: [TripSharingPermission]
}

/// Sharing permission levels
enum TripSharingPermission: Sendable {
    case read
    case readOnly
    case readWrite
    case readWriteDelete
}

/// Errors specific to CloudKit sharing
enum CloudKitSharingError: LocalizedError {
    case syncEngineNotInitialized
    case customZoneCreationFailed
    case shareCreationFailed(String)
    case shareNotFound
    case invalidShareMetadata
    
    var errorDescription: String? {
        switch self {
        case .syncEngineNotInitialized:
            return "CKSyncEngine has not been initialized"
        case .customZoneCreationFailed:
            return "Failed to create custom CloudKit zone for sharing"
        case .shareCreationFailed(let details):
            return "Failed to create CloudKit share: \(details)"
        case .shareNotFound:
            return "CloudKit share not found"
        case .invalidShareMetadata:
            return "Invalid share metadata provided"
        }
    }
}