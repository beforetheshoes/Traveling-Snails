//
//  CKShareManager.swift
//  Traveling Snails
//
//

import CloudKit
import Foundation
import SwiftData

/// Manager for CloudKit sharing operations
/// Handles creation, management, and deletion of CKShare records
@MainActor
final class CKShareManager {

    // MARK: - Properties

    /// CloudKit container for share operations
    private let container: CKContainer

    /// Private database for share operations
    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    /// Custom zone for shared records
    private let customZone = CKRecordZone(zoneName: "TripSharing")

    /// Cache of created zones to avoid duplicate creation
    private var createdZones: Set<CKRecordZone.ID> = []
    
    // MARK: - Initialization
    
    init(container: CKContainer = CKContainer.default()) {
        self.container = container
    }
    
    // MARK: - Zone Management
    
    /// Create a custom zone for sharing if it doesn't exist
    /// - Parameter zoneName: Name of the zone to create
    /// - Returns: The created or existing zone
    func createCustomZone(named zoneName: String) async throws -> CKRecordZone {
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        
        // Check if we already created this zone
        if createdZones.contains(zoneID) {
            return CKRecordZone(zoneID: zoneID)
        }
        
        do {
            // Check if zone already exists
            let existingZone = try await privateDatabase.recordZone(for: zoneID)
            createdZones.insert(zoneID)
            Logger.shared.info("Custom zone '\(zoneName)' already exists", category: .cloudKit)
            return existingZone
        } catch {
            // Zone doesn't exist, create it
            Logger.shared.info("Creating custom zone '\(zoneName)'", category: .cloudKit)
            let newZone = CKRecordZone(zoneID: zoneID)
            let savedZone = try await privateDatabase.save(newZone)
            createdZones.insert(zoneID)
            Logger.shared.info("Custom zone '\(zoneName)' created successfully", category: .cloudKit)
            return savedZone
        }
    }
    
    // MARK: - Record Management
    
    /// Create a CloudKit record for a Trip
    /// - Parameters:
    ///   - trip: The trip to create a record for
    ///   - zoneName: Name of the zone to create the record in
    /// - Returns: The created CKRecord
    func createRecord(for trip: Trip, in zoneName: String) async throws -> CKRecord {
        // Ensure the zone exists
        let zone = try await createCustomZone(named: zoneName)
        
        // Create the record
        let recordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zone.zoneID)
        let record = CKRecord(recordType: "Trip", recordID: recordID)
        
        // Populate record fields
        record["name"] = trip.name as CKRecordValue
        record["notes"] = trip.notes as CKRecordValue
        record["isProtected"] = trip.isProtected as CKRecordValue
        record["createdDate"] = trip.createdDate as CKRecordValue
        
        // Add date fields if set
        if trip.hasStartDate {
            record["startDate"] = trip.startDate as CKRecordValue
            record["hasStartDate"] = true as CKRecordValue
        }
        
        if trip.hasEndDate {
            record["endDate"] = trip.endDate as CKRecordValue
            record["hasEndDate"] = true as CKRecordValue
        }
        
        // Save the record
        let savedRecord = try await privateDatabase.save(record)
        
        Logger.shared.info("Created CloudKit record for trip: \(trip.id)", category: .cloudKit)
        
        return savedRecord
    }
    
    // MARK: - Share Management
    
    /// Create a CKShare for a given record
    /// - Parameter record: The root record to share
    /// - Returns: The created CKShare
    func createShare(for record: CKRecord) async throws -> CKShare {
        Logger.shared.info("Creating share for record: \(record.recordID)", category: .cloudKit)
        
        // Create the share
        let share = CKShare(rootRecord: record)
        
        // Configure share properties
        share[CKShare.SystemFieldKey.title] = record["name"] ?? "Shared Trip"
        share.publicPermission = .none // Private sharing only
        
        // Save the share
        let savedRecord = try await privateDatabase.save(share)
        
        guard let savedShare = savedRecord as? CKShare else {
            throw CKShareManagerError.invalidShareRecord
        }
        
        Logger.shared.info("Share created successfully for record: \(record.recordID)", category: .cloudKit)
        
        return savedShare
    }
    
    /// Add a participant to a share using email or phone
    /// - Parameters:
    ///   - share: The share to add the participant to
    ///   - emailOrPhone: The email address or phone number of the participant
    ///   - permission: The permission level for the participant
    /// - Returns: The updated share
    func addParticipant(
        to share: CKShare,
        emailOrPhone: String,
        permission: CKShare.ParticipantPermission
    ) async throws -> CKShare {
        Logger.shared.info("Adding participant to share: \(share.recordID)", category: .cloudKit)
        
        // Note: In a real implementation, you would need to look up the user identity
        // using CKContainer.discoverUserIdentity methods
        // For now, this is a placeholder that shows the intended interface
        
        // This would require additional implementation to:
        // 1. Discover user identity from email/phone
        // 2. Create and add the participant
        // 3. Save the updated share
        
        Logger.shared.warning("Participant addition not fully implemented - requires user identity discovery", category: .cloudKit)
        
        return share
    }
    
    /// Remove a participant from a share by participant index
    /// - Parameters:
    ///   - share: The share to remove the participant from
    ///   - participantIndex: The index of the participant to remove
    /// - Returns: The updated share
    func removeParticipant(from share: CKShare, at participantIndex: Int) async throws -> CKShare {
        Logger.shared.info("Removing participant from share: \(share.recordID)", category: .cloudKit)
        
        guard participantIndex < share.participants.count else {
            throw CKShareManagerError.participantNotFound
        }
        
        let participant = share.participants[participantIndex]
        share.removeParticipant(participant)
        
        // Save the updated share
        let savedRecord = try await privateDatabase.save(share)
        
        guard let updatedShare = savedRecord as? CKShare else {
            throw CKShareManagerError.invalidShareRecord
        }
        
        Logger.shared.info("Participant removed successfully from share: \(share.recordID)", category: .cloudKit)
        
        return updatedShare
    }
    
    /// Update permissions for a participant by index
    /// - Parameters:
    ///   - share: The share containing the participant
    ///   - participantIndex: The index of the participant to update
    ///   - permission: The new permission level
    /// - Returns: The updated share
    func updateParticipantPermission(
        in share: CKShare,
        at participantIndex: Int,
        to permission: CKShare.ParticipantPermission
    ) async throws -> CKShare {
        Logger.shared.info("Updating participant permission in share: \(share.recordID)", category: .cloudKit)
        
        guard participantIndex < share.participants.count else {
            throw CKShareManagerError.participantNotFound
        }
        
        // Update participant permission
        share.participants[participantIndex].permission = permission
        
        // Save the updated share
        let savedRecord = try await privateDatabase.save(share)
        
        guard let updatedShare = savedRecord as? CKShare else {
            throw CKShareManagerError.invalidShareRecord
        }
        
        Logger.shared.info("Participant permission updated successfully in share: \(share.recordID)", category: .cloudKit)
        
        return updatedShare
    }
    
    /// Delete a share
    /// - Parameter shareID: The ID of the share to delete
    func deleteShare(with shareID: CKRecord.ID) async throws {
        Logger.shared.info("Deleting share: \(shareID)", category: .cloudKit)
        
        // Delete the share record
        _ = try await privateDatabase.deleteRecord(withID: shareID)
        
        Logger.shared.info("Share deleted successfully: \(shareID)", category: .cloudKit)
    }
    
    /// Fetch a share by ID
    /// - Parameter shareID: The ID of the share to fetch
    /// - Returns: The fetched share
    func fetchShare(with shareID: CKRecord.ID) async throws -> CKShare {
        Logger.shared.info("Fetching share: \(shareID)", category: .cloudKit)
        
        let record = try await privateDatabase.record(for: shareID)
        
        guard let share = record as? CKShare else {
            throw CKShareManagerError.invalidShareRecord
        }
        
        Logger.shared.info("Share fetched successfully: \(shareID)", category: .cloudKit)
        
        return share
    }
    
    // MARK: - Share URL Management
    
    /// Generate a sharing URL for a share
    /// - Parameter share: The share to generate a URL for
    /// - Returns: The sharing URL
    func generateSharingURL(for share: CKShare) -> URL? {
        Logger.shared.info("Generating sharing URL for share: \(share.recordID)", category: .cloudKit)
        return share.url
    }
    
    /// Accept a share using its metadata
    /// - Parameter shareMetadata: The share metadata from an invitation
    /// - Returns: The accepted share
    func acceptShare(with shareMetadata: CKShare.Metadata) async throws -> CKShare {
        Logger.shared.info("Accepting share with metadata", category: .cloudKit)
        
        // Use async/await pattern for CloudKit operation
        return try await withCheckedThrowingContinuation { continuation in
            let acceptOperation = CKAcceptSharesOperation(shareMetadatas: [shareMetadata])
            
            acceptOperation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    Logger.shared.info("Share accepted successfully", category: .cloudKit)
                    continuation.resume(returning: shareMetadata.share)
                case .failure(let error):
                    Logger.shared.logError(error, message: "Failed to accept share", category: .cloudKit)
                    continuation.resume(throwing: error)
                }
            }
            
            container.add(acceptOperation)
        }
    }
}

// MARK: - Error Types

enum CKShareManagerError: LocalizedError {
    case invalidShareRecord
    case shareAcceptanceFailed
    case participantNotFound
    case permissionUpdateFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidShareRecord:
            return "The fetched record is not a valid CKShare"
        case .shareAcceptanceFailed:
            return "Failed to accept the CloudKit share"
        case .participantNotFound:
            return "The specified participant was not found in the share"
        case .permissionUpdateFailed:
            return "Failed to update participant permissions"
        }
    }
}