import Testing
import SwiftData
import Foundation
@testable import Traveling_Snails

@Suite("Reactive Icon Tests")
@MainActor
final class ReactiveIconTests: SwiftDataTestBase {
    
    @Test("View model currentIcon updates immediately when transportation type changes")
    func viewModelCurrentIconUpdatesImmediately() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Create view model for new transportation activity
        let viewModel = UniversalActivityFormViewModel(
            trip: trip,
            activityType: .transportation,
            modelContext: modelContext
        )
        
        // Initial state - should use default plane icon
        #expect(viewModel.currentIcon == "airplane", "Initial transportation should show airplane icon (default)")
        #expect(viewModel.editData.transportationType == .plane, "Default transportation type should be plane")
        
        // Change to car
        viewModel.editData.transportationType = .car
        #expect(viewModel.currentIcon == "car", "After changing to car, currentIcon should immediately update to car icon")
        
        // Change to train
        viewModel.editData.transportationType = .train
        #expect(viewModel.currentIcon == "train.side.front.car", "After changing to train, currentIcon should immediately update to train icon")
        
        // Change to boat
        viewModel.editData.transportationType = .boat
        #expect(viewModel.currentIcon == "ferry", "After changing to boat, currentIcon should immediately update to ferry icon")
        
        // Change to bicycle
        viewModel.editData.transportationType = .bicycle
        #expect(viewModel.currentIcon == "bicycle", "After changing to bicycle, currentIcon should immediately update to bicycle icon")
        
        // Change to walking
        viewModel.editData.transportationType = .walking
        #expect(viewModel.currentIcon == "figure.walk", "After changing to walking, currentIcon should immediately update to walking icon")
        
        // Change back to plane
        viewModel.editData.transportationType = .plane
        #expect(viewModel.currentIcon == "airplane", "After changing back to plane, currentIcon should return to airplane icon")
    }
    
    @Test("Non-transportation activities use static icon")
    func nonTransportationActivitiesUseStaticIcon() {
        // Create test trip
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        modelContext.insert(trip)
        
        // Test lodging activity
        let lodgingViewModel = UniversalActivityFormViewModel(
            trip: trip,
            activityType: .lodging,
            modelContext: modelContext
        )
        
        // Lodging should use static icon regardless of transportation type changes
        #expect(lodgingViewModel.currentIcon == lodgingViewModel.icon, "Lodging should use static icon")
        #expect(lodgingViewModel.currentIcon == "bed.double.fill", "Lodging should use bed icon")
        
        // Test general activity
        let activityViewModel = UniversalActivityFormViewModel(
            trip: trip,
            activityType: .activity,
            modelContext: modelContext
        )
        
        #expect(activityViewModel.currentIcon == activityViewModel.icon, "Activity should use static icon")
        #expect(activityViewModel.currentIcon == "ticket.fill", "Activity should use ticket icon")
    }
    
    @Test("Edit mode preserves existing transportation icon")
    func editModePreservesExistingTransportationIcon() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        // Create existing transportation with specific type
        let existingTransportation = Transportation(
            name: "Flight to NYC",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        existingTransportation.type = .plane
        modelContext.insert(existingTransportation)
        
        // Verify the transportation model itself has correct data
        #expect(existingTransportation.type == .plane, "Transportation model should have plane type")
        #expect(existingTransportation.transportationType == .plane, "Transportation transportationType property should return plane")
        #expect(existingTransportation.icon == "airplane", "Transportation icon should be airplane")
        
        // Create view model for editing existing transportation
        let viewModel = UniversalActivityFormViewModel(
            existingActivity: existingTransportation,
            modelContext: modelContext
        )
        
        // Debug: Check if edit data is initialized correctly
        #expect(viewModel.editData.transportationType == .plane, "Edit mode should preserve existing transportation type")
        #expect(viewModel.activityType == .transportation, "View model should recognize this as transportation activity")
        
        // Should show existing transportation type icon
        #expect(viewModel.currentIcon == "airplane", "Edit mode should show existing transportation icon")
        
        // Changing transportation type should update icon immediately
        viewModel.editData.transportationType = .train
        #expect(viewModel.currentIcon == "train.side.front.car", "Icon should update immediately even in edit mode")
        
        // Test multiple type changes to ensure reactivity works
        viewModel.editData.transportationType = .boat
        #expect(viewModel.currentIcon == "ferry", "Icon should update to ferry when changed to boat")
        
        viewModel.editData.transportationType = .car
        #expect(viewModel.currentIcon == "car", "Icon should update to car when changed to car")
    }
    
    @Test("Edit mode works with different transportation types")
    func editModeWorksWithDifferentTransportationTypes() {
        // Create test trip and organization
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let org = Organization(name: "Test Org")
        modelContext.insert(trip)
        modelContext.insert(org)
        
        let transportationTypes: [(TransportationType, String)] = [
            (.train, "train.side.front.car"),
            (.boat, "ferry"),
            (.car, "car"),
            (.bicycle, "bicycle"),
            (.walking, "figure.walk")
        ]
        
        for (transportationType, expectedIcon) in transportationTypes {
            // Create transportation with specific type
            let transportation = Transportation(
                name: "\(transportationType.displayName) Trip",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )
            transportation.type = transportationType
            modelContext.insert(transportation)
            
            // Create edit mode view model
            let viewModel = UniversalActivityFormViewModel(
                existingActivity: transportation,
                modelContext: modelContext
            )
            
            // Verify initial state
            #expect(viewModel.editData.transportationType == transportationType, "Edit data should preserve \(transportationType.rawValue) type")
            #expect(viewModel.currentIcon == expectedIcon, "Edit mode should show \(expectedIcon) for \(transportationType.rawValue)")
            
            // Test that changes still work
            viewModel.editData.transportationType = .plane
            #expect(viewModel.currentIcon == "airplane", "Should update to airplane icon when changed to plane")
        }
    }
}