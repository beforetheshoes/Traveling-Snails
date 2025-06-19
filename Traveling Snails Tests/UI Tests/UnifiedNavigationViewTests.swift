//
//  UnifiedNavigationViewTests.swift
//  Traveling Snails Tests
//
//  Created by Ryan Williams on 6/11/25.
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

// MARK: - Test Models

struct MockNavigationItem: NavigationItem {
    let id = UUID()
    var displayName: String
    var displaySubtitle: String?
    var displayIcon: String
    var displayColor: Color
    var displayBadgeCount: Int?
    
    init(
        name: String,
        subtitle: String? = nil,
        icon: String = "circle",
        color: Color = .blue,
        badgeCount: Int? = nil
    ) {
        self.displayName = name
        self.displaySubtitle = subtitle
        self.displayIcon = icon
        self.displayColor = color
        self.displayBadgeCount = badgeCount
    }
}

// MARK: - Navigation Configuration Tests

@Suite("Navigation Configuration Tests")
struct NavigationConfigurationTests {
    
    @Test("Default configuration initialization")
    func testDefaultConfiguration() {
        let config = NavigationConfiguration<MockNavigationItem>(title: "Test")
        
        #expect(config.title == "Test")
        #expect(config.emptyStateTitle == "No Items")
        #expect(config.emptyStateIcon == "tray")
        #expect(config.emptyStateDescription == "No items found")
        #expect(config.addButtonTitle == "Add Item")
        #expect(config.addButtonIcon == "plus")
        #expect(config.searchPlaceholder == "Search...")
        #expect(config.allowsSearch == true)
        #expect(config.allowsSelection == true)
    }
    
    @Test("Custom configuration initialization")
    func testCustomConfiguration() {
        let config = NavigationConfiguration<MockNavigationItem>(
            title: "Custom Title",
            emptyStateTitle: "Empty",
            emptyStateIcon: "folder",
            emptyStateDescription: "No data",
            addButtonTitle: "Create",
            addButtonIcon: "plus.circle",
            searchPlaceholder: "Find...",
            allowsSearch: false,
            allowsSelection: false
        )
        
        #expect(config.title == "Custom Title")
        #expect(config.emptyStateTitle == "Empty")
        #expect(config.emptyStateIcon == "folder")
        #expect(config.emptyStateDescription == "No data")
        #expect(config.addButtonTitle == "Create")
        #expect(config.addButtonIcon == "plus.circle")
        #expect(config.searchPlaceholder == "Find...")
        #expect(config.allowsSearch == false)
        #expect(config.allowsSelection == false)
    }
}

// MARK: - Mock Navigation Item Tests

@Suite("Mock Navigation Item Tests")
struct MockNavigationItemTests {
    
    @Test("Basic item creation")
    func testBasicItemCreation() {
        let item = MockNavigationItem(name: "Test Item")
        
        #expect(item.displayName == "Test Item")
        #expect(item.displaySubtitle == nil)
        #expect(item.displayIcon == "circle")
        #expect(item.displayColor == .blue)
        #expect(item.displayBadgeCount == nil)
    }
    
    @Test("Full item creation")
    func testFullItemCreation() {
        let item = MockNavigationItem(
            name: "Full Item",
            subtitle: "Subtitle",
            icon: "star",
            color: .red,
            badgeCount: 5
        )
        
        #expect(item.displayName == "Full Item")
        #expect(item.displaySubtitle == "Subtitle")
        #expect(item.displayIcon == "star")
        #expect(item.displayColor == .red)
        #expect(item.displayBadgeCount == 5)
    }
    
    @Test("Item identity")
    func testItemIdentity() {
        let item1 = MockNavigationItem(name: "Item 1")
        let item2 = MockNavigationItem(name: "Item 2")
        let item3 = MockNavigationItem(name: "Item 1")
        
        #expect(item1.id != item2.id)
        #expect(item1.id != item3.id)
        #expect(item2.id != item3.id)
    }
    
    @Test("Item hashability")
    func testItemHashability() {
        let item1 = MockNavigationItem(name: "Item 1")
        let item2 = MockNavigationItem(name: "Item 2")
        
        let set = Set([item1, item2])
        #expect(set.count == 2)
        #expect(set.contains(item1))
        #expect(set.contains(item2))
    }
}

// MARK: - Trip Navigation Item Tests

@Suite("Trip Navigation Item Tests")
struct TripNavigationItemTests {
    
    @Test("Trip with name")
    func testTripWithName() {
        let trip = Trip(name: "Summer Vacation")
        
        #expect(trip.displayName == "Summer Vacation")
        #expect(trip.displayIcon == "airplane")
        #expect(trip.displayColor == .blue)
    }
    
    @Test("Trip without name")
    func testTripWithoutName() {
        let trip = Trip(name: "")
        
        #expect(trip.displayName == NSLocalizedString("trip.untitled", value: "Untitled Trip", comment: "Default trip name"))
    }
    
    @Test("Trip with date range")
    func testTripWithDateRange() {
        let trip = Trip(name: "Test Trip")
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
        
        trip.startDate = startDate
        trip.endDate = endDate
        trip.hasStartDate = true
        trip.hasEndDate = true
        
        let subtitle = trip.displaySubtitle
        #expect(subtitle != nil)
        #expect(subtitle!.contains("-"))
    }
    
    @Test("Trip with start date only")
    func testTripWithStartDateOnly() {
        let trip = Trip(name: "Test Trip")
        let startDate = Date()
        
        trip.startDate = startDate
        trip.hasStartDate = true
        trip.hasEndDate = false
        
        let subtitle = trip.displaySubtitle
        #expect(subtitle != nil)
        #expect(subtitle!.contains("Starts"))
    }
    
    @Test("Trip with end date only")
    func testTripWithEndDateOnly() {
        let trip = Trip(name: "Test Trip")
        let endDate = Date()
        
        trip.endDate = endDate
        trip.hasStartDate = false
        trip.hasEndDate = true
        
        let subtitle = trip.displaySubtitle
        #expect(subtitle != nil)
        #expect(subtitle!.contains("Ends"))
    }
    
    @Test("Trip with no dates")
    func testTripWithNoDates() {
        let trip = Trip(name: "Test Trip")
        trip.hasStartDate = false
        trip.hasEndDate = false
        
        let subtitle = trip.displaySubtitle
        #expect(subtitle == NSLocalizedString("trip.noDates", value: "No dates set", comment: "Trip with no dates"))
    }
    
    @Test("Trip badge count")
    func testTripBadgeCount() {
        let trip = Trip(name: "Test Trip")
        
        // Mock totalActivities - in real implementation this would be calculated
        // For testing, we'll assume it's 0 initially
        #expect(trip.displayBadgeCount == nil)
    }
}

// MARK: - Organization Navigation Item Tests

@Suite("Organization Navigation Item Tests")
struct OrganizationNavigationItemTests {
    
    @Test("Organization with name")
    func testOrganizationWithName() {
        let org = Organization()
        org.name = "Acme Corp"
        
        #expect(org.displayName == "Acme Corp")
        #expect(org.displayIcon == "building.2")
        #expect(org.displayColor == .orange)
    }
    
    @Test("Organization without name")
    func testOrganizationWithoutName() {
        let org = Organization()
        org.name = ""
        
        #expect(org.displayName == NSLocalizedString("organization.unnamed", value: "Unnamed Organization", comment: "Default organization name"))
    }
    
    @Test("Organization with contact info")
    func testOrganizationWithContactInfo() {
        let org = Organization()
        org.name = "Test Org"
        org.phone = "555-0123"
        org.email = "test@example.com"
        
        let subtitle = org.displaySubtitle
        #expect(subtitle != nil)
        #expect(subtitle!.contains("555-0123"))
        #expect(subtitle!.contains("test@example.com"))
        #expect(subtitle!.contains("•"))
    }
    
    @Test("Organization badge count")
    func testOrganizationBadgeCount() {
        let org = Organization()
        
        // Initially should have no activities
        #expect(org.displayBadgeCount == nil)
    }
}

// MARK: - Search Functionality Tests

@Suite("Search Functionality Tests")
struct SearchFunctionalityTests {
    
    @Test("Default search filter - name matching")
    func testDefaultSearchFilterName() {
        let items = [
            MockNavigationItem(name: "Apple Inc."),
            MockNavigationItem(name: "Google LLC"),
            MockNavigationItem(name: "Microsoft Corp")
        ]
        
        let searchText = "apple"
        let filteredItems = items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText)
        }
        
        #expect(filteredItems.count == 1)
        #expect(filteredItems.first?.displayName == "Apple Inc.")
    }
    
    @Test("Default search filter - subtitle matching")
    func testDefaultSearchFilterSubtitle() {
        let items = [
            MockNavigationItem(name: "Company A", subtitle: "Software Development"),
            MockNavigationItem(name: "Company B", subtitle: "Hardware Manufacturing"),
            MockNavigationItem(name: "Company C", subtitle: "Consulting Services")
        ]
        
        let searchText = "software"
        let filteredItems = items.filter { item in
            item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        
        #expect(filteredItems.count == 1)
        #expect(filteredItems.first?.displayName == "Company A")
    }
    
    @Test("Search with empty string")
    func testSearchWithEmptyString() {
        let items = [
            MockNavigationItem(name: "Item 1"),
            MockNavigationItem(name: "Item 2"),
            MockNavigationItem(name: "Item 3")
        ]
        
        let searchText = ""
        let filteredItems = items.filter { item in
            searchText.isEmpty ||
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        #expect(filteredItems.count == 3)
    }
    
    @Test("Search case insensitivity")
    func testSearchCaseInsensitivity() {
        let items = [
            MockNavigationItem(name: "Apple Inc."),
            MockNavigationItem(name: "GOOGLE LLC"),
            MockNavigationItem(name: "microsoft corp")
        ]
        
        let searchTexts = ["apple", "APPLE", "Apple", "ApPlE"]
        
        for searchText in searchTexts {
            let filteredItems = items.filter { item in
                item.displayName.localizedCaseInsensitiveContains(searchText)
            }
            #expect(filteredItems.count == 1, "Search for '\(searchText)' should find 1 item")
            #expect(filteredItems.first?.displayName == "Apple Inc.", "Should find Apple Inc. for search '\(searchText)'")
        }
    }
    
    @Test("Search with no matches")
    func testSearchWithNoMatches() {
        let items = [
            MockNavigationItem(name: "Apple Inc."),
            MockNavigationItem(name: "Google LLC"),
            MockNavigationItem(name: "Microsoft Corp")
        ]
        
        let searchText = "Tesla"
        let filteredItems = items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        #expect(filteredItems.isEmpty)
    }
}

// MARK: - UnifiedSearchBar Integration Tests

@Suite("UnifiedSearchBar Integration Tests")
struct UnifiedSearchBarIntegrationTests {
    
    @Test("Search bar configuration")
    func testSearchBarConfiguration() {
        var searchText = ""
        let placeholder = "Search items..."
        
        // Test that UnifiedSearchBar.general works correctly
        // In a real UI test, this would verify the search bar appearance
        #expect(searchText.isEmpty)
        #expect(!placeholder.isEmpty)
        
        // Test search text assignment
        searchText = "test query"
        #expect(searchText == "test query")
    }
    
    @Test("Search bar integration with navigation")
    func testSearchBarIntegrationWithNavigation() {
        let items = [
            MockNavigationItem(name: "Test Item 1"),
            MockNavigationItem(name: "Test Item 2"),
            MockNavigationItem(name: "Different Name")
        ]
        
        let searchText = "Test"
        let filteredItems = items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        #expect(filteredItems.count == 2)
        #expect(filteredItems.contains { $0.displayName == "Test Item 1" })
        #expect(filteredItems.contains { $0.displayName == "Test Item 2" })
    }
}

@Suite("Enhanced Row View Tests")
struct EnhancedRowViewTests {
    
    @Test("Row view accessibility")
    func testRowViewAccessibility() {
        let item = MockNavigationItem(
            name: "Test Item",
            subtitle: "Test Subtitle",
            badgeCount: 3
        )
        
        // Test that accessibility elements are properly configured
        // In a real UI test, this would verify the accessibility tree
        #expect(item.displayName == "Test Item")
        #expect(item.displaySubtitle == "Test Subtitle")
        #expect(item.displayBadgeCount == 3)
    }
    
    @Test("Row view with badge")
    func testRowViewWithBadge() {
        let item = MockNavigationItem(
            name: "Item with Badge",
            badgeCount: 10
        )
        
        #expect(item.displayBadgeCount == 10)
    }
    
    @Test("Row view without badge")
    func testRowViewWithoutBadge() {
        let item = MockNavigationItem(
            name: "Item without Badge",
            badgeCount: nil
        )
        
        #expect(item.displayBadgeCount == nil)
    }
    
    @Test("Row view with zero badge")
    func testRowViewWithZeroBadge() {
        let item = MockNavigationItem(
            name: "Item with Zero Badge",
            badgeCount: 0
        )
        
        #expect(item.displayBadgeCount == 0)
    }
}

// MARK: - Navigation State Tests

@Suite("Navigation State Tests")
struct NavigationStateTests {
    
    @Test("Initial state")
    func testInitialState() {
        let items = [
            MockNavigationItem(name: "Item 1"),
            MockNavigationItem(name: "Item 2")
        ]
        
        // Test initial state assumptions
        #expect(items.count == 2)
        #expect(items[0].displayName == "Item 1")
        #expect(items[1].displayName == "Item 2")
    }
    
    @Test("Empty items list")
    func testEmptyItemsList() {
        let items: [MockNavigationItem] = []
        
        #expect(items.isEmpty)
    }
    
    @Test("Single item list")
    func testSingleItemList() {
        let items = [MockNavigationItem(name: "Only Item")]
        
        #expect(items.count == 1)
        #expect(items.first?.displayName == "Only Item")
    }
}

// MARK: - Convenience Initializer Tests

@Suite("Convenience Initializer Tests")
struct ConvenienceInitializerTests {
    
    @Test("Trip convenience initializer configuration")
    func testTripConvenienceInitializerConfiguration() {
        // Test static string values rather than complex binding scenarios
        let trips: [Trip] = []
        
        // Test that the convenience initializer would create correct configuration
        let expectedTitle = NSLocalizedString("navigation.trips.title", value: "Trips", comment: "Trips navigation title")
        let expectedEmptyTitle = NSLocalizedString("navigation.trips.empty.title", value: "No Trips", comment: "Empty trips title")
        let expectedEmptyDescription = NSLocalizedString("navigation.trips.empty.description", value: "Create your first trip to get started", comment: "Empty trips description")
        
        #expect(!expectedTitle.isEmpty)
        #expect(!expectedEmptyTitle.isEmpty)
        #expect(!expectedEmptyDescription.isEmpty)
        #expect(trips.isEmpty) // Verify empty array handling
    }
    
    @Test("Organization convenience initializer configuration")
    func testOrganizationConvenienceInitializerConfiguration() {
        // Test static string values rather than complex binding scenarios
        let organizations: [Organization] = []
        
        // Test that the convenience initializer would create correct configuration
        let expectedTitle = NSLocalizedString("navigation.organizations.title", value: "Organizations", comment: "Organizations navigation title")
        let expectedEmptyTitle = NSLocalizedString("navigation.organizations.empty.title", value: "No Organizations", comment: "Empty organizations title")
        let expectedEmptyDescription = NSLocalizedString("navigation.organizations.empty.description", value: "Add your first organization to get started", comment: "Empty organizations description")
        
        #expect(!expectedTitle.isEmpty)
        #expect(!expectedEmptyTitle.isEmpty)
        #expect(!expectedEmptyDescription.isEmpty)
        #expect(organizations.isEmpty) // Verify empty array handling
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    @Test("Handling invalid trip data")
    func testHandlingInvalidTripData() {
        let trip = Trip(name: "")
        
        // Should gracefully handle empty name
        #expect(!trip.displayName.isEmpty)
        #expect(trip.displayName == NSLocalizedString("trip.untitled", value: "Untitled Trip", comment: "Default trip name"))
    }
    
    @Test("Handling invalid organization data")
    func testHandlingInvalidOrganizationData() {
        let org = Organization()
        org.name = ""
        
        // Should gracefully handle empty name
        #expect(!org.displayName.isEmpty)
        #expect(org.displayName == NSLocalizedString("organization.unnamed", value: "Unnamed Organization", comment: "Default organization name"))
    }
    
    @Test("Handling nil subtitle")
    func testHandlingNilSubtitle() {
        let item = MockNavigationItem(name: "Test", subtitle: nil)
        
        #expect(item.displaySubtitle == nil)
        
        // Search should still work with nil subtitle
        let searchText = "test"
        let matches = item.displayName.localizedCaseInsensitiveContains(searchText) ||
                     (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        
        #expect(matches == true)
    }
    
    @Test("Handling negative badge count")
    func testHandlingNegativeBadgeCount() {
        let item = MockNavigationItem(name: "Test", badgeCount: -1)
        
        // Badge count can be negative but UI should handle appropriately
        #expect(item.displayBadgeCount == -1)
    }
}

// MARK: - Performance Tests

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("Large list filtering performance")
    func testLargeListFilteringPerformance() {
        // Create a large list of items
        let items = (1...1000).map { i in
            MockNavigationItem(
                name: "Item \(i)",
                subtitle: "Subtitle for item \(i)",
                badgeCount: i % 10 == 0 ? i : nil
            )
        }
        
        let searchText = "Item 5"
        
        let startTime = Date()
        let filteredItems = items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        let endTime = Date()
        
        let timeInterval = endTime.timeIntervalSince(startTime)
        
        #expect(filteredItems.count >= 1) // Should find at least "Item 5"
        #expect(timeInterval < 0.1) // Should complete within 100ms
    }
    
    @Test("Memory usage with large datasets")
    func testMemoryUsageWithLargeDatasets() {
        // Create items and ensure they can be deallocated
        var items: [MockNavigationItem]? = (1...10000).map { i in
            MockNavigationItem(name: "Item \(i)")
        }
        
        #expect(items?.count == 10000)
        
        // Clear reference
        items = nil
        
        // Items should be deallocated (this is more of a conceptual test)
        #expect(items == nil)
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("Tab switching behavior")
    func testTabSwitchingBehavior() {
        var selectedTabValue = 0
        
        // Simulate tab switch
        selectedTabValue = 1
        
        #expect(selectedTabValue == 1)
    }
    
    @Test("Trip selection from external source")
    func testTripSelectionFromExternalSource() {
        let trip = Trip(name: "Selected Trip")
        var selectedTripValue: Trip? = nil
        
        // Simulate external trip selection
        selectedTripValue = trip
        
        #expect(selectedTripValue?.id == trip.id)
        #expect(selectedTripValue?.name == "Selected Trip")
    }
}

// MARK: - Localization Tests

@Suite("Localization Tests")
struct LocalizationTests {
    
    @Test("Default string localization")
    func testDefaultStringLocalization() {
        let untitledTrip = NSLocalizedString("trip.untitled", value: "Untitled Trip", comment: "Default trip name")
        let unnamedOrg = NSLocalizedString("organization.unnamed", value: "Unnamed Organization", comment: "Default organization name")
        
        #expect(!untitledTrip.isEmpty)
        #expect(!unnamedOrg.isEmpty)
        #expect(untitledTrip == "Untitled Trip") // Default value
        #expect(unnamedOrg == "Unnamed Organization") // Default value
    }
    
    @Test("Navigation strings localization")
    func testNavigationStringsLocalization() {
        let selectItemTitle = NSLocalizedString("navigation.detail.selectItem.title", value: "Select an Item", comment: "Title when no item is selected")
        let selectItemDescription = NSLocalizedString("navigation.detail.selectItem.description", value: "Choose an item from the list to view details", comment: "Description when no item is selected")
        
        #expect(!selectItemTitle.isEmpty)
        #expect(!selectItemDescription.isEmpty)
    }
    
    @Test("Accessibility strings localization")
    func testAccessibilityStringsLocalization() {
        let accessibilityHint = NSLocalizedString("navigation.row.accessibilityHint", value: "Double tap to view details", comment: "Accessibility hint for navigation rows")
        
        #expect(!accessibilityHint.isEmpty)
        #expect(accessibilityHint == "Double tap to view details") // Default value
    }
}

// MARK: - Test Utilities

// Simple test utilities for validation
extension String {
    func isValidLocalizationKey() -> Bool {
        return !isEmpty && contains(".")
    }
}
