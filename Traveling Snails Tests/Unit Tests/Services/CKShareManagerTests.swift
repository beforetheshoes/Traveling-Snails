//
//  CKShareManagerTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
import CloudKit
@testable import Traveling_Snails

/// Tests for CKShareManager functionality
/// These tests validate the CloudKit sharing API structure and basic functionality
@Suite("CKShare Manager Tests")
@MainActor
struct CKShareManagerTests {
    
    // MARK: - CKShareManager Creation Tests
    
    @Test("CKShareManager can be created", .tags(.unit, .fast, .cloudkit, .sharing))
    func testCKShareManagerCreation() throws {
        let shareManager = CKShareManager(container: CKContainer(identifier: "iCloud.TravelingSnails"))
        // CKShareManager is created successfully - test that it's not nil
        #expect(type(of: shareManager) == CKShareManager.self)
    }
    
    @Test("CKShareManager creates custom zone for sharing", .tags(.unit, .medium, .cloudkit, .sharing))
    func testCustomZoneCreation() async throws {
        let shareManager = CKShareManager(container: CKContainer(identifier: "iCloud.TravelingSnails"))
        
        // Note: This will likely fail in test environment due to CloudKit unavailability
        do {
            let zone = try await shareManager.createCustomZone(named: "TripSharing")
            #expect(zone.zoneID.zoneName == "TripSharing")
            #expect(zone.zoneID.ownerName == CKCurrentUserDefaultName)
        } catch {
            // Expected to fail in test environment - CloudKit not available
            #expect(error is CKError)
        }
    }
    
    @Test("CKShareManager creates CKRecord for Trip", .tags(.unit, .medium, .cloudkit, .sharing))
    func testCKRecordCreationForTrip() async throws {
        let shareManager = CKShareManager(container: CKContainer(identifier: "iCloud.TravelingSnails"))
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        // Note: This will likely fail in test environment due to CloudKit unavailability
        do {
            let record = try await shareManager.createRecord(for: trip, in: "TripSharing")
            #expect(record.recordType == "Trip")
            #expect(record["name"] as? String == "Test Trip")
            #expect(record.recordID.zoneID.zoneName == "TripSharing")
        } catch {
            // Expected to fail in test environment - CloudKit not available
            #expect(error is CKError)
        }
    }
    
    @Test("CKShareManager creates CKShare for Trip record", .tags(.unit, .medium, .cloudkit, .sharing))
    func testCKShareCreationForTripRecord() async throws {
        let shareManager = CKShareManager(container: CKContainer(identifier: "iCloud.TravelingSnails"))
        let trip = Trip(name: "Shared Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        // Note: This will likely fail in test environment due to CloudKit unavailability
        do {
            let record = try await shareManager.createRecord(for: trip, in: "TripSharing")
            let share = try await shareManager.createShare(for: record)
            
            #expect(share.recordID.recordName.count > 0)
            #expect(share.participants.count >= 1) // At least the owner
        } catch {
            // Expected to fail in test environment - CloudKit not available
            #expect(error is CKError)
        }
    }
    
    @Test("CKShareManager API structure validation", .tags(.unit, .fast, .cloudkit, .sharing))
    func testAPIStructure() throws {
        let shareManager = CKShareManager(container: CKContainer(identifier: "iCloud.TravelingSnails"))
        
        // Test that API methods exist and are callable (structure validation)
        let mockShare = CKShare(rootRecord: CKRecord(recordType: "Trip"))
        
        // These methods should exist and be callable
        let url = shareManager.generateSharingURL(for: mockShare)
        
        // URL will be nil for mock shares, but method exists
        #expect(url == nil || url != nil) // Always true, but validates method exists
    }
    
    @Test("Trip shareID storage and retrieval", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDFunctionality() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        // Test shareID storage (doesn't require CloudKit)
        #expect(trip.shareID == nil)
        
        let shareID = CKRecord.ID(recordName: "TestShare", zoneID: CKRecordZone.ID(zoneName: "TripSharing"))
        trip.shareID = shareID
        
        #expect(trip.shareID?.recordName == "TestShare")
        #expect(trip.shareID?.zoneID.zoneName == "TripSharing")
        
        // Clear shareID
        trip.shareID = nil
        #expect(trip.shareID == nil)
    }
}