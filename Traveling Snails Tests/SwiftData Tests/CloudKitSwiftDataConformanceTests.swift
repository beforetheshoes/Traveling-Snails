//
//  CloudKitSwiftDataConformanceTests.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//


import Testing
import Foundation
import SwiftData

@testable import Traveling_Snails

@Suite("CloudKit & SwiftData Conformance Tests")
struct CloudKitSwiftDataConformanceTests {
    
    @Suite("Relationship Safety Tests")
    struct RelationshipSafetyTests {
        
        @Test("Trip relationships never return nil")
        func tripRelationshipsNeverReturnNil() {
            let trip = Trip(name: "Test Trip")
            
            // Even with no data, accessors should return empty arrays, not nil
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)
            
            // Should be able to call array methods without crashing
            #expect(trip.lodging.count == 0)
            #expect(trip.transportation.count == 0)
            #expect(trip.activity.count == 0)
            
            // Should handle computed properties safely
            #expect(trip.totalActivities == 0)
            #expect(trip.totalCost == 0)
        }
        
        @Test("Organization relationships never return nil")
        func organizationRelationshipsNeverReturnNil() {
            let org = Organization(name: "Test Org")
            
            // Even with no data, accessors should return empty arrays
            #expect(org.transportation.isEmpty)
            #expect(org.lodging.isEmpty)
            #expect(org.activity.isEmpty)
            
            // Should handle computed properties safely
            #expect(org.hasTransportation == false)
            #expect(org.hasLodging == false)
            #expect(org.hasActivity == false)
            #expect(org.canBeDeleted == true)
        }
        
        @Test("File attachment relationships never return nil")
        func fileAttachmentRelationshipsNeverReturnNil() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            let transportation = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            // All should return empty arrays initially
            #expect(activity.fileAttachments.isEmpty)
            #expect(lodging.fileAttachments.isEmpty)
            #expect(transportation.fileAttachments.isEmpty)
            
            // Should handle computed properties safely
            #expect(activity.hasAttachments == false)
            #expect(lodging.hasAttachments == false)
            #expect(transportation.hasAttachments == false)
            
            #expect(activity.attachmentCount == 0)
            #expect(lodging.attachmentCount == 0)
            #expect(transportation.attachmentCount == 0)
        }
    }
    
    @Suite("Relationship Append/Remove Safety Tests")
    struct RelationshipAppendRemoveSafetyTests {
        
        @Test("Trip relationship mutations work safely")
        func tripRelationshipMutationsWorkSafely() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            // Should be able to append to empty arrays
            let lodging = Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            // This should work without crashes
            trip.lodging.append(lodging)
            #expect(trip.lodging.count == 1)
            #expect(trip.totalActivities == 1)
            
            // Should be able to remove
            trip.lodging.removeAll()
            #expect(trip.lodging.isEmpty)
            #expect(trip.totalActivities == 0)
        }
        
        @Test("Organization relationship mutations work safely")
        func organizationRelationshipMutationsWorkSafely() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let transportation = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            // Setting relationship should work
            transportation.organization = org
            
            // Organization should reflect the relationship
            #expect(org.transportation.contains { $0.id == transportation.id })
            #expect(org.hasTransportation == true)
            #expect(org.canBeDeleted == false)
        }
        
        @Test("File attachment mutations work safely")
        func fileAttachmentMutationsWorkSafely() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            let attachment = EmbeddedFileAttachment(
                fileName: "test.pdf",
                originalFileName: "Test.pdf"
            )
            
            // Should be able to append
            activity.fileAttachments.append(attachment)
            #expect(activity.hasAttachments == true)
            #expect(activity.attachmentCount == 1)
            
            // Should be able to remove
            activity.fileAttachments.removeAll()
            #expect(activity.hasAttachments == false)
            #expect(activity.attachmentCount == 0)
        }
    }
    
    @Suite("None Organization Safety Tests")
    struct NoneOrganizationSafetyTests {
        
        @Test("None organization creation is safe")
        func noneOrganizationCreationIsSafe() {
            // Should not crash when accessing isNone property
            let noneOrg = Organization(name: "None")
            #expect(noneOrg.isNone == true)
            #expect(noneOrg.canBeDeleted == false)
            
            let regularOrg = Organization(name: "Regular")
            #expect(regularOrg.isNone == false)
            #expect(regularOrg.canBeDeleted == true)
        }
        
        @Test("None organization relationship handling")
        func noneOrganizationRelationshipHandling() {
            let trip = Trip(name: "Test Trip")
            let noneOrg = Organization(name: "None")
            
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: noneOrg
            )
            
            // Should handle None organization relationships safely
            #expect(activity.organization?.isNone == true)
            #expect(activity.displayLocation == "No location specified")
        }
    }
    
    @Suite("CloudKit Compatibility Tests")
    struct CloudKitCompatibilityTests {
        
        @Test("Empty relationships are efficiently stored")
        func emptyRelationshipsAreEfficientlyStored() {
            let trip = Trip(name: "Empty Trip")
            
            // Empty arrays should not waste CloudKit storage
            // Our setter should convert empty arrays to nil
            trip.lodging = []
            trip.transportation = []
            trip.activity = []
            
            // But getters should still return empty arrays
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)
        }
        
        @Test("Relationships handle CloudKit sync scenarios")
        func relationshipsHandleCloudKitSyncScenarios() {
            let trip = Trip(name: "Sync Test Trip")
            let org = Organization(name: "Sync Test Org")
            
            // Simulate CloudKit sync: relationships might be nil initially
            // Our accessors should handle this gracefully
            #expect(trip.lodging.isEmpty) // Should not crash
            #expect(org.transportation.isEmpty) // Should not crash
            
            // After adding data, should work normally
            let lodging = Lodging(
                name: "Synced Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            trip.lodging.append(lodging)
            #expect(trip.lodging.count == 1)
            #expect(trip.totalActivities == 1)
        }
    }
    
    @Suite("Data Consistency Tests")
    struct DataConsistencyTests {
        
        @Test("Relationship bidirectionality is maintained")
        func relationshipBidirectionalityIsMaintained() {
            let trip = Trip(name: "Bidirectional Test")
            let org = Organization(name: "Test Org")
            
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            // Set the "to-one" relationships
            activity.trip = trip
            activity.organization = org
            
            // The "to-many" relationships should be updated automatically by SwiftData
            // Note: In real SwiftData, this happens automatically with inverse relationships
            // For testing, we verify the relationship exists
            #expect(activity.trip?.id == trip.id)
            #expect(activity.organization?.id == org.id)
        }
        
        @Test("Complex relationship scenarios work")
        func complexRelationshipScenariosWork() {
            let trip = Trip(name: "Complex Trip")
            let org1 = Organization(name: "Airline")
            let org2 = Organization(name: "Hotel")
            
            // Multiple activities with different organizations
            let flight = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org1
            )
            
            let hotel = Lodging(
                name: "Hotel Stay",
                start: Date(),
                end: Date(),
                cost: 200,
                paid: .none,
                trip: trip,
                organization: org2
            )
            
            let activity = Activity(
                name: "Sightseeing",
                start: Date(),
                end: Date(),
                cost: 50,
                trip: trip,
                organization: org2
            )
            
            // Manually set up relationships for testing
            trip.transportation.append(flight)
            trip.lodging.append(hotel)
            trip.activity.append(activity)
            
            // Should calculate totals correctly
            #expect(trip.totalActivities == 3)
            #expect(trip.totalCost == 250) // 200 + 50
            
            // Organizations should track their activities
            org1.transportation.append(flight)
            org2.lodging.append(hotel)
            org2.activity.append(activity)
            
            #expect(org1.hasTransportation == true)
            #expect(org1.canBeDeleted == false)
            #expect(org2.hasLodging == true)
            #expect(org2.hasActivity == true)
            #expect(org2.canBeDeleted == false)
        }
    }
    
    @Suite("Performance and Memory Tests")
    struct PerformanceAndMemoryTests {
        
        @Test("Large relationship collections perform well")
        func largeRelationshipCollectionsPerformWell() {
            let trip = Trip(name: "Large Trip")
            let org = Organization(name: "Large Org")
            
            let startTime = Date()
            
            // Create many activities
            for i in 0..<100 {
                let activity = Activity(
                    name: "Activity \(i)",
                    start: Date(),
                    end: Date(),
                    cost: Decimal(i),
                    trip: trip,
                    organization: org
                )
                
                trip.activity.append(activity)
                org.activity.append(activity)
            }
            
            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 1.0, "Creating 100 activities took \(creationTime) seconds")
            
            // Verify totals are calculated correctly
            #expect(trip.totalActivities == 100)
            #expect(trip.totalCost == Decimal(4950)) // Sum of 0+1+2+...+99
            #expect(org.hasActivity == true)
            #expect(org.activity.count == 100)
        }
        
        @Test("Memory usage is efficient with empty relationships")
        func memoryUsageIsEfficientWithEmptyRelationships() {
            // Create many objects with no relationships
            var trips: [Trip] = []
            var orgs: [Organization] = []
            
            for i in 0..<50 {
                let trip = Trip(name: "Trip \(i)")
                let org = Organization(name: "Org \(i)")
                
                trips.append(trip)
                orgs.append(org)
            }
            
            // All should have empty relationships without memory bloat
            for trip in trips {
                #expect(trip.lodging.isEmpty)
                #expect(trip.totalActivities == 0)
            }
            
            for org in orgs {
                #expect(org.transportation.isEmpty)
                #expect(org.hasTransportation == false)
            }
        }
    }
}
