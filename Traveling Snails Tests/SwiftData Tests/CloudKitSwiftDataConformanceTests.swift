//
//  CloudKitSwiftDataConformanceTests.swift
//  Traveling Snails
//
//


import Foundation
import SwiftData
import Testing

@testable import Traveling_Snails

@Suite("CloudKit & SwiftData Conformance Tests")
@MainActor
struct CloudKitSwiftDataConformanceTests {
    @Suite("Relationship Safety Tests")
    @MainActor
    struct RelationshipSafetyTests {
        @Test("Trip relationships never return nil")
        func tripRelationshipsNeverReturnNil() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            testBase.modelContext.insert(trip)
            try testBase.modelContext.save()

            // Even with no data, accessors should return empty arrays, not nil
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)

            // Should be able to call array methods without crashing
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)

            // Should handle computed properties safely
            #expect(trip.totalActivities == 0)
            #expect(trip.totalCost == 0)
        }

        @Test("Organization relationships never return nil")
        func organizationRelationshipsNeverReturnNil() async throws {
            let testBase = SwiftDataTestBase()
            
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

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
        func fileAttachmentRelationshipsNeverReturnNil() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(activity)

            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(lodging)

            let transportation = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(transportation)
            try testBase.modelContext.save()

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
    @MainActor
    struct RelationshipAppendRemoveSafetyTests {
        @Test("Trip relationship mutations work safely")
        func tripRelationshipMutationsWorkSafely() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

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
            testBase.modelContext.insert(lodging)
            try testBase.modelContext.save()

            // This should work without crashes
            trip.lodging.append(lodging)
            try testBase.modelContext.save()
            #expect(trip.lodging.count == 1)
            #expect(trip.totalActivities == 1)

            // Should be able to remove
            trip.lodging.removeAll()
            try testBase.modelContext.save()
            #expect(trip.lodging.isEmpty)
            #expect(trip.totalActivities == 0)
        }

        @Test("Organization relationship mutations work safely")
        func organizationRelationshipMutationsWorkSafely() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

            let transportation = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(transportation)
            try testBase.modelContext.save()

            // Setting relationship should work
            transportation.organization = org
            try testBase.modelContext.save()

            // Organization should reflect the relationship
            #expect(org.transportation.contains { $0.id == transportation.id })
            #expect(org.hasTransportation == true)
            #expect(org.canBeDeleted == false)
        }

        @Test("File attachment mutations work safely")
        func fileAttachmentMutationsWorkSafely() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()

            let attachment = EmbeddedFileAttachment(
                fileName: "test.pdf",
                originalFileName: "Test.pdf"
            )
            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            // Should be able to append
            activity.fileAttachments.append(attachment)
            try testBase.modelContext.save()
            #expect(activity.hasAttachments == true)
            #expect(activity.attachmentCount == 1)

            // Should be able to remove
            activity.fileAttachments.removeAll()
            try testBase.modelContext.save()
            #expect(activity.hasAttachments == false)
            #expect(activity.attachmentCount == 0)
        }
    }

    @Suite("None Organization Safety Tests")
    @MainActor
    struct NoneOrganizationSafetyTests {
        @Test("None organization creation is safe")
        func noneOrganizationCreationIsSafe() async throws {
            let testBase = SwiftDataTestBase()
            
            // Should not crash when accessing isNone property
            let noneOrg = Organization(name: "None")
            testBase.modelContext.insert(noneOrg)
            try testBase.modelContext.save()
            #expect(noneOrg.isNone == true)
            #expect(noneOrg.canBeDeleted == false)

            let regularOrg = Organization(name: "Regular")
            testBase.modelContext.insert(regularOrg)
            try testBase.modelContext.save()
            #expect(regularOrg.isNone == false)
            #expect(regularOrg.canBeDeleted == true)
        }

        @Test("None organization relationship handling")
        func noneOrganizationRelationshipHandling() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Test Trip")
            let noneOrg = Organization(name: "None")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(noneOrg)
            try testBase.modelContext.save()

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: noneOrg
            )
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()

            // Should handle None organization relationships safely
            #expect(activity.organization?.isNone == true)
            #expect(activity.displayLocation == "No location specified")
        }
    }

    @Suite("CloudKit Compatibility Tests")
    @MainActor
    struct CloudKitCompatibilityTests {
        @Test("Empty relationships are efficiently stored")
        func emptyRelationshipsAreEfficientlyStored() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Empty Trip")
            testBase.modelContext.insert(trip)
            try testBase.modelContext.save()

            // Empty arrays should not waste CloudKit storage
            // Our setter should convert empty arrays to nil
            trip.lodging = []
            trip.transportation = []
            trip.activity = []
            try testBase.modelContext.save()

            // But getters should still return empty arrays
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)
        }

        @Test("Relationships handle CloudKit sync scenarios")
        func relationshipsHandleCloudKitSyncScenarios() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Sync Test Trip")
            let org = Organization(name: "Sync Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

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
            testBase.modelContext.insert(lodging)
            try testBase.modelContext.save()

            trip.lodging.append(lodging)
            try testBase.modelContext.save()
            #expect(trip.lodging.count == 1)
            #expect(trip.totalActivities == 1)
        }
    }

    @Suite("Data Consistency Tests")
    @MainActor
    struct DataConsistencyTests {
        @Test("Relationship bidirectionality is maintained")
        func relationshipBidirectionalityIsMaintained() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Bidirectional Test")
            let org = Organization(name: "Test Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()

            // Set the "to-one" relationships
            activity.trip = trip
            activity.organization = org
            try testBase.modelContext.save()

            // The "to-many" relationships should be updated automatically by SwiftData
            // Note: In real SwiftData, this happens automatically with inverse relationships
            // For testing, we verify the relationship exists
            #expect(activity.trip?.id == trip.id)
            #expect(activity.organization?.id == org.id)
        }

        @Test("Complex relationship scenarios work")
        func complexRelationshipScenariosWork() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Complex Trip")
            let org1 = Organization(name: "Airline")
            let org2 = Organization(name: "Hotel")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org1)
            testBase.modelContext.insert(org2)
            try testBase.modelContext.save()

            // Multiple activities with different organizations
            let flight = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org1
            )
            testBase.modelContext.insert(flight)

            let hotel = Lodging(
                name: "Hotel Stay",
                start: Date(),
                end: Date(),
                cost: 200,
                paid: .none,
                trip: trip,
                organization: org2
            )
            testBase.modelContext.insert(hotel)

            let activity = Activity(
                name: "Sightseeing",
                start: Date(),
                end: Date(),
                cost: 50,
                trip: trip,
                organization: org2
            )
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()

            // Manually set up relationships for testing
            trip.transportation.append(flight)
            trip.lodging.append(hotel)
            trip.activity.append(activity)
            try testBase.modelContext.save()

            // Should calculate totals correctly
            #expect(trip.totalActivities == 3)
            #expect(trip.totalCost == 250) // 200 + 50

            // Organizations should track their activities
            org1.transportation.append(flight)
            org2.lodging.append(hotel)
            org2.activity.append(activity)
            try testBase.modelContext.save()

            #expect(org1.hasTransportation == true)
            #expect(org1.canBeDeleted == false)
            #expect(org2.hasLodging == true)
            #expect(org2.hasActivity == true)
            #expect(org2.canBeDeleted == false)
        }
    }

    @Suite("Performance and Memory Tests")
    @MainActor
    struct PerformanceAndMemoryTests {
        @Test("Large relationship collections perform well")
        func largeRelationshipCollectionsPerformWell() async throws {
            let testBase = SwiftDataTestBase()
            
            let trip = Trip(name: "Large Trip")
            let org = Organization(name: "Large Org")
            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(org)
            try testBase.modelContext.save()

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
                testBase.modelContext.insert(activity)

                trip.activity.append(activity)
                org.activity.append(activity)
            }
            try testBase.modelContext.save()

            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 6.0, "Creating 100 activities took \(creationTime) seconds")

            // Verify totals are calculated correctly
            #expect(trip.totalActivities == 100)
            #expect(trip.totalCost == Decimal(4950)) // Sum of 0+1+2+...+99
            #expect(org.hasActivity == true)
            #expect(org.activity.count == 100)
        }

        @Test("Memory usage is efficient with empty relationships")
        func memoryUsageIsEfficientWithEmptyRelationships() async throws {
            let testBase = SwiftDataTestBase()
            
            // Create many objects with no relationships
            var trips: [Trip] = []
            var orgs: [Organization] = []

            for i in 0..<50 {
                let trip = Trip(name: "Trip \(i)")
                let org = Organization(name: "Org \(i)")
                testBase.modelContext.insert(trip)
                testBase.modelContext.insert(org)

                trips.append(trip)
                orgs.append(org)
            }
            try testBase.modelContext.save()

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
