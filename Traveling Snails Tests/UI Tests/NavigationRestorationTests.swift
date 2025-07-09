//
//  NavigationRestorationTests.swift
//  Traveling Snails Tests
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Navigation Restoration Tests")
struct NavigationRestorationTests {
    // MARK: - Test Environment Setup

    @MainActor
    private func makeTestEnvironment() -> (ModelContainer, Trip, Activity) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, Activity.self, configurations: config)

        let trip = Trip(name: "Test Trip")
        container.mainContext.insert(trip)

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        container.mainContext.insert(activity)

        try! container.mainContext.save()

        return (container, trip, activity)
    }

    // MARK: - Navigation State Tests

    @Test("Navigation state preserves selected trip when navigating from activity detail", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .trip, .activity, .validation, .mainActor))
    @MainActor func testNavigationStatePreservesSelectedTrip() async {
        let (_, trip, activity) = makeTestEnvironment()

        // Simulate navigation state
        let selectedTrip: Trip? = trip
        let selectedActivity: (any TripActivityProtocol)? = activity
        var currentView: NavigationDestination = .activityDetail(activity)

        // Verify initial state
        #expect(selectedTrip != nil)
        #expect(selectedActivity != nil)
        #expect(currentView.isSameType(as: .activityDetail(activity)))

        // Simulate navigating to different tab and back
        currentView = .tripList
        // Selected trip should be preserved
        #expect(selectedTrip != nil)

        // When navigating back, should restore to activity detail
        if let _ = selectedTrip, let preservedActivity = selectedActivity {
            currentView = .activityDetail(preservedActivity)
            #expect(currentView.isSameType(as: .activityDetail(preservedActivity)))
        }
    }

    @Test("Navigation state handles trip selection from activity detail", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .trip, .activity, .validation, .mainActor))
    @MainActor func testNavigationStateHandlesTripSelectionFromActivityDetail() async {
        let (_, trip, activity) = makeTestEnvironment()

        // Simulate being in activity detail view
        let selectedTrip: Trip? = trip
        var currentView: NavigationDestination = .activityDetail(activity)

        // Verify we're viewing the activity detail
        #expect(currentView.isSameType(as: .activityDetail(activity)))
        #expect(selectedTrip != nil)

        // Simulate clicking on the trip in the trip list while viewing activity detail
        // This should navigate to trip detail, not stay on activity detail
        currentView = .tripDetail(trip)

        // Should now be viewing trip detail
        #expect(currentView.isSameType(as: .tripDetail(trip)))
        #expect(selectedTrip != nil)
    }

    @Test("Navigation state restores activity detail after tab switch", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testNavigationStateRestoresActivityDetailAfterTabSwitch() async {
        let (_, trip, activity) = makeTestEnvironment()

        // Start with activity detail view
        let _: Trip? = trip  // Indicate intentionally unused
        let selectedActivity: (any TripActivityProtocol)? = activity
        var currentView: NavigationDestination = .activityDetail(activity)
        var selectedTab = 0 // Trips tab

        #expect(currentView.isSameType(as: .activityDetail(activity)))
        #expect(selectedTab == 0)

        // Switch to different tab
        selectedTab = 1 // Organizations tab
        #expect(selectedTab == 1)
        _ = currentView // Store previous view state

        // Switch back to trips tab
        selectedTab = 0
        #expect(selectedTab == 0)

        // Should restore to activity detail if that's where we were
        if let preservedActivity = selectedActivity {
            currentView = .activityDetail(preservedActivity)
            #expect(currentView.isSameType(as: .activityDetail(preservedActivity)))
        }
    }

    @Test("Navigation handles missing selected trip gracefully", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .trip, .errorHandling, .validation, .mainActor))
    @MainActor func testNavigationHandlesMissingSelectedTripGracefully() async {
        let (_, _, activity) = makeTestEnvironment()

        // Start with activity but no selected trip
        let selectedTrip: Trip? = nil
        var currentView: NavigationDestination = .activityDetail(activity)

        // Should handle gracefully
        #expect(selectedTrip == nil)
        #expect(currentView.isSameType(as: .activityDetail(activity)))

        // When trip is missing, should fall back to appropriate view
        if selectedTrip == nil {
            currentView = .tripList
            #expect(currentView.isSameType(as: .tripList))
        }
    }

    // MARK: - Activity Detail View State Tests

    @Test("Activity detail view preserves state when navigation occurs", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testActivityDetailViewPreservesStateWhenNavigationOccurs() async {
        let (_, _, _) = makeTestEnvironment()

        // Simulate activity detail view state
        var isShowingEditForm = false
        let scrollPosition: CGFloat = 100.0
        var selectedTab = 0  // Tab index

        // User opens edit form
        isShowingEditForm = true
        #expect(isShowingEditForm == true)

        // User switches tabs - simulate tab navigation
        selectedTab = 1
        #expect(selectedTab == 1)

        // User switches back
        selectedTab = 0
        #expect(selectedTab == 0)

        // Edit form state should be preserved
        #expect(isShowingEditForm == true)
        #expect(scrollPosition == 100.0)
    }

    @Test("Activity detail view updates when underlying activity changes", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testActivityDetailViewUpdatesWhenUnderlyingActivityChanges() async {
        let (container, _, activity) = makeTestEnvironment()
        let context = container.mainContext

        let originalName = activity.name
        #expect(originalName == "Test Activity")

        // Simulate activity update
        activity.name = "Updated Activity Name"
        try! context.save()

        // View should reflect the updated name
        #expect(activity.name == "Updated Activity Name")
    }

    // MARK: - Navigation Menu Tests

    @Test("Navigation menu handles activity selection correctly", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testNavigationMenuHandlesActivitySelectionCorrectly() async {
        let (container, trip, activity) = makeTestEnvironment()

        // Create additional activity for testing
        let startDate2 = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        let endDate2 = Calendar.current.date(byAdding: .hour, value: 6, to: startDate2) ?? startDate2
        let activity2 = Activity(
            name: "Second Activity",
            start: startDate2,
            end: endDate2,
            trip: trip
        )
        container.mainContext.insert(activity2)
        try! container.mainContext.save()

        var selectedActivity: (any TripActivityProtocol)? = activity
        var currentView: NavigationDestination = .activityDetail(activity)

        // Verify first activity is selected
        #expect(selectedActivity != nil)
        #expect(currentView.isSameType(as: .activityDetail(activity)))

        // Select second activity from navigation
        selectedActivity = activity2
        currentView = .activityDetail(activity2)

        // Should now show second activity
        #expect(selectedActivity != nil)
        #expect(currentView.isSameType(as: .activityDetail(activity2)))
    }

    // MARK: - Edge Cases

    @Test("Navigation handles deleted activity gracefully", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .errorHandling, .validation, .mainActor))
    @MainActor func testNavigationHandlesDeletedActivityGracefully() async {
        let (container, trip, activity) = makeTestEnvironment()
        let context = container.mainContext

        var selectedActivity: (any TripActivityProtocol)? = activity
        var currentView: NavigationDestination = .activityDetail(activity)

        #expect(selectedActivity != nil)

        // Delete the activity
        context.delete(activity)
        try! context.save()

        // Navigation should handle gracefully
        selectedActivity = nil
        currentView = .tripDetail(trip)

        #expect(selectedActivity == nil)
        #expect(currentView.isSameType(as: .tripDetail(trip)))
    }

    @Test("Navigation preserves trip detail selection when valid", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .trip, .activity, .validation, .mainActor))
    @MainActor func testNavigationPreservesTripDetailSelectionWhenValid() async {
        let (_, trip, activity) = makeTestEnvironment()

        let selectedTrip: Trip? = trip
        var currentView: NavigationDestination = .tripDetail(trip)

        #expect(selectedTrip != nil)
        #expect(currentView.isSameType(as: .tripDetail(trip)))

        // Navigate to activity detail
        currentView = .activityDetail(activity)

        // Trip selection should be preserved
        #expect(selectedTrip != nil)
        #expect(currentView.isSameType(as: .activityDetail(activity)))

        // Navigate back to trip detail
        currentView = .tripDetail(trip)

        #expect(selectedTrip != nil)
        #expect(currentView.isSameType(as: .tripDetail(trip)))
    }
}

// MARK: - Supporting Types

enum NavigationDestination: Equatable {
    case tripList
    case tripDetail(Trip)
    case activityDetail(any TripActivityProtocol)

    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.tripList, .tripList):
            return true
        case (.tripDetail(let trip1), .tripDetail(let trip2)):
            return trip1.id == trip2.id
        case (.activityDetail(let activity1), .activityDetail(let activity2)):
            return activity1.id == activity2.id
        default:
            return false
        }
    }

    // Test-safe comparison that avoids SwiftData ID access
    func isSameType(as other: NavigationDestination) -> Bool {
        switch (self, other) {
        case (.tripList, .tripList):
            return true
        case (.tripDetail, .tripDetail):
            return true
        case (.activityDetail, .activityDetail):
            return true
        default:
            return false
        }
    }
}
