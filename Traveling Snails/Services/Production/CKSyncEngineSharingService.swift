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
    
    /// Rate limiting for excessive event processing
    private var lastEventLogTime: Date = Date()
    private var eventProcessingCount: Int = 0
    private let eventLoggingThreshold: Int = 100 // Log every 100 events after threshold
    
    // MARK: - Initialization
    
    override init(modelContainer: ModelContainer) {
        // Use the correct container identifier from entitlements
        self.cloudKitContainer = CKContainer(identifier: "iCloud.TravelingSnails")
        super.init(modelContainer: modelContainer)
    }
    
    // MARK: - CloudKit Validation
    
    /// Validate CloudKit account and container status
    private func validateCloudKitStatus() async throws {
        Logger.shared.info("Validating CloudKit account status", category: .cloudKit)
        
        // Check account status
        let accountStatus = try await cloudKitContainer.accountStatus()
        Logger.shared.info("CloudKit account status: \(accountStatus.rawValue)", category: .cloudKit)
        
        switch accountStatus {
        case .couldNotDetermine:
            throw CloudKitSharingError.accountStatusUnavailable
        case .noAccount:
            throw CloudKitSharingError.noICloudAccount
        case .restricted:
            throw CloudKitSharingError.accountRestricted
        case .available:
            Logger.shared.info("CloudKit account is available", category: .cloudKit)
        case .temporarilyUnavailable:
            throw CloudKitSharingError.accountTemporarilyUnavailable
        @unknown default:
            throw CloudKitSharingError.unknownAccountStatus
        }
        
        // Note: User discoverability permissions are deprecated in iOS 17+
        // CloudKit sharing should work without explicit permission requests
        Logger.shared.info("CloudKit account validated - sharing should be available", category: .cloudKit)
        
        // Additional diagnostics for Mac environment
        Logger.shared.info("Device info - Model: \(ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Unknown"), Platform: \(ProcessInfo.processInfo.environment["PLATFORM_NAME"] ?? "Unknown")", category: .cloudKit)
        
        #if targetEnvironment(macCatalyst)
        Logger.shared.info("Running under Mac Catalyst", category: .cloudKit)
        #else
        Logger.shared.info("Not running under Mac Catalyst", category: .cloudKit)
        #endif
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
        // Validate CloudKit availability first
        try await validateCloudKitStatus()
        
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
        
        // For SwiftData + CloudKit sharing, we need to share the existing SwiftData record
        // First, get the actual CloudKit record for this SwiftData Trip
        let database = cloudKitContainer.privateCloudDatabase
        
        // SwiftData uses the default zone, but we need to move to custom zone for sharing
        let defaultZoneRecordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: CKRecordZone.default().zoneID)
        
        Logger.shared.info("Fetching existing Trip record from SwiftData/CloudKit", category: .cloudKit)
        
        let savedShare: CKShare
        
        do {
            // Try to fetch the existing record from the default zone
            let existingRecord = try await database.record(for: defaultZoneRecordID)
            Logger.shared.info("Found existing Trip record: \(existingRecord.recordID)", category: .cloudKit)
            
            // Create a new record in the custom zone with the same data
            let customZoneRecordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: customZone.zoneID)
            let tripRecordForSharing = CKRecord(recordType: existingRecord.recordType, recordID: customZoneRecordID)
            
            // Copy all the fields from the existing record
            for key in existingRecord.allKeys() {
                tripRecordForSharing[key] = existingRecord[key]
            }
            
            // Create the share
            let share = CKShare(rootRecord: tripRecordForSharing)
            share[CKShare.SystemFieldKey.title] = trip.name as CKRecordValue
            share.publicPermission = .none // Private sharing only
            
            Logger.shared.info("Created share for existing Trip record", category: .cloudKit)
            
            Logger.shared.info("Trip record and share created - Share ID: \(share.recordID), Root record: \(tripRecordForSharing.recordID)", category: .cloudKit)
            Logger.shared.info("Share properties before save - URL: \(share.url?.absoluteString ?? "nil"), Participants: \(share.participants.count)", category: .cloudKit)
            
            // CloudKit requires saving the root record and share together atomically
            Logger.shared.info("Saving trip record and share together atomically", category: .cloudKit)
            
            try await withCheckedThrowingContinuation { continuation in
                let operation = CKModifyRecordsOperation(recordsToSave: [tripRecordForSharing, share], recordIDsToDelete: nil)
                
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        Logger.shared.info("Trip record and share saved successfully", category: .cloudKit)
                        Logger.shared.info("Share properties after save - URL: \(share.url?.absoluteString ?? "nil"), Participants: \(share.participants.count)", category: .cloudKit)
                        continuation.resume(returning: ())
                    case .failure(let error):
                        Logger.shared.logError(error, message: "Failed to save trip record and share together", category: .cloudKit)
                        continuation.resume(throwing: error)
                    }
                }
                
                database.add(operation)
            }
            
            savedShare = share
            
        } catch {
            Logger.shared.logError(error, message: "Could not find existing Trip record for sharing", category: .cloudKit)
            
            // Check if this is a "record not found" error (common when SwiftData hasn't synced yet)
            if let ckError = error as? CKError, ckError.code == .unknownItem {
                throw CloudKitSharingError.shareCreationFailed("This trip hasn't synced to iCloud yet. Please wait a moment and try again.")
            } else {
                throw CloudKitSharingError.shareCreationFailed("Could not access trip in iCloud. Error: \(error.localizedDescription)")
            }
        }
        
        Logger.shared.info("Share created successfully for trip: \(trip.id), URL: \(savedShare.url?.absoluteString ?? "none")", category: .cloudKit)
        
        // CloudKit may not immediately populate the share URL after creation
        // Try multiple strategies to get the populated URL
        if savedShare.url == nil {
            Logger.shared.info("Share URL is nil, attempting multiple recovery strategies for trip: \(trip.id)", category: .cloudKit)
            
            // Strategy 1: Wait briefly and check again (sometimes CloudKit needs a moment)
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            if savedShare.url != nil {
                Logger.shared.info("Share URL populated after brief wait: \(savedShare.url!.absoluteString)", category: .cloudKit)
                return savedShare
            }
            
            // Strategy 2: Refetch from private database
            do {
                if let refetchedShare = try await database.record(for: savedShare.recordID) as? CKShare {
                    Logger.shared.info("Refetched share from private DB for trip: \(trip.id), URL: \(refetchedShare.url?.absoluteString ?? "still none")", category: .cloudKit)
                    if refetchedShare.url != nil {
                        return refetchedShare
                    }
                }
            } catch {
                Logger.shared.logError(error, message: "Failed to refetch share", category: .cloudKit)
            }
            
            // Strategy 3: Try shared database (Mac Catalyst fallback)
            #if targetEnvironment(macCatalyst)
            do {
                let sharedDatabase = cloudKitContainer.sharedCloudDatabase
                if let sharedRefetch = try await sharedDatabase.record(for: savedShare.recordID) as? CKShare {
                    Logger.shared.info("Refetched share from shared DB for trip: \(trip.id), URL: \(sharedRefetch.url?.absoluteString ?? "still none")", category: .cloudKit)
                    if sharedRefetch.url != nil {
                        return sharedRefetch
                    }
                }
            } catch {
                Logger.shared.logError(error, message: "Failed to refetch share from alternate source", category: .cloudKit)
            }
            #endif
            
            // Strategy 4: Check if this is a development environment issue
            #if DEBUG
            Logger.shared.warning("Share URL still nil - this may be normal in development builds or Mac Catalyst", category: .cloudKit)
            // Return the share anyway in debug mode - the share record exists even without URL
            return savedShare
            #else
            // In production, this is a real problem
            Logger.shared.error("Share created but URL remains unavailable after all recovery attempts for trip: \(trip.id)", category: .cloudKit)
            throw CloudKitSharingError.shareURLNotAvailable
            #endif
        }
        
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
        let shareModifications = zoneChanges.modifications.filter { $0.record is CKShare }
        let shareDeletions = zoneChanges.deletions.count
        
        if shareModifications.count > 0 || shareDeletions > 0 {
            Logger.shared.info("CKSyncEngine fetched zone changes - \(shareModifications.count) share modifications, \(shareDeletions) deletions", category: .cloudKit)
        }
        
        // Reset event counter if we haven't processed events in the last 5 minutes
        let now = Date()
        if now.timeIntervalSince(lastEventLogTime) > 300 {
            if eventProcessingCount > 0 {
                Logger.shared.info("Resetting event processing count (was \(eventProcessingCount))", category: .cloudKit)
                eventProcessingCount = 0
            }
            lastEventLogTime = now
        }
        
        // Process share modifications
        for modification in shareModifications {
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
        eventProcessingCount += 1
        
        // Rate limit excessive logging
        let shouldLog = eventProcessingCount <= 10 || eventProcessingCount % eventLoggingThreshold == 0
        
        if shouldLog {
            if eventProcessingCount > 10 {
                Logger.shared.warning("Processing excessive share deletions - count: \(eventProcessingCount), latest: \(recordID)", category: .cloudKit)
            } else {
                Logger.shared.info("Processing share deletion: \(recordID)", category: .cloudKit)
            }
        }
        
        // Find and remove the share from cache
        var foundAndRemoved = false
        for (tripID, share) in activeShares {
            if share.recordID == recordID {
                activeShares.removeValue(forKey: tripID)
                if shouldLog {
                    Logger.shared.info("Removed cached share for trip: \(tripID)", category: .cloudKit)
                }
                foundAndRemoved = true
                break
            }
        }
        
        // Log if we're processing deletions for shares we don't have cached (indicates sync issues)
        if !foundAndRemoved && shouldLog {
            let zoneInfo = recordID.zoneID.zoneName == "com.apple.coredata.cloudkit.zone" ? "default CloudKit zone" : "custom zone"
            Logger.shared.warning("Processed deletion for unknown share in \(zoneInfo): \(recordID)", category: .cloudKit)
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
    case accountStatusUnavailable
    case noICloudAccount
    case accountRestricted
    case accountTemporarilyUnavailable
    case unknownAccountStatus
    case shareURLNotAvailable
    case customZoneRequired
    
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
        case .accountStatusUnavailable:
            return "CloudKit account status could not be determined"
        case .noICloudAccount:
            return "No iCloud account found. Please sign in to iCloud in System Settings"
        case .accountRestricted:
            return "iCloud account is restricted and cannot use CloudKit sharing"
        case .accountTemporarilyUnavailable:
            return "iCloud account is temporarily unavailable. Please try again later"
        case .unknownAccountStatus:
            return "Unknown iCloud account status"
        case .shareURLNotAvailable:
            return "Share link could not be generated. CloudKit sharing may not be fully supported on this device configuration"
        case .customZoneRequired:
            return "CloudKit sharing requires a custom zone. Cannot share records in the default zone"
        }
    }
}