//
//  C.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/1/25.
//

import Foundation
import SwiftData
import Testing


@testable import Traveling_Snails

@Suite("Core Model Tests")
struct CoreModelTests {
    
    @Suite("Trip Model Tests")
    struct TripTests {
        
        @Test("Trip initialization with basic properties")
        func tripBasicInitialization() {
            let trip = Trip(name: "Test Trip", notes: "Test notes")
            
            #expect(trip.name == "Test Trip")
            #expect(trip.notes == "Test notes")
            #expect(trip.hasStartDate == false)
            #expect(trip.hasEndDate == false)
            #expect(trip.totalActivities == 0)
            #expect(trip.totalCost == 0)
        }
        
        @Test("Trip initialization with dates")
        func tripInitializationWithDates() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            
            let trip = Trip(name: "Trip with Dates", startDate: startDate, endDate: endDate)
            
            #expect(trip.hasStartDate == true)
            #expect(trip.hasEndDate == true)
            #expect(trip.startDate == startDate)
            #expect(trip.endDate == endDate)
            #expect(trip.hasDateRange == true)
        }
        
        @Test("Trip date management")
        func tripDateManagement() {
            let trip = Trip(name: "Date Test Trip")
            let testDate = Date()
            
            // Initially no dates
            #expect(trip.hasStartDate == false)
            #expect(trip.hasEndDate == false)
            #expect(trip.effectiveStartDate == nil)
            #expect(trip.effectiveEndDate == nil)
            
            // Set start date
            trip.setStartDate(testDate)
            #expect(trip.hasStartDate == true)
            #expect(trip.startDate == testDate)
            #expect(trip.effectiveStartDate == testDate)
            
            // Clear start date
            trip.clearStartDate()
            #expect(trip.hasStartDate == false)
            #expect(trip.effectiveStartDate == nil)
        }
        
        @Test("Trip date range validation")
        func tripDateRangeValidation() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            
            let trip = Trip(name: "Range Test", startDate: startDate, endDate: endDate)
            
            guard let dateRange = trip.dateRange else {
                Issue.record("Date range should exist")
                return
            }
            
            #expect(dateRange.lowerBound == startDate)
            #expect(dateRange.upperBound == endDate)
            #expect(dateRange.contains(Calendar.current.date(byAdding: .day, value: 3, to: startDate)!))
            #expect(!dateRange.contains(Calendar.current.date(byAdding: .day, value: 10, to: startDate)!))
        }
    }
    
    @Suite("Organization Model Tests")
    struct OrganizationTests {
        
        @Test("Organization basic initialization")
        func organizationBasicInit() {
            let org = Organization(name: "Test Airline")
            
            #expect(org.name == "Test Airline")
            #expect(org.phone == "")
            #expect(org.email == "")
            #expect(org.website == "")
            #expect(org.logoURL == "")
            #expect(org.isNone == false)
        }
        
        @Test("Organization with full details")
        func organizationFullDetails() {
            let address = Address(
                street: "123 Main St",
                city: "Test City",
                state: "TS",
                country: "Test Country"
            )
            
            let org = Organization(
                name: "Full Details Airline",
                phone: "+1-555-0123",
                email: "info@airline.com",
                website: "https://airline.com",
                logoURL: "https://airline.com/logo.png",
                address: address
            )
            
            #expect(org.hasPhone == true)
            #expect(org.hasEmail == true)
            #expect(org.hasWebsite == true)
            #expect(org.hasLogoURL == true)
            #expect(org.hasAddress == true)
        }
        
        @Test("Organization none sentinel")
        func organizationNoneSentinel() {
            let noneOrg = Organization(name: "None")
            #expect(noneOrg.isNone == true)
            
            let regularOrg = Organization(name: "Regular Airline")
            #expect(regularOrg.isNone == false)
        }
    }
    
    @Suite("Address Model Tests")
    struct AddressTests {
        
        @Test("Address basic initialization")
        func addressBasicInit() {
            let address = Address()
            
            #expect(address.street == "")
            #expect(address.city == "")
            #expect(address.state == "")
            #expect(address.country == "")
            #expect(address.isEmpty == true)
            #expect(address.coordinate == nil)
        }
        
        @Test("Address with full details")
        func addressFullDetails() {
            let address = Address(
                street: "123 Main St",
                city: "San Francisco",
                state: "CA",
                country: "USA",
                postalCode: "94102",
                latitude: 37.7749,
                longitude: -122.4194,
                formattedAddress: "123 Main St, San Francisco, CA 94102, USA"
            )
            
            #expect(address.isEmpty == false)
            #expect(address.coordinate != nil)
            #expect(address.coordinate?.latitude == 37.7749)
            #expect(address.coordinate?.longitude == -122.4194)
            #expect(address.displayAddress == "123 Main St, San Francisco, CA 94102, USA")
        }
        
        @Test("Address display logic")
        func addressDisplayLogic() {
            // Test formatted address priority
            let addressWithFormatted = Address(
                street: "123 Main St",
                city: "SF",
                formattedAddress: "Formatted Address"
            )
            #expect(addressWithFormatted.displayAddress == "Formatted Address")
            
            // Test component fallback
            let addressWithoutFormatted = Address(
                street: "456 Oak St",
                city: "Oakland",
                state: "CA"
            )
            #expect(addressWithoutFormatted.displayAddress == "456 Oak St, Oakland, CA")
        }
    }
    
    @Suite("Activity Models Tests")
    struct ActivityModelTests {
        
        @Test("Activity initialization and protocol conformance")
        func activityInitialization() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Venue")
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate)!
            
            let activity = Activity(
                name: "Museum Visit",
                start: startDate,
                end: endDate,
                cost: Decimal(25.50),
                paid: .infull,
                reservation: "ABC123",
                notes: "Remember to bring ID",
                trip: trip,
                organization: org
            )
            
            #expect(activity.name == "Museum Visit")
            #expect(activity.cost == Decimal(25.50))
            #expect(activity.paid == .infull)
            #expect(activity.reservation == "ABC123")
            #expect(activity.notes == "Remember to bring ID")
            #expect(activity.duration() == 2 * 3600) // 2 hours in seconds
        }
        
        @Test("Lodging initialization and properties")
        func lodgingInitialization() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Hotel")
            let checkIn = Date()
            let checkOut = Calendar.current.date(byAdding: .day, value: 2, to: checkIn)!
            
            let lodging = Lodging(
                name: "Grand Hotel",
                start: checkIn,
                end: checkOut,
                cost: Decimal(200.00),
                paid: .deposit,
                reservation: "HTL456",
                trip: trip,
                organization: org
            )
            
            #expect(lodging.name == "Grand Hotel")
            #expect(lodging.cost == Decimal(200.00))
            #expect(lodging.paid == .deposit)
            #expect(lodging.reservation == "HTL456")
            
            // Test computed properties
            #expect(lodging.startTZId == TimeZone.current.identifier)
            #expect(lodging.endTZId == TimeZone.current.identifier)
        }
        
        @Test("Transportation initialization and type handling")
        func transportationInitialization() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            let departure = Date()
            let arrival = Calendar.current.date(byAdding: .hour, value: 3, to: departure)!
            
            let transportation = Transportation(
                name: "Flight to Paris",
                type: .plane,
                start: departure,
                end: arrival,
                cost: Decimal(500.00),
                paid: .infull,
                confirmation: "ABC123XYZ",
                trip: trip,
                organization: org
            )
            
            #expect(transportation.name == "Flight to Paris")
            #expect(transportation.type == .plane)
            #expect(transportation.cost == Decimal(500.00))
            #expect(transportation.confirmation == "ABC123XYZ")
        }
    }
    
    @Suite("Paid Status Tests")
    struct PaidStatusTests {
        
        @Test("Paid status display names")
        func paidStatusDisplayNames() {
            #expect(PaidStatus.none.displayName == "None")
            #expect(PaidStatus.deposit.displayName == "Deposit")
            #expect(PaidStatus.infull.displayName == "In Full")
        }
        
        @Test("Paid status all cases")
        func paidStatusAllCases() {
            let allCases = PaidStatus.allCases
            #expect(allCases.count == 3)
            #expect(allCases.contains(.none))
            #expect(allCases.contains(.deposit))
            #expect(allCases.contains(.infull))
        }
    }
    
    @Suite("Transportation Type Tests")
    struct TransportationTypeTests {
        
        @Test("Transportation type system images")
        func transportationTypeSystemImages() {
            #expect(TransportationType.plane.systemImage == "airplane")
            #expect(TransportationType.train.systemImage == "train.side.front.car")
            #expect(TransportationType.car.systemImage == "car")
            #expect(TransportationType.boat.systemImage == "ferry")
            #expect(TransportationType.bicycle.systemImage == "bicycle")
            #expect(TransportationType.walking.systemImage == "figure.walk")
        }
        
        @Test("Transportation type display names")
        func transportationTypeDisplayNames() {
            #expect(TransportationType.plane.displayName == "Plane")
            #expect(TransportationType.train.displayName == "Train")
            #expect(TransportationType.car.displayName == "Car")
            #expect(TransportationType.boat.displayName == "Boat")
            #expect(TransportationType.bicycle.displayName == "Bicycle")
            #expect(TransportationType.walking.displayName == "Walking")
        }
    }
}
