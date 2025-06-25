import Testing
import SwiftData
import Foundation
@testable import Traveling_Snails

@Suite("Transportation Icon Tests")
@MainActor
final class TransportationIconTests: SwiftDataTestBase {
    
    @Test("Transportation activities show specific type icons in ActivityRowView")
    func transportationActivitiesShowSpecificTypeIcons() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Test each transportation type shows its specific icon
        let transportationTypes: [(TransportationType, String)] = [
            (.plane, "airplane"),
            (.train, "train.side.front.car"),
            (.boat, "ferry"),
            (.car, "car"),
            (.bicycle, "bicycle"),
            (.walking, "figure.walk")
        ]
        
        for (transportationType, expectedIcon) in transportationTypes {
            // Create transportation activity with specific type
            let transportation = Transportation(
                name: "\(transportationType.rawValue.capitalized) Trip",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            transportation.type = transportationType
            modelContext.insert(transportation)
            
            // Create ActivityWrapper
            let wrapper = ActivityWrapper(transportation)
            
            // Verify the transportation model has the correct specific icon
            #expect(transportation.icon == expectedIcon, "Transportation.\(transportationType.rawValue) should have icon '\(expectedIcon)'")
            
            // Verify ActivityWrapper uses the specific transportation icon, not generic "car.fill"
            #expect(wrapper.tripActivity.icon == expectedIcon, "ActivityWrapper should use specific transportation icon '\(expectedIcon)', not generic type icon")
            #expect(wrapper.tripActivity.icon != wrapper.type.icon, "Transportation activities should use specific icon, not generic '\(wrapper.type.icon)'")
        }
    }
    
    @Test("ActivityWrapper preserves specific transportation icons vs generic type icons")
    func activityWrapperPreservesSpecificTransportationIcons() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Create plane transportation
        let planeTransportation = Transportation(
            name: "Flight to Paris",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        planeTransportation.type = .plane
        modelContext.insert(planeTransportation)
        
        let wrapper = ActivityWrapper(planeTransportation)
        
        // The generic ActivityType.transportation always returns "car.fill"
        #expect(wrapper.type.icon == "car.fill", "Generic ActivityType.transportation should always return 'car.fill'")
        
        // But the specific Transportation should return its type-specific icon
        #expect(wrapper.tripActivity.icon == "airplane", "Plane transportation should return 'airplane' icon")
        
        // These should be different - this is the core issue we're fixing
        #expect(wrapper.type.icon != wrapper.tripActivity.icon, "Generic type icon should differ from specific transportation icon")
    }
    
    @Test("Non-transportation activities continue using generic type icons")
    func nonTransportationActivitiesUseGenericTypeIcons() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Create lodging activity
        let lodging = Lodging(
            name: "Hotel Stay",
            start: Date(),
            end: Date(),
            cost: 0,
            paid: PaidStatus.none,
            trip: trip,
            organization: org
        )
        modelContext.insert(lodging)
        
        // Create general activity
        let activity = Activity(
            name: "Museum Visit",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        modelContext.insert(activity)
        
        let lodgingWrapper = ActivityWrapper(lodging)
        let activityWrapper = ActivityWrapper(activity)
        
        // Non-transportation activities should use their generic type icons
        #expect(lodgingWrapper.tripActivity.icon == lodgingWrapper.type.icon, "Lodging should use generic type icon")
        #expect(activityWrapper.tripActivity.icon == activityWrapper.type.icon, "Activity should use generic type icon")
        
        #expect(lodgingWrapper.type.icon == "bed.double.fill", "Lodging should use bed icon")
        #expect(activityWrapper.type.icon == "ticket.fill", "Activity should use ticket icon")
    }
    
    @Test("Transportation type changes reflect in icon property")
    func transportationTypeChangesReflectInIcon() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Create transportation activity
        let transportation = Transportation(
            name: "Journey",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        transportation.type = .car
        modelContext.insert(transportation)
        
        let wrapper = ActivityWrapper(transportation)
        
        // Initial state - car
        #expect(wrapper.tripActivity.icon == "car", "Initial car transportation should show car icon")
        
        // Change to plane
        transportation.type = .plane
        #expect(wrapper.tripActivity.icon == "airplane", "After changing to plane, should show airplane icon")
        
        // Change to train
        transportation.type = .train
        #expect(wrapper.tripActivity.icon == "train.side.front.car", "After changing to train, should show train icon")
    }
}