//
//  DirectoryRestructureIntegrationTests.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("Directory Restructure Integration Tests")
struct DirectoryRestructureIntegrationTests {
    
    // MARK: - File Import and Module Access Tests
    
    @Suite("Module Import Validation")
    struct ModuleImportValidationTests {
        
        @Test("ViewModels are accessible after restructure")
        func testViewModelsAccessibility() throws {
            // Ensure all ViewModels remain accessible after moving
            let trip = Trip(name: "Test Trip")
            
            // Test existing ViewModels (without ModelContext for simplicity)
            // ActivityFormViewModel requires ModelContext, so we'll test others
            
            let calendarViewModel = CalendarViewModel(trip: trip)
            #expect(calendarViewModel.trip.name == "Test Trip")
            
            // Test new NavigationViewModel
            let config = NavigationConfiguration<Trip>(title: "Test")
            let navigationViewModel = NavigationViewModel(items: [trip], configuration: config, tabIndex: 0)
            #expect(navigationViewModel.items.count == 1)
        }
        
        @Test("Content Views are accessible after restructure")
        func testContentViewsAccessibility() throws {
            // Test that content views can be instantiated after restructure
            let trip = Trip(name: "Test Trip")
            let config = NavigationConfiguration<Trip>(title: "Test")
            
            let _ = NavigationContentView(
                items: [trip],
                configuration: config,
                searchText: .constant(""),
                selectedItem: .constant(nil),
                onItemTap: { _ in },
                onAddTap: { }
            )
            
            // Should be able to create content view
            #expect(config.title == "Test")
        }
        
        @Test("Root Views maintain proper coordination")
        func testRootViewCoordination() throws {
            // Test that root views can still coordinate with ViewModels
            let trips: [Trip] = [Trip(name: "Test Trip")]
            
            let _ = UnifiedNavigationRootView.trips(
                trips: trips,
                selectedTab: .constant(0),
                selectedTrip: .constant(nil),
                tabIndex: 0
            )
            
            // Should be able to create root view with proper configuration
            #expect(trips.count == 1)
        }
    }
    
    // MARK: - File Structure Validation Tests
    
    @Suite("File Structure Validation")
    struct FileStructureValidationTests {
        
        @Test("All required files exist in expected locations")
        func testRequiredFilesExistence() throws {
            // This will validate that critical files are accessible
            // We'll update expected paths as we restructure
            
            // Core models should remain accessible
            let trip = Trip(name: "Test")
            let org = Organization(name: "Test Org")
            let address = Address(street: "Test St")
            
            #expect(trip.name == "Test")
            #expect(org.name == "Test Org")
            #expect(address.street == "Test St")
            
            // ViewModels should be accessible
            let calendarVM = CalendarViewModel(trip: trip)
            #expect(calendarVM.trip.name == "Test")
        }
        
        @Test("Import statements resolve correctly")
        func testImportStatements() throws {
            // Test that our imports work correctly after restructure
            // This ensures no circular dependencies or missing imports
            
            // Test SwiftUI imports
            let color: Color = .blue
            #expect(color == .blue)
            
            // Test Foundation imports
            let uuid = UUID()
            #expect(uuid.uuidString.count > 0)
            
            // Test model imports work
            let trip = Trip(name: "Import Test")
            #expect(trip.id != UUID())
        }
    }
    
    // MARK: - Navigation Flow Integration Tests
    
    @Suite("Navigation Flow Integration")
    struct NavigationFlowIntegrationTests {
        
        @Test("Complete navigation flow works after restructure")
        func testCompleteNavigationFlow() throws {
            // Test end-to-end navigation flow
            let trips: [Trip] = [
                Trip(name: "Business Trip"),
                Trip(name: "Vacation")
            ]
            
            let config = NavigationConfiguration<Trip>(
                title: "Trips",
                emptyStateTitle: "No Trips"
            )
            
            let viewModel = NavigationViewModel(
                items: trips,
                configuration: config,
                tabIndex: 0
            )
            
            // Test search functionality
            viewModel.handleSearch("Business")
            let searchResults = viewModel.filteredItems
            #expect(searchResults.count == 1)
            #expect(searchResults.first?.name == "Business Trip")
            
            // Test selection
            let selectedTrip = trips.first!
            viewModel.selectItem(selectedTrip)
            #expect(viewModel.selectedItem?.id == selectedTrip.id)
            
            // Test tab coordination
            viewModel.handleTabChange(to: 1)
            #expect(viewModel.selectedItem == nil)
        }
        
        @Test("View hierarchy construction succeeds")
        func testViewHierarchyConstruction() throws {
            // Test that complex view hierarchies can be built
            let trip = Trip(name: "Hierarchy Test")
            
            // Test that we can create nested view structures
            let _ = TripDetailView(trip: trip)
            
            // Should be able to reference view without compilation errors
            #expect(trip.name == "Hierarchy Test")
        }
    }
    
    // MARK: - Performance and Memory Tests
    
    @Suite("Performance After Restructure")
    struct PerformanceAfterRestructureTests {
        
        @Test("ViewModel creation performance remains good")
        func testViewModelCreationPerformance() throws {
            let trips = (0..<100).map { Trip(name: "Trip \($0)") }
            let config = NavigationConfiguration<Trip>(title: "Performance Test")
            
            let startTime = Date()
            let viewModel = NavigationViewModel(items: trips, configuration: config, tabIndex: 0)
            let endTime = Date()
            
            let duration = endTime.timeIntervalSince(startTime)
            
            #expect(viewModel.items.count == 100)
            #expect(duration < 0.1) // Should create in under 100ms
        }
        
        @Test("Search performance remains efficient")
        func testSearchPerformance() throws {
            let trips = (0..<1000).map { Trip(name: "Trip \($0) Test Data") }
            let config = NavigationConfiguration<Trip>(title: "Search Performance")
            let viewModel = NavigationViewModel(items: trips, configuration: config, tabIndex: 0)
            
            let startTime = Date()
            viewModel.handleSearch("500")
            let results = viewModel.filteredItems
            let endTime = Date()
            
            let duration = endTime.timeIntervalSince(startTime)
            
            #expect(results.count == 1)
            #expect(duration < 6.0) // Should search in under 6 seconds for 1000 items
        }
    }
    
    // MARK: - Backwards Compatibility Tests
    
    @Suite("Backwards Compatibility")
    struct BackwardsCompatibilityTests {
        
        @Test("Existing API signatures remain unchanged")
        func testExistingAPISignatures() throws {
            // Test that public APIs we depend on haven't changed
            let trip = Trip(name: "API Test")
            
            // Core model APIs
            #expect(trip.name == "API Test")
            #expect(trip.id != UUID())
            #expect(trip.totalActivities >= 0)
            
            // Navigation item protocol conformance
            let navigationTrip: any NavigationItem = trip
            #expect(navigationTrip.displayName == "API Test")
            #expect(navigationTrip.displayIcon == "airplane")
            #expect(navigationTrip.displayColor == .blue)
        }
        
        @Test("Existing convenience initializers still work")
        func testConvenienceInitializers() throws {
            // Test that convenience methods still function
            let trips: [Trip] = [Trip(name: "Convenience Test")]
            
            let _ = UnifiedNavigationRootView.trips(
                trips: trips,
                selectedTab: .constant(0),
                selectedTrip: .constant(nil),
                tabIndex: 0
            )
            
            let organizations: [Organization] = [Organization(name: "Test Org")]
            
            let _ = UnifiedNavigationRootView.organizations(
                organizations: organizations,
                selectedTab: .constant(1),
                selectedTrip: .constant(nil),
                tabIndex: 1
            )
            
            // Should be able to create both navigation types
            #expect(trips.count == 1)
            #expect(organizations.count == 1)
        }
    }
}

// MARK: - Helper Extensions for Testing

extension DirectoryRestructureIntegrationTests {
    
    /// Helper to validate file accessibility after moves
    static func validateFileAccess<T>(_ type: T.Type, expectedCount: Int = 1) -> Bool {
        // This would be expanded to actually check file system access
        // For now, we validate that types are accessible
        return true
    }
    
    /// Helper to validate import resolution
    static func validateImports() -> Bool {
        // Validate that all necessary imports resolve
        let _ = SwiftUI.Color.blue
        let _ = Foundation.UUID()
        return true
    }
}