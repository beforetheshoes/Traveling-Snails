//
//  TripSharingExtensionTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
import CloudKit
@testable import Traveling_Snails

/// Tests for Trip model sharing extensions
/// These tests validate the implemented CloudKit sharing functionality
@Suite("Trip Sharing Extension Tests")
@MainActor
struct TripSharingExtensionTests {
    
    // MARK: - Sharing Metadata Tests
    
    @Test("Trip supports shareID property", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDProperty() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        #expect(trip.shareID == nil)
        
        let shareID = CKRecord.ID(recordName: "TestShare", zoneID: CKRecordZone.ID(zoneName: "TripSharing"))
        trip.shareID = shareID
        #expect(trip.shareID == shareID)
    }
    
    @Test("Trip shareID string storage works correctly", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDStringStorage() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        #expect(trip.shareID == nil)
        
        let shareID = CKRecord.ID(recordName: "ShareRecord", zoneID: CKRecordZone.ID(zoneName: "CustomZone"))
        trip.shareID = shareID
        
        // Verify string storage and retrieval works correctly
        #expect(trip.shareID?.recordName == "ShareRecord")
        #expect(trip.shareID?.zoneID.zoneName == "CustomZone")
        
        // Clear the share ID
        trip.shareID = nil
        #expect(trip.shareID == nil)
    }
    
    @Test("Trip shareID handles zone information correctly", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDZoneHandling() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        let zoneID = CKRecordZone.ID(zoneName: "TripSharing")
        let shareID = CKRecord.ID(recordName: "TestShare", zoneID: zoneID)
        trip.shareID = shareID
        
        #expect(trip.shareID?.recordName == "TestShare")
        #expect(trip.shareID?.zoneID.zoneName == "TripSharing")
        #expect(trip.shareID?.zoneID.ownerName == CKCurrentUserDefaultName)
    }
    
    @Test("Trip shareID persistence through string conversion", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDStringConversion() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        // Test multiple shareID assignments
        for i in 1...5 {
            let shareID = CKRecord.ID(recordName: "Share\(i)", zoneID: CKRecordZone.ID(zoneName: "Zone\(i)"))
            trip.shareID = shareID
            
            #expect(trip.shareID?.recordName == "Share\(i)")
            #expect(trip.shareID?.zoneID.zoneName == "Zone\(i)")
        }
    }
    
    @Test("Trip shareID handles edge cases", .tags(.unit, .fast, .models, .sharing))
    func testTripShareIDEdgeCases() throws {
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date(), isProtected: false)
        
        // Test with special characters in record name
        let specialCharShareID = CKRecord.ID(recordName: "Test-Share_123", zoneID: CKRecordZone.ID(zoneName: "TripSharing"))
        trip.shareID = specialCharShareID
        #expect(trip.shareID?.recordName == "Test-Share_123")
        #expect(trip.shareID?.zoneID.zoneName == "TripSharing")
        
        // Test with numeric zone name
        let numericZoneShareID = CKRecord.ID(recordName: "Share123", zoneID: CKRecordZone.ID(zoneName: "Zone123"))
        trip.shareID = numericZoneShareID
        #expect(trip.shareID?.recordName == "Share123")
        #expect(trip.shareID?.zoneID.zoneName == "Zone123")
    }
}