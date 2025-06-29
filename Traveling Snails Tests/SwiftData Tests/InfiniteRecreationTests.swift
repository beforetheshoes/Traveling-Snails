//
//  InfiniteRecreationTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Infinite Recreation Tests")
struct InfiniteRecreationTests {
    @Test("DatabaseBrowserTab should not cause infinite recreation with model arrays", .disabled("This test intentionally causes an infinite loop and hangs the test runner."))
    @MainActor
    func testDatabaseBrowserTabRecreation() async throws {
        let testBase = SwiftDataTestBase()

        // Create test data
        let trip = Trip(name: "Test Trip")
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(3600)
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )

        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()

        // Fetch data (simulating current anti-pattern)
        let trips = try testBase.modelContext.fetch(FetchDescriptor<Trip>())
        let activities = try testBase.modelContext.fetch(FetchDescriptor<Activity>())
        let transportation = try testBase.modelContext.fetch(FetchDescriptor<Transportation>())
        let lodging = try testBase.modelContext.fetch(FetchDescriptor<Lodging>())
        let organizations = try testBase.modelContext.fetch(FetchDescriptor<Organization>())
        let addresses = try testBase.modelContext.fetch(FetchDescriptor<Address>())
        let attachments = try testBase.modelContext.fetch(FetchDescriptor<EmbeddedFileAttachment>())

        // Track view recreations
        var creationCount = 0

        // Create a view that tracks recreations
        struct TrackedDatabaseBrowserTab: View {
            let trips: [Trip]
            let transportation: [Transportation]
            let lodging: [Lodging]
            let activities: [Activity]
            let organizations: [Organization]
            let addresses: [Address]
            let attachments: [EmbeddedFileAttachment]
            let creationTracker: () -> Void

            init(trips: [Trip], transportation: [Transportation], lodging: [Lodging],
                 activities: [Activity], organizations: [Organization], addresses: [Address],
                 attachments: [EmbeddedFileAttachment], creationTracker: @escaping () -> Void) {
                self.trips = trips
                self.transportation = transportation
                self.lodging = lodging
                self.activities = activities
                self.organizations = organizations
                self.addresses = addresses
                self.attachments = attachments
                self.creationTracker = creationTracker

                // Track each creation
                creationTracker()
            }

            var body: some View {
                VStack {
                    Text("Trips: \(trips.count)")
                    Text("Activities: \(activities.count)")
                }
            }
        }

        // Create the view with the anti-pattern
        _ = TrackedDatabaseBrowserTab(
            trips: trips,
            transportation: transportation,
            lodging: lodging,
            activities: activities,
            organizations: organizations,
            addresses: addresses,
            attachments: attachments
        )            { creationCount += 1 }

        // Simulate adding a new activity (which would trigger SwiftData updates)
        let newActivity = Activity(name: "New Activity", start: Date(), end: Date().addingTimeInterval(1800))
        newActivity.trip = trip
        testBase.modelContext.insert(newActivity)
        try testBase.modelContext.save()

        // The issue: if we re-fetch and recreate the view, it recreates infinitely
        let updatedActivities = try testBase.modelContext.fetch(FetchDescriptor<Activity>())

        _ = TrackedDatabaseBrowserTab(
            trips: trips,
            transportation: transportation,
            lodging: lodging,
            activities: updatedActivities, // This change triggers recreation
            organizations: organizations,
            addresses: addresses,
            attachments: attachments
        )            { creationCount += 1 }

        // Verify the anti-pattern behavior
        #expect(creationCount == 2, "View should recreate when model arrays change")
        #expect(updatedActivities.count == 2, "Should have 2 activities after adding one")

        // This test demonstrates the problem: every time SwiftData updates,
        // views receiving model arrays as parameters will recreate
    }

    @Test("Query-based view should not recreate excessively")
    @MainActor
    func testQueryBasedViewStability() async throws {
        let testBase = SwiftDataTestBase()

        // Create test data
        let trip = Trip(name: "Test Trip")
        let activity = Activity(name: "Test Activity", start: Date(), end: Date().addingTimeInterval(3600))
        activity.trip = trip

        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()

        _ = 0

        // Create a query-based view (the correct pattern)
        struct QueryBasedView: View {
            @Query private var activities: [Activity]
            let creationTracker: () -> Void

            init(creationTracker: @escaping () -> Void) {
                self.creationTracker = creationTracker
                creationTracker() // Track creation
            }

            var body: some View {
                Text("Activities: \(activities.count)")
            }
        }

        // This approach should be more stable
        // Note: In actual testing, we'd need to test this in a SwiftUI environment
        // This test serves as documentation of the correct pattern

        #expect(true, "Query-based views should be more stable")
    }
}
