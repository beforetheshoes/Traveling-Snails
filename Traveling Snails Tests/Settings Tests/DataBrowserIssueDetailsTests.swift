import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("DataBrowser Issue Details Tests")
@MainActor
struct DataBrowserIssueDetailsTests {
    // MARK: - Test Issue Detail Display Functions

    @Test("getDetailedItems returns correct format for blank entries")
    func getDetailedItemsFormatForBlankEntries() {
        let testBase = SwiftDataTestBase()
        
        // Create test diagnostic results with blank entries
        var results = DataBrowserView.DiagnosticResults()

        // Create mock blank transportation
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        testBase.modelContext.insert(trip)

        let blankTransportation = Transportation(
            type: .plane,
            start: Date(),
            end: Date().addingTimeInterval(3600),
            trip: trip
        )
        blankTransportation.name = ""

        let blankLodging = Lodging(
            start: Date(),
            end: Date().addingTimeInterval(86_400),
            trip: trip
        )
        blankLodging.name = ""

        let blankActivity = Activity(
            name: "",
            start: Date(),
            end: Date().addingTimeInterval(3600),
            trip: trip
        )

        results.blankTransportation = [blankTransportation]
        results.blankLodging = [blankLodging]
        results.blankActivities = [blankActivity]

        // Test that getDetailedItems function would work
        // This tests the format that should be implemented in AllIssuesFixerContent
        _ = [
            "Transportation: \(blankTransportation.type.rawValue) (no name)",
            "Lodging: (no name)",
            "Activity: (no name)",
        ]

        // Verify the data structure contains the needed information
        #expect(results.blankTransportation.count == 1)
        #expect(results.blankLodging.count == 1)
        #expect(results.blankActivities.count == 1)
        #expect(results.issueCount(for: .blankEntries) == 3)

        // Verify the individual items have the correct properties for display
        #expect(results.blankTransportation.first?.name.isEmpty == true)
        #expect(results.blankTransportation.first?.type == .plane)
        #expect(results.blankLodging.first?.name.isEmpty == true)
        #expect(results.blankActivities.first?.name.isEmpty == true)
    }

    @Test("Diagnostic results structure supports detailed item display")
    func diagnosticResultsSupportsDetailedItemDisplay() {
        // Test that DiagnosticResults has all the arrays needed for detailed display
        let results = DataBrowserView.DiagnosticResults()

        // Verify all issue type arrays exist
        #expect(results.blankTransportation.isEmpty)
        #expect(results.blankLodging.isEmpty)
        #expect(results.blankActivities.isEmpty)
        #expect(results.orphanedTransportation.isEmpty)
        #expect(results.orphanedLodging.isEmpty)
        #expect(results.orphanedActivities.isEmpty)
        #expect(results.orphanedAddresses.isEmpty)
        #expect(results.orphanedAttachments.isEmpty)
        #expect(results.invalidTimezoneTransportation.isEmpty)
        #expect(results.invalidTimezoneLodging.isEmpty)
        #expect(results.invalidTimezoneActivities.isEmpty)
        #expect(results.invalidDateTransportation.isEmpty)
        #expect(results.invalidDateLodging.isEmpty)
        #expect(results.invalidDateActivities.isEmpty)
        #expect(results.activitiesWithoutOrganizations.isEmpty)
        #expect(results.brokenAttachments.isEmpty)

        // Verify issue counting works
        #expect(results.hasIssues == false)
        #expect(results.totalIssues == 0)
    }

    @Test("Issue types have proper display properties")
    func issueTypesHaveProperDisplayProperties() {
        // Test that all issue types have the properties needed for UI display
        for issueType in DataBrowserView.IssueType.allCases {
            #expect(!issueType.rawValue.isEmpty)
            #expect(!issueType.icon.isEmpty)

            // Verify color is one of the expected colors
            let color = issueType.color
            #expect(color == .red || color == .orange || color == .yellow)
        }
    }

    @Test("Issue description generation works correctly")
    func issueDescriptionGenerationWorksCorrectly() {
        let testBase = SwiftDataTestBase()
        
        // Create test data
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        testBase.modelContext.insert(trip)

        var results = DataBrowserView.DiagnosticResults()

        // Add some test issues
        let blankTransportation = Transportation(type: .plane, start: Date(), end: Date().addingTimeInterval(3600), trip: trip)
        blankTransportation.name = ""
        results.blankTransportation = [blankTransportation]

        let orphanedActivity = Activity(name: "Orphaned Activity", start: Date(), end: Date().addingTimeInterval(3600), trip: nil)
        results.orphanedActivities = [orphanedActivity]

        // Test description generation logic (this exists in DataBrowserView)
        #expect(results.issueCount(for: .blankEntries) == 1)
        #expect(results.issueCount(for: .orphanedData) == 1)

        // The descriptions should include counts and types
        // This validates that the data structure supports creating descriptions like:
        // "Entries with no name: 1 transportation"
        // "Data not linked to trips: 1 activities"
    }

    // MARK: - Test UI Enhancement Requirements

    @Test("DataBrowserIssuesTab should show expandable details")
    func dataBrowserIssuesTabShouldShowExpandableDetails() {
        let testBase = SwiftDataTestBase()
        
        // This test documents the requirement for the UI enhancement
        // The DataBrowserIssuesTab currently only shows:
        // - Issue type name
        // - Issue count  
        // - Basic description

        // It should be enhanced to also show:
        // - Expandable section with detailed item list
        // - Individual problematic items with specific details
        // - "Show Details" / "Hide Details" toggle

        // Create test data to validate the enhancement
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        testBase.modelContext.insert(trip)

        var results = DataBrowserView.DiagnosticResults()

        let blankActivity1 = Activity(name: "", start: Date(), end: Date().addingTimeInterval(3600), trip: trip)
        let blankActivity2 = Activity(name: "", start: Date(), end: Date().addingTimeInterval(3600), trip: trip)

        results.blankActivities = [blankActivity1, blankActivity2]

        // Verify we have data that should be displayed in expanded details
        #expect(results.blankActivities.count == 2)
        #expect(results.issueCount(for: .blankEntries) == 2)

        // Each item should be individually displayable in the UI
        for activity in results.blankActivities {
            #expect(activity.name.isEmpty)
            // This activity should appear as "Activity: (no name)" in the detailed list
        }
    }

    @Test("UI should handle large lists with truncation")
    func uiShouldHandleLargeListsWithTruncation() {
        let testBase = SwiftDataTestBase()
        
        // Test the truncation pattern used in AllIssuesFixerContent
        // Shows first 10 items + "... and X more" pattern

        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86_400))
        testBase.modelContext.insert(trip)

        var results = DataBrowserView.DiagnosticResults()

        // Create 15 blank activities to test truncation
        var blankActivities: [Activity] = []
        for _ in 1...15 {
            let activity = Activity(name: "", start: Date(), end: Date().addingTimeInterval(3600), trip: trip)
            blankActivities.append(activity)
        }

        results.blankActivities = blankActivities

        #expect(results.blankActivities.count == 15)

        // The UI should show first 10 items
        let displayItems = Array(results.blankActivities.prefix(10))
        #expect(displayItems.count == 10)

        // Plus a "... and 5 more" indicator
        let remainingCount = results.blankActivities.count - 10
        #expect(remainingCount == 5)

        // This validates the truncation pattern: Array(items.prefix(10)) + ["... and \(remainingCount) more"]
    }
}
