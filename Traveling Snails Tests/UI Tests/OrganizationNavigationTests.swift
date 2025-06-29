//
//  OrganizationNavigationTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

/// Tests for organization navigation functionality
/// Ensures organization detail view is properly integrated with navigation system
@MainActor
@Suite("Organization Navigation Tests")
struct OrganizationNavigationTests {
    // MARK: - Test Helper Methods

    private func createTestOrganization(name: String = "Test Organization", context: ModelContext) -> Organization {
        let organization = Organization(
            name: name,
            phone: "555-0123",
            email: "test@example.com",
            website: "https://example.com"
        )
        context.insert(organization)
        return organization
    }

    private func createTestOrganizationWithAddress(context: ModelContext) -> Organization {
        let organization = createTestOrganization(name: "Org with Address", context: context)
        organization.address = Address(
            street: "123 Test St",
            city: "Test City",
            state: "TS",
            country: "Test Country",
            postalCode: "12345"
        )
        return organization
    }

    // MARK: - Navigation Configuration Tests

    @Test("Organization navigation configuration should have correct settings")
    func testOrganizationNavigationConfiguration() {
        _ = SwiftDataTestBase() // Ensure test environment
        let organizations: [Organization] = []

        let navigationView = UnifiedNavigationView.organizations(
            organizations: organizations,
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            tabIndex: 1
        )

        // Verify configuration properties through the navigation view
        let config = navigationView.configuration
        #expect(config.title == NSLocalizedString("navigation.organizations.title", value: "Organizations", comment: "Organizations navigation title"))
        #expect(config.allowsSearch == true)
        #expect(config.allowsSelection == true)
        #expect(config.emptyStateIcon == "building.2")
        #expect(config.addButtonIcon == "plus")
    }

    // MARK: - Organization NavigationItem Protocol Tests

    @Test("Organization should implement NavigationItem protocol correctly")
    func testOrganizationNavigationItemConformance() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganization(context: testBase.modelContext)

        // Test NavigationItem properties
        #expect(organization.displayName == "Test Organization")
        #expect(organization.displayIcon == "building.2")
        #expect(organization.displayColor == .orange)
        #expect(organization.displayBadgeCount == nil) // No related items yet

        // Test display subtitle with contact info
        #expect(organization.displaySubtitle == "555-0123 • test@example.com")
    }

    @Test("Organization with no contact info should show usage statistics in subtitle")
    func testOrganizationNavigationItemWithoutContactInfo() {
        let testBase = SwiftDataTestBase()
        let organization = Organization(name: "No Contact Org")
        testBase.modelContext.insert(organization)

        #expect(organization.displaySubtitle == nil) // No contact info or activities

        // Add a trip and activity to test usage statistics
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)

        let activity = Activity(name: "Test Activity", start: Date(), end: Date(), trip: trip, organization: organization)
        testBase.modelContext.insert(activity)

        try! testBase.modelContext.save()

        // Should now show activity count
        #expect(organization.displaySubtitle?.contains("1 activities") == true)
        #expect(organization.displayBadgeCount == 1)
    }

    // MARK: - Organization Detail View Integration Tests

    @Test("Organization detail view should display correctly with navigation parameters")
    func testOrganizationDetailViewIntegration() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganizationWithAddress(context: testBase.modelContext)
        try! testBase.modelContext.save()

        // Create the detail view (this should not crash or fail)
        let detailView = OrganizationDetailView(
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            organization: organization
        )

        // Verify the view can be created without errors
        #expect(detailView.organization.name == "Org with Address")
        #expect(detailView.organization.address?.city == "Test City")
    }

    @Test("Organization detail view should handle None organization correctly")
    func testNoneOrganizationHandling() {
        let testBase = SwiftDataTestBase()

        // Use OrganizationManager to get/create None organization
        let result = OrganizationManager.shared.ensureNoneOrganization(in: testBase.modelContext)
        guard case .success(let noneResult) = result else {
            #expect(Bool(false), "Failed to create None organization")
            return
        }

        let noneOrg = noneResult.organization
        #expect(noneOrg.isNone == true)
        #expect(noneOrg.name == "None")
        #expect(noneOrg.canBeDeleted == false)
    }

    // MARK: - Navigation View Integration Tests

    @Test("Organizations navigation view should use real detail view builder")
    func testOrganizationNavigationDetailViewBuilder() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganization(context: testBase.modelContext)
        try! testBase.modelContext.save()

        let navigationView = UnifiedNavigationView.organizations(
            organizations: [organization],
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            tabIndex: 1
        )

        // Test that detail view builder creates a proper view
        let detailView = navigationView.detailViewBuilder(organization)

        // This test will FAIL initially (TDD approach) because the current implementation
        // uses placeholder text instead of OrganizationDetailView
        // The test expects the detail view to be an actual OrganizationDetailView wrapped in AnyView

        // We can't directly test the type due to AnyView wrapping, but we can verify
        // it's not the placeholder text by checking it doesn't contain "Organization Detail -"
        let detailViewString = String(describing: detailView)
        #expect(!detailViewString.contains("Organization Detail -"), "Detail view should not be placeholder text")
    }

    @Test("Organizations navigation view should use real add view builder")
    func testOrganizationNavigationAddViewBuilder() {
        _ = SwiftDataTestBase() // Ensure test environment

        let navigationView = UnifiedNavigationView.organizations(
            organizations: [],
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            tabIndex: 1
        )

        // Test that add view builder creates a proper view
        let addView = navigationView.addViewBuilder()

        // This test will FAIL initially (TDD approach) because the current implementation
        // uses placeholder text instead of AddOrganizationForm
        // The test expects the add view to be an actual form, not placeholder text

        let addViewString = String(describing: addView)
        #expect(!addViewString.contains("Add Organization View - To Be Implemented"), "Add view should not be placeholder text")
    }

    // MARK: - Organization Search Tests

    @Test("Organization navigation should filter search results correctly")
    func testOrganizationSearchFiltering() {
        let testBase = SwiftDataTestBase()

        let org1 = createTestOrganization(name: "Apple Inc", context: testBase.modelContext)
        let org2 = createTestOrganization(name: "Google LLC", context: testBase.modelContext)
        let org3 = createTestOrganization(name: "Microsoft Corp", context: testBase.modelContext)

        try! testBase.modelContext.save()

        let organizations = [org1, org2, org3]

        // Test default search filter behavior
        let searchResults = organizations.filter { organization in
            organization.displayName.localizedCaseInsensitiveContains("app") ||
            (organization.displaySubtitle?.localizedCaseInsensitiveContains("app") ?? false)
        }

        #expect(searchResults.count == 1)
        #expect(searchResults.first?.name == "Apple Inc")
    }

    // MARK: - Organization Detail View Functionality Tests

    @Test("Organization detail view should show correct activity count")
    func testOrganizationActivityCount() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganization(context: testBase.modelContext)

        // Create a trip with multiple activities for this organization
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)

        let activity1 = Activity(name: "Activity 1", start: Date(), end: Date(), trip: trip, organization: organization)
        let activity2 = Activity(name: "Activity 2", start: Date(), end: Date(), trip: trip, organization: organization)
        let lodging = Lodging(name: "Test Lodging", start: Date(), end: Date(), trip: trip, organization: organization)

        testBase.modelContext.insert(activity1)
        testBase.modelContext.insert(activity2)
        testBase.modelContext.insert(lodging)

        try! testBase.modelContext.save()

        // Test total activity count
        let totalCount = organization.transportation.count + organization.lodging.count + organization.activity.count
        #expect(totalCount == 3) // 2 activities + 1 lodging
    }

    @Test("Organization detail view should handle related trips correctly")
    func testOrganizationRelatedTrips() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganization(context: testBase.modelContext)

        // Create multiple trips with activities for this organization
        let trip1 = Trip(name: "Trip 1")
        let trip2 = Trip(name: "Trip 2")
        let trip3 = Trip(name: "Trip 3")

        testBase.modelContext.insert(trip1)
        testBase.modelContext.insert(trip2)
        testBase.modelContext.insert(trip3)

        // Add activities to trip1 and trip2 only
        let activity1 = Activity(name: "Activity 1", start: Date(), end: Date(), trip: trip1, organization: organization)
        let activity2 = Activity(name: "Activity 2", start: Date(), end: Date(), trip: trip2, organization: organization)

        testBase.modelContext.insert(activity1)
        testBase.modelContext.insert(activity2)

        try! testBase.modelContext.save()

        // Create detail view to test related trips logic
        let detailView = OrganizationDetailView(
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            organization: organization
        )

        #expect(detailView.relatedTrips.count == 2) // Should only include trip1 and trip2
        #expect(detailView.relatedTrips.contains { $0.name == "Trip 1" })
        #expect(detailView.relatedTrips.contains { $0.name == "Trip 2" })
        #expect(!detailView.relatedTrips.contains { $0.name == "Trip 3" })
    }

    // MARK: - Performance Tests

    @Test("Organization navigation view should not cause infinite recreation")
    func testOrganizationNavigationViewStability() {
        let testBase = SwiftDataTestBase()
        let organization = createTestOrganization(context: testBase.modelContext)
        try! testBase.modelContext.save()

        // Measure view creation time to detect infinite recreation
        let startTime = Date()

        for _ in 0..<10 {
            let navigationView = UnifiedNavigationView.organizations(
                organizations: [organization],
                selectedTab: .constant(1),
                selectedTrip: .constant(nil),
                tabIndex: 1
            )

            // Create detail view multiple times
            _ = navigationView.detailViewBuilder(organization)
        }

        let elapsedTime = Date().timeIntervalSince(startTime)

        // Should complete quickly (under 1 second for 10 iterations)
        #expect(elapsedTime < 1.0, "View creation took too long, possible infinite recreation: \(elapsedTime)s")
    }
}
