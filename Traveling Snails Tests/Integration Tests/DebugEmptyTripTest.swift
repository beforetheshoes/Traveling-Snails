//
//  DebugEmptyTripTest.swift
//  Traveling Snails
//
//

import Foundation
import Testing
import os

@testable import Traveling_Snails

@Suite("Debug Empty Trip Issue")
struct DebugEmptyTripIssue {
    @Test("Investigate empty trip activity count")
    func investigateEmptyTripActivityCount() {
        let emptyTrip = Trip(name: "")

        #if DEBUG
        Logger().debug("Empty trip created with ID: \(emptyTrip.id, privacy: .public)")
        Logger().debug("Trip lodging count: \(emptyTrip.lodging.count, privacy: .public)")
        Logger().debug("Trip transportation count: \(emptyTrip.transportation.count, privacy: .public)")
        Logger().debug("Trip activity count: \(emptyTrip.activity.count, privacy: .public)")
        Logger().debug("Trip totalActivities: \(emptyTrip.totalActivities, privacy: .public)")
        Logger().debug("Trip totalCost: \(emptyTrip.totalCost, privacy: .public)")
        #endif

        // Let's check each component
        let lodgingCount = emptyTrip.lodging.count
        let transportationCount = emptyTrip.transportation.count
        let activityCount = emptyTrip.activity.count

        #if DEBUG
        Logger().debug("Lodging count: \(lodgingCount, privacy: .public)")
        Logger().debug("Transportation count: \(transportationCount, privacy: .public)")
        Logger().debug("Activity count: \(activityCount, privacy: .public)")
        Logger().debug("Manual total: \(lodgingCount + transportationCount + activityCount, privacy: .public)")
        #endif

        // Check if any arrays are non-nil but have unexpected content
        #if DEBUG
        Logger().debug("Lodging array exists with \(emptyTrip.lodging.count, privacy: .public) items")
        for (index, item) in emptyTrip.lodging.enumerated() {
            Logger().debug("Lodging[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        #if DEBUG
        Logger().debug("Transportation array exists with \(emptyTrip.transportation.count, privacy: .public) items")
        for (index, item) in emptyTrip.transportation.enumerated() {
            Logger().debug("Transportation[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        #if DEBUG
        Logger().debug("Activity array exists with \(emptyTrip.activity.count, privacy: .public) items")
        for (index, item) in emptyTrip.activity.enumerated() {
            Logger().debug("Activity[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        // This test will fail until we fix the issue, but it will give us debug info
        #expect(emptyTrip.totalActivities == 0, "Expected 0 activities but got \(emptyTrip.totalActivities)")
    }

    @Test("Compare different trip creation methods")
    func compareDifferentTripCreationMethods() {
        // Method 1: Empty name
        let trip1 = Trip(name: "")
        #if DEBUG
        Logger().debug("Trip1 (empty name) ID: \(trip1.id, privacy: .public) - totalActivities: \(trip1.totalActivities, privacy: .public)")
        #endif

        // Method 2: Default initializer
        let trip2 = Trip()
        #if DEBUG
        Logger().debug("Trip2 (default init) ID: \(trip2.id, privacy: .public) - totalActivities: \(trip2.totalActivities, privacy: .public)")
        #endif

        // Method 3: Normal name
        let trip3 = Trip(name: "Normal Trip")
        #if DEBUG
        Logger().debug("Trip3 (normal name) ID: \(trip3.id, privacy: .public) - totalActivities: \(trip3.totalActivities, privacy: .public)")
        #endif

        // Method 4: With dates
        let trip4 = Trip(name: "Trip with dates", startDate: Date(), endDate: Date())
        #if DEBUG
        Logger().debug("Trip4 (with dates) ID: \(trip4.id, privacy: .public) - totalActivities: \(trip4.totalActivities, privacy: .public)")
        #endif

        // Check if the issue is specific to empty name or general
        let allCounts = [trip1.totalActivities, trip2.totalActivities, trip3.totalActivities, trip4.totalActivities]
        #if DEBUG
        Logger().debug("All trip activity counts: \(allCounts, privacy: .public)")
        #endif
    }

    @Test("Investigate empty activity creation")
    func investigateEmptyActivityCreation() {
        let emptyTrip = Trip(name: "")
        let emptyOrg = Organization(name: "")

        let emptyActivity = Activity(
            name: "",
            start: Date(),
            end: Date(),
            trip: emptyTrip,
            organization: emptyOrg
        )

        #if DEBUG
        Logger().debug("Created empty activity with ID: \(emptyActivity.id, privacy: .public)")
        Logger().debug("Activity trip ID: \(emptyActivity.trip?.id.uuidString ?? "nil", privacy: .public)")
        Logger().debug("Activity organization ID: \(emptyActivity.organization?.id.uuidString ?? "nil", privacy: .public)")

        // Check if creating the activity automatically adds it to the trip
        Logger().debug("After creating activity, emptyTrip.totalActivities: \(emptyTrip.totalActivities, privacy: .public)")
        Logger().debug("EmptyTrip.activity count: \(emptyTrip.activity.count, privacy: .public)")
        #endif

        // The issue might be that creating an Activity automatically adds it to the trip's activity array
    }
}
