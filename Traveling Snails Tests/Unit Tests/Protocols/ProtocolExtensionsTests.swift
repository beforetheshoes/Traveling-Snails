import Foundation
import SwiftUI
import Testing

@testable import Traveling_Snails

@Suite("Protocol and Extension Tests")
struct ProtocolExtensionTests {
    @Suite("TripActivityProtocol Tests")
    struct TripActivityProtocolTests {
        @Test("Activity protocol conformance")
        func activityProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate)!

            let activity = Activity(
                name: "Test Activity",
                start: startDate,
                end: endDate,
                trip: trip,
                organization: org
            )

            // Test protocol properties
            #expect(activity.confirmationLabel == "Reservation")
            #expect(activity.supportsCustomLocation == true)
            #expect(activity.activityType == .activity)
            #expect(activity.icon == "ticket.fill")
            #expect(activity.color == .purple)
            #expect(activity.scheduleTitle == "Schedule")
            #expect(activity.startLabel == "Start")
            #expect(activity.endLabel == "End")
            #expect(activity.hasTypeSelector == false)
        }

        @Test("Lodging protocol conformance")
        func lodgingProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Hotel")
            let checkIn = Date()
            let checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn)!

            let lodging = Lodging(
                name: "Test Hotel",
                start: checkIn,
                end: checkOut,
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            // Test protocol properties
            #expect(lodging.confirmationLabel == "Reservation")
            #expect(lodging.supportsCustomLocation == true)
            #expect(lodging.activityType == .lodging)
            #expect(lodging.icon == "bed.double.fill")
            #expect(lodging.color == .indigo)
            #expect(lodging.scheduleTitle == "Stay Details")
            #expect(lodging.startLabel == "Check-in")
            #expect(lodging.endLabel == "Check-out")
            #expect(lodging.hasTypeSelector == false)
        }

        @Test("Transportation protocol conformance")
        func transportationProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            let departure = Date()
            let arrival = Calendar.current.date(byAdding: .hour, value: 3, to: departure)!

            let transportation = Transportation(
                name: "Test Flight",
                type: .plane,
                start: departure,
                end: arrival,
                trip: trip,
                organization: org
            )

            // Test protocol properties
            #expect(transportation.confirmationLabel == "Confirmation")
            #expect(transportation.supportsCustomLocation == false)
            #expect(transportation.activityType == .transportation)
            #expect(transportation.icon == "airplane") // Should match plane type
            #expect(transportation.color == .blue)
            #expect(transportation.scheduleTitle == "Schedule")
            #expect(transportation.startLabel == "Departure")
            #expect(transportation.endLabel == "Arrival")
            #expect(transportation.hasTypeSelector == true)
        }

        @Test("Activity location handling")
        func activityLocationHandling() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Venue")
            let noneOrg = Organization(name: "None")

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            // Test with organization - check if org actually has an address
            #expect(activity.displayLocation == "Test Venue")
            // hasLocation will be true if organization has a non-empty address
            let hasOrgAddress = !(org.address?.isEmpty ?? true)
            #expect(activity.hasLocation == hasOrgAddress)

            // Test with None organization and custom location
            activity.organization = noneOrg
            activity.customLocationName = "Custom Venue"
            #expect(activity.displayLocation == "Custom Venue")

            // Test with custom address
            let customAddress = Address(street: "123 Main St", city: "Test City")
            activity.customAddresss = customAddress
            activity.customLocationName = ""
            #expect(activity.displayLocation == "123 Main St, Test City")
            #expect(activity.hasLocation == true)
        }

        @Test("Transportation location handling")
        func transportationLocationHandling() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            let noneOrg = Organization(name: "None")

            let transportation = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            // Test with organization
            #expect(transportation.displayLocation == "Test Airline")
            // Check if organization actually has an address - organizations start with empty addresses
            let hasAddress = !(org.address?.isEmpty ?? true)
            #expect(transportation.hasLocation == hasAddress)

            // Test with None organization
            transportation.organization = noneOrg
            #expect(transportation.displayLocation == "No organization specified")
            #expect(transportation.hasLocation == false)
        }
    }

    @Suite("ActivityWrapper Tests")
    struct ActivityWrapperTests {
        @Test("ActivityWrapper type detection")
        func activityWrapperTypeDetection() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")

            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
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

            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            let lodgingWrapper = ActivityWrapper(lodging)
            let transportationWrapper = ActivityWrapper(transportation)
            let activityWrapper = ActivityWrapper(activity)

            #expect(lodgingWrapper.type == .lodging)
            #expect(transportationWrapper.type == .transportation)
            #expect(activityWrapper.type == .activity)
        }

        @Test("ActivityWrapper type properties")
        func activityWrapperTypeProperties() {
            #expect(ActivityWrapper.ActivityType.lodging.icon == "bed.double.fill")
            #expect(ActivityWrapper.ActivityType.transportation.icon == "car.fill")
            #expect(ActivityWrapper.ActivityType.activity.icon == "ticket.fill")

            #expect(ActivityWrapper.ActivityType.lodging.color == .indigo)
            #expect(ActivityWrapper.ActivityType.transportation.color == .blue)
            #expect(ActivityWrapper.ActivityType.activity.color == .purple)
        }
    }

    @Suite("TripActivityEditData Tests")
    struct TripActivityEditDataTests {
        @Test("TripActivityEditData initialization from Activity")
        func editDataFromActivity() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate)!

            let activity = Activity(
                name: "Test Activity",
                start: startDate,
                end: endDate,
                cost: Decimal(50.00),
                paid: .deposit,
                reservation: "RES123",
                notes: "Test notes",
                trip: trip,
                organization: org,
                customLocationName: "Custom Location"
            )

            let editData = TripActivityEditData(from: activity)

            #expect(editData.name == "Test Activity")
            #expect(editData.start == startDate)
            #expect(editData.end == endDate)
            #expect(editData.cost == Decimal(50.00))
            #expect(editData.paid == .deposit)
            #expect(editData.confirmationField == "RES123")
            #expect(editData.notes == "Test notes")
            #expect(editData.customLocationName == "Custom Location")
            #expect(editData.organization?.name == "Test Org")
        }

        @Test("TripActivityEditData initialization from Transportation")
        func editDataFromTransportation() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            let departure = Date()
            let arrival = Calendar.current.date(byAdding: .hour, value: 3, to: departure)!

            let transportation = Transportation(
                name: "Test Flight",
                type: .plane,
                start: departure,
                end: arrival,
                cost: Decimal(500.00),
                paid: .infull,
                confirmation: "ABC123",
                notes: "Window seat",
                trip: trip,
                organization: org
            )

            let editData = TripActivityEditData(from: transportation)

            #expect(editData.name == "Test Flight")
            #expect(editData.transportationType == .plane)
            #expect(editData.cost == Decimal(500.00))
            #expect(editData.paid == .infull)
            #expect(editData.confirmationField == "ABC123")
            #expect(editData.notes == "Window seat")
        }
    }

    @Suite("DestinationType Tests")
    struct DestinationTypeTests {
        @Test("DestinationType equality")
        func destinationTypeEquality() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")

            let lodging1 = Lodging(
                name: "Hotel 1",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            let lodging2 = Lodging(
                name: "Hotel 2",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            let activity1 = Activity(
                name: "Activity 1",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            let dest1 = DestinationType.lodging(lodging1)
            let dest2 = DestinationType.lodging(lodging1) // Same lodging
            let dest3 = DestinationType.lodging(lodging2) // Different lodging
            let dest4 = DestinationType.activity(activity1) // Different type

            #expect(dest1 == dest2)
            #expect(dest1 != dest3)
            #expect(dest1 != dest4)
        }

        @Test("DestinationType hashing")
        func destinationTypeHashing() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")

            let lodging = Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            let dest1 = DestinationType.lodging(lodging)
            let dest2 = DestinationType.lodging(lodging)

            // Same destination should have same hash
            #expect(dest1.hashValue == dest2.hashValue)

            // Different types should be hashable
            let set: Set<DestinationType> = [dest1, dest2]
            #expect(set.count == 1) // Should be deduplicated
        }
    }
}
