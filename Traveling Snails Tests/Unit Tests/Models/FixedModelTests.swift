//
//  FixedModelTests.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/1/25.
//

import Testing
import Foundation

@testable import Traveling_Snails

@Suite("Fixed Model Tests (No SwiftData)")
struct FixedModelTests {
    
    @Suite("Model Initialization Tests")
    struct ModelInitializationTests {
        
        @Test("Trip initialization with proper defaults")
        func tripInitializationWithProperDefaults() {
            let trip = Trip(name: "Test Trip")
            
            #expect(trip.name == "Test Trip")
            #expect(trip.notes == "")
            #expect(trip.hasStartDate == false)
            #expect(trip.hasEndDate == false)
            #expect(trip.totalActivities == 0)
            #expect(trip.totalCost == 0)
        }
        
        @Test("Organization initialization with proper defaults")
        func organizationInitializationWithProperDefaults() {
            let org = Organization(name: "Test Org")
            
            #expect(org.name == "Test Org")
            #expect(org.phone == "")
            #expect(org.email == "")
            #expect(org.website == "")
            #expect(org.logoURL == "")
            #expect(org.cachedLogoFilename == "")
            #expect(org.isNone == false)
        }
        
        @Test("Address initialization with proper defaults")
        func addressInitializationWithProperDefaults() {
            let address = Address()
            
            #expect(address.street == "")
            #expect(address.city == "")
            #expect(address.state == "")
            #expect(address.country == "")
            #expect(address.postalCode == "")
            #expect(address.formattedAddress == "")
            #expect(address.latitude == 0.0)
            #expect(address.longitude == 0.0)
            #expect(address.isEmpty == true)
        }
        
        @Test("Activity initialization with current timezone defaults")
        func activityInitializationWithCurrentTimezoneDefaults() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            #expect(activity.name == "Test Activity")
            #expect(activity.cost == Decimal(0))
            #expect(activity.paid == .none)
            #expect(activity.reservation == "")
            #expect(activity.notes == "")
            #expect(activity.customLocationName == "")
            #expect(activity.hideLocation == false)
            
            // These default to current timezone, not empty string
            #expect(activity.startTZId == TimeZone.current.identifier)
            #expect(activity.endTZId == TimeZone.current.identifier)
        }
        
        @Test("Lodging initialization with current timezone defaults")
        func lodgingInitializationWithCurrentTimezoneDefaults() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            #expect(lodging.name == "Test Hotel")
            #expect(lodging.cost == Decimal(0))
            #expect(lodging.paid == .none)
            #expect(lodging.reservation == "")
            #expect(lodging.notes == "")
            #expect(lodging.customLocationName == "")
            #expect(lodging.hideLocation == false)
            
            // These default to current timezone, not empty string
            #expect(lodging.checkInTZId == TimeZone.current.identifier)
            #expect(lodging.checkOutTZId == TimeZone.current.identifier)
        }
        
        @Test("Transportation initialization with current timezone defaults")
        func transportationInitializationWithCurrentTimezoneDefaults() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let transport = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            #expect(transport.name == "Test Flight")
            #expect(transport.cost == Decimal(0))
            #expect(transport.paid == .none)
            #expect(transport.confirmation == "")
            #expect(transport.notes == "")
            
            // These default to current timezone, not empty string
            #expect(transport.startTZId == TimeZone.current.identifier)
            #expect(transport.endTZId == TimeZone.current.identifier)
        }
    }
    
    @Suite("Relationship Handling Tests")
    struct RelationshipHandlingTests {
        
        @Test("Trip handles nil relationships gracefully")
        func tripHandlesNilRelationshipsGracefully() {
            let trip = Trip(name: "Nil Test")
            
            // With nil relationships, these should not crash
            #expect(trip.totalActivities == 0)
            #expect(trip.totalCost == 0)
            #expect(trip.lodging.isEmpty)
            #expect(trip.transportation.isEmpty)
            #expect(trip.activity.isEmpty)
        }
        
        @Test("Trip with manually initialized relationships")
        func tripWithManuallyInitializedRelationships() {
            let trip = Trip(name: "Manual Test")
            let org = Organization(name: "Test Org")
            
            // Initialize arrays manually
            trip.lodging = []
            trip.transportation = []
            trip.activity = []
            
            // Add activities
            let lodging = Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: Decimal(200),
                paid: .none,
                trip: trip,
                organization: org
            )
            
            let transport = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                cost: Decimal(500),
                trip: trip,
                organization: org
            )
            
            let activity = Activity(
                name: "Museum",
                start: Date(),
                end: Date(),
                cost: Decimal(50),
                trip: trip,
                organization: org
            )
            
            lodging.trip = trip
            transport.trip = trip
            activity.trip = trip
            
            #expect(trip.lodging.count == 1)
            #expect(trip.transportation.count == 1)
            #expect(trip.activity.count == 1)
            #expect(trip.totalActivities == 3)
            #expect(trip.totalCost == Decimal(750))
        }
        
        @Test("Organization handles nil relationships gracefully")
        func organizationHandlesNilRelationshipsGracefully() {
            let org = Organization(name: "Nil Test")
            
            #expect(org.transportation.isEmpty)
            #expect(org.lodging.isEmpty)
            #expect(org.activity.isEmpty)
            #expect(org.hasTransportation == false)
            #expect(org.hasLodging == false)
            #expect(org.hasActivity == false)
        }
    }
    
    @Suite("Business Logic Tests")
    struct BusinessLogicTests {
        
        @Test("Trip cost calculation precision")
        func tripCostCalculationPrecision() {
            let trip = Trip(name: "Cost Test")
            let org = Organization(name: "Test Org")
            
            trip.lodging = []
            trip.transportation = []
            trip.activity = []
            
            let lodging = Lodging(
                name: "Hotel",
                start: Date(),
                end: Date(),
                cost: Decimal(string: "199.99")!,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            let transport = Transportation(
                name: "Flight",
                start: Date(),
                end: Date(),
                cost: Decimal(string: "549.50")!,
                trip: trip,
                organization: org
            )
            
            let activity = Activity(
                name: "Tour",
                start: Date(),
                end: Date(),
                cost: Decimal(string: "75.25")!,
                trip: trip,
                organization: org
            )
            
            
            lodging.trip = trip
            transport.trip = trip
            activity.trip = trip

            
            let expectedTotal = Decimal(string: "824.74")!
            #expect(trip.totalCost == expectedTotal)
        }
        
        @Test("Activity duration calculation")
        func activityDurationCalculation() {
            let trip = Trip(name: "Duration Test")
            let org = Organization(name: "Test Org")
            
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .hour, value: 3, to: startDate)!
            
            let activity = Activity(
                name: "3 Hour Activity",
                start: startDate,
                end: endDate,
                trip: trip,
                organization: org
            )
            
            #expect(activity.duration() == 3 * 3600) // 3 hours in seconds
        }
        
        @Test("Trip date range validation")
        func tripDateRangeValidation() {
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            
            let trip = Trip(name: "Date Range Test", startDate: startDate, endDate: endDate)
            
            #expect(trip.hasDateRange == true)
            #expect(trip.dateRange != nil)
            
            if let range = trip.dateRange {
                #expect(range.lowerBound == startDate)
                #expect(range.upperBound == endDate)
                
                let midDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)!
                #expect(range.contains(midDate))
            }
        }
        
        @Test("None organization detection")
        func noneOrganizationDetection() {
            let noneOrg = Organization(name: "None")
            let regularOrg = Organization(name: "Regular Org")
            
            #expect(noneOrg.isNone == true)
            #expect(regularOrg.isNone == false)
        }
    }
    
    @Suite("Protocol Conformance Tests")
    struct ProtocolConformanceTests {
        
        @Test("Activity protocol conformance")
        func activityProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                trip: trip,
                organization: org
            )
            
            #expect(activity.confirmationLabel == "Reservation")
            #expect(activity.supportsCustomLocation == true)
            #expect(activity.activityType == .activity)
            #expect(activity.icon == "ticket.fill")
            #expect(activity.color == .purple)
            #expect(activity.startLabel == "Start")
            #expect(activity.endLabel == "End")
            #expect(activity.hasTypeSelector == false)
        }
        
        @Test("Lodging protocol conformance")
        func lodgingProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Hotel")
            
            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                cost: 0,
                paid: .none,
                trip: trip,
                organization: org
            )
            
            #expect(lodging.confirmationLabel == "Reservation")
            #expect(lodging.supportsCustomLocation == true)
            #expect(lodging.activityType == .lodging)
            #expect(lodging.icon == "bed.double.fill")
            #expect(lodging.color == .indigo)
            #expect(lodging.startLabel == "Check-in")
            #expect(lodging.endLabel == "Check-out")
            #expect(lodging.hasTypeSelector == false)
        }
        
        @Test("Transportation protocol conformance")
        func transportationProtocolConformance() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            
            let transport = Transportation(
                name: "Test Flight",
                type: .plane,
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            
            #expect(transport.confirmationLabel == "Confirmation")
            #expect(transport.supportsCustomLocation == false)
            #expect(transport.activityType == .transportation)
            #expect(transport.icon == "airplane")
            #expect(transport.color == .blue)
            #expect(transport.startLabel == "Departure")
            #expect(transport.endLabel == "Arrival")
            #expect(transport.hasTypeSelector == true)
        }
    }
    
    @Suite("Edge Case Handling")
    struct EdgeCaseHandling {
        
        @Test("Empty models handle gracefully - safer version")
        func emptyModelsHandleGracefullySafer() {
            let emptyTrip = Trip(name: "")
            let emptyOrg = Organization(name: "")
            
            // Test the models themselves without creating cross-references
            #expect(emptyTrip.name.isEmpty == true)
            #expect(emptyOrg.name.isEmpty == true)
            #expect(emptyTrip.totalCost == 0)
            
            // Don't test totalActivities when creating activities that reference the trip
            // Instead, test with manually controlled relationships:
            emptyTrip.lodging = []
            emptyTrip.transportation = []
            emptyTrip.activity = []
            
            #expect(emptyTrip.totalActivities == 0)
        }
        
        @Test("Extreme decimal values")
        func extremeDecimalValues() {
            let activity = Activity()
            
            let testValues = [
                Decimal(0),
                Decimal(string: "0.01")!,
                Decimal(string: "999999.99")!,
                Decimal(string: "123.456789")!
            ]
            
            for value in testValues {
                activity.cost = value
                #expect(activity.cost == value)
            }
        }
        
        @Test("Invalid timezone handling")
        func invalidTimezoneHandling() {
            let activity = Activity()
            activity.startTZId = "Invalid/Timezone"
            activity.endTZId = "Another/Invalid"
            
            // Should fallback to current timezone
            #expect(activity.startTZ.identifier == TimeZone.current.identifier)
            #expect(activity.endTZ.identifier == TimeZone.current.identifier)
        }
        
        @Test("Extreme coordinate values")
        func extremeCoordinateValues() {
            let extremeAddress = Address(latitude: 90.0, longitude: 180.0)
            #expect(extremeAddress.latitude == 90.0)
            #expect(extremeAddress.longitude == 180.0)
            #expect(extremeAddress.coordinate != nil)
            
            let nullIslandAddress = Address(latitude: 0.0, longitude: 0.0)
            #expect(nullIslandAddress.coordinate == nil) // 0,0 returns nil in your implementation
        }
        
        @Test("Very long strings")
        func veryLongStrings() {
            let longName = String(repeating: "A", count: 1000)
            let trip = Trip(name: longName)
            #expect(trip.name == longName)
            #expect(trip.name.count == 1000)
        }
        
        @Test("Extreme dates")
        func extremeDates() {
            let veryOldDate = Date(timeIntervalSince1970: 0) // 1970
            let farFutureDate = Date(timeIntervalSince1970: 4102444800) // 2100
            
            let activity = Activity()
            activity.start = veryOldDate
            activity.end = farFutureDate
            
            #expect(activity.start == veryOldDate)
            #expect(activity.end == farFutureDate)
            #expect(activity.duration() > 0)
        }
    }
    
    @Suite("Performance Tests")
    struct PerformanceTests {
        
        @Test("Large dataset creation performance")
        func largeDatasetCreationPerformance() {
            let trip = Trip(name: "Performance Test")
            let org = Organization(name: "Performance Org")
            
            trip.activity = []
            
            let startTime = Date()
            
            // Create 100 activities
            for i in 0..<100 {
                let activity = Activity(
                    name: "Activity \(i)",
                    start: Date(),
                    end: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!,
                    cost: Decimal(i),
                    trip: trip,
                    organization: org
                )
                
                activity.trip = trip
            }
            
            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 5.0, "Creating 100 activities took \(creationTime) seconds - should complete within 5 seconds")
            
            #expect(trip.activity.count == 100)
            #expect(trip.totalActivities == 100)
            #expect(trip.totalCost == Decimal(4950)) // Sum of 0+1+2+...+99
        }
        
        @Test("Cost calculation performance")
        func costCalculationPerformance() {
            let trip = Trip(name: "Cost Performance Test")
            let org = Organization(name: "Test Org")
            
            trip.lodging = []
            trip.transportation = []
            trip.activity = []
            
            // Add many activities
            for i in 0..<50 {
                trip.lodging.append(Lodging(
                    name: "Hotel \(i)",
                    start: Date(),
                    end: Date(),
                    cost: Decimal(100 + i),
                    paid: .none,
                    trip: trip,
                    organization: org
                ))
                
                trip.transportation.append(Transportation(
                    name: "Transport \(i)",
                    start: Date(),
                    end: Date(),
                    cost: Decimal(200 + i),
                    trip: trip,
                    organization: org
                ))
                
                trip.activity.append(Activity(
                    name: "Activity \(i)",
                    start: Date(),
                    end: Date(),
                    cost: Decimal(50 + i),
                    trip: trip,
                    organization: org
                ))
            }
            
            let startTime = Date()
            let totalCost = trip.totalCost
            let calculationTime = Date().timeIntervalSince(startTime)
            
            #expect(calculationTime < 0.1, "Cost calculation took \(calculationTime) seconds")
            #expect(totalCost > 0)
            #expect(trip.totalActivities == 150) // 50 of each type
        }
    }
}
