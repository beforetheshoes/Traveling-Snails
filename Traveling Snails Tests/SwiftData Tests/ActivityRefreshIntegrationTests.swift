//
//  ActivityRefreshIntegrationTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

/// Tests for Issue #19: New trip activity doesn't show up on save - requires navigation refresh
@MainActor
@Suite("Activity Refresh Integration Tests")
struct ActivityRefreshIntegrationTests {
    @Test("Activity save should immediately update activity lists", .tags(.swiftdata, .medium, .parallel, .integration, .trip, .activity, .validation, .critical))
    func testActivitySaveImmediatelyUpdatesLists() throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()

        // Create a trip
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        // Verify trip starts with no activities
        #expect(trip.activity.isEmpty, "Trip should start with no activities")
        #expect(trip.totalActivities == 0, "Trip should have 0 total activities")

        // Create and save activity using ActivitySaveService (mimicking real save flow)
        let activitySaver = ActivitySaverFactory.createSaver(for: .activity)
        let template = activitySaver.createTemplate(in: trip)
        var editData = TripActivityEditData(from: template)
        editData.name = "Test Activity"
        editData.organization = Organization.ensureUniqueNoneOrganization(in: testBase.modelContext)

        try activitySaver.save(
            editData: editData,
            attachments: [],
            trip: trip,
            in: testBase.modelContext
        )

        // THIS IS WHERE THE BUG MANIFESTS:
        // After save, accessing trip.activity directly doesn't reflect the new activity
        // because SwiftData relationships aren't immediately refreshed

        // This should pass but currently fails due to relationship access anti-pattern
        #expect(trip.activity.count == 1, "Activity should appear immediately after save")
        #expect(trip.totalActivities == 1, "Trip should show 1 total activity")
        #expect(trip.activity.first?.name == "Test Activity", "Saved activity should be accessible")

        // Verify activity was actually saved to database
        let allActivities = try testBase.modelContext.fetch(FetchDescriptor<Activity>())
        #expect(allActivities.count == 1, "Activity should be saved to database")
        #expect(allActivities.first?.name == "Test Activity", "Database should have correct activity")
    }

    @Test("Multiple activity types should all appear immediately after save", .tags(.swiftdata, .medium, .parallel, .integration, .trip, .activity, .validation, .critical))
    func testMultipleActivityTypesAppearImmediately() throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()

        // Create a trip
        let trip = Trip(name: "Multi Activity Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        let org = Organization.ensureUniqueNoneOrganization(in: testBase.modelContext)

        // Save Activity
        let activitySaver = ActivitySaverFactory.createSaver(for: .activity)
        let activityTemplate = activitySaver.createTemplate(in: trip)
        var activityEditData = TripActivityEditData(from: activityTemplate)
        activityEditData.name = "Test Activity"
        activityEditData.organization = org
        try activitySaver.save(editData: activityEditData, attachments: [], trip: trip, in: testBase.modelContext)

        // Save Lodging
        let lodgingSaver = ActivitySaverFactory.createSaver(for: .lodging)
        let lodgingTemplate = lodgingSaver.createTemplate(in: trip)
        var lodgingEditData = TripActivityEditData(from: lodgingTemplate)
        lodgingEditData.name = "Test Hotel"
        lodgingEditData.organization = org
        try lodgingSaver.save(editData: lodgingEditData, attachments: [], trip: trip, in: testBase.modelContext)

        // Save Transportation
        let transportationSaver = ActivitySaverFactory.createSaver(for: .transportation)
        let transportationTemplate = transportationSaver.createTemplate(in: trip)
        var transportationEditData = TripActivityEditData(from: transportationTemplate)
        transportationEditData.name = "Test Flight"
        transportationEditData.organization = org
        transportationEditData.transportationType = TransportationType.plane
        try transportationSaver.save(editData: transportationEditData, attachments: [], trip: trip, in: testBase.modelContext)

        // All activities should appear immediately in relationship access
        // This currently fails due to the SwiftData anti-pattern
        #expect(trip.activity.count == 1, "Activity should appear immediately")
        #expect(trip.lodging.count == 1, "Lodging should appear immediately")
        #expect(trip.transportation.count == 1, "Transportation should appear immediately")
        #expect(trip.totalActivities == 3, "All 3 activities should be counted")

        // Verify all were actually saved to database
        let allActivities = try testBase.modelContext.fetch(FetchDescriptor<Activity>())
        let allLodging = try testBase.modelContext.fetch(FetchDescriptor<Lodging>())
        let allTransportation = try testBase.modelContext.fetch(FetchDescriptor<Transportation>())

        #expect(allActivities.count == 1, "Activity should be in database")
        #expect(allLodging.count == 1, "Lodging should be in database")
        #expect(allTransportation.count == 1, "Transportation should be in database")
    }

    @Test("Trip activity wrapper aggregation should work immediately after save", .tags(.swiftdata, .medium, .parallel, .integration, .trip, .activity, .dataModel, .validation, .critical))
    func testTripActivityWrapperAggregation() throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()

        // Create a trip
        let trip = Trip(name: "Wrapper Test Trip")
        testBase.modelContext.insert(trip)
        try testBase.modelContext.save()

        let org = Organization.ensureUniqueNoneOrganization(in: testBase.modelContext)

        // Save an activity
        let activitySaver = ActivitySaverFactory.createSaver(for: .activity)
        let template = activitySaver.createTemplate(in: trip)
        var editData = TripActivityEditData(from: template)
        editData.name = "Test Activity"
        editData.organization = org
        try activitySaver.save(editData: editData, attachments: [], trip: trip, in: testBase.modelContext)

        // Test the activity wrapper aggregation (used in TripDetailView.allActivities)
        // This mimics the current broken pattern in TripDetailView.swift lines 29-36
        let lodgingActivities = (trip.lodging).map { ActivityWrapper($0) }
        let transportationActivities = (trip.transportation).map { ActivityWrapper($0) }
        let activityActivities = (trip.activity).map { ActivityWrapper($0) }

        let allActivities = (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }

        // This should pass but currently fails due to relationship access issue
        #expect(allActivities.count == 1, "Activity wrapper aggregation should find 1 activity")
        #expect(allActivities.first?.tripActivity.name == "Test Activity", "Activity wrapper should have correct activity")
    }
}
