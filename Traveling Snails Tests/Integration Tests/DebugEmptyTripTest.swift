//
//  DebugEmptyTripTest.swift
//  Traveling Snails
//
//

import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Debug Empty Trip Issue")
struct DebugEmptyTripIssue {
    @Test("Investigate empty trip activity count")
    func investigateEmptyTripActivityCount() {
        let emptyTrip = Trip(name: "")

        print("DEBUG: Empty trip created")
        print("DEBUG: emptyTrip.name = '\(emptyTrip.name)'")
        print("DEBUG: emptyTrip.lodging = \(String(describing: emptyTrip.lodging))")
        print("DEBUG: emptyTrip.transportation = \(String(describing: emptyTrip.transportation))")
        print("DEBUG: emptyTrip.activity = \(String(describing: emptyTrip.activity))")
        print("DEBUG: emptyTrip.totalActivities = \(emptyTrip.totalActivities)")
        print("DEBUG: emptyTrip.totalCost = \(emptyTrip.totalCost)")

        // Let's check each component
        let lodgingCount = emptyTrip.lodging.count
        let transportationCount = emptyTrip.transportation.count
        let activityCount = emptyTrip.activity.count

        print("DEBUG: lodging count = \(lodgingCount)")
        print("DEBUG: transportation count = \(transportationCount)")
        print("DEBUG: activity count = \(activityCount)")
        print("DEBUG: manual total = \(lodgingCount + transportationCount + activityCount)")

        // Check if any arrays are non-nil but have unexpected content
        print("DEBUG: lodging array exists with \(emptyTrip.lodging.count) items")
        for (index, item) in emptyTrip.lodging.enumerated() {
            print("DEBUG: lodging[\(index)] = \(item.name)")
        }

        print("DEBUG: transportation array exists with \(emptyTrip.transportation.count) items")
        for (index, item) in emptyTrip.transportation.enumerated() {
            print("DEBUG: transportation[\(index)] = \(item.name)")
        }

        print("DEBUG: activity array exists with \(emptyTrip.activity.count) items")
        for (index, item) in emptyTrip.activity.enumerated() {
            print("DEBUG: activity[\(index)] = \(item.name)")
        }

        // This test will fail until we fix the issue, but it will give us debug info
        #expect(emptyTrip.totalActivities == 0, "Expected 0 activities but got \(emptyTrip.totalActivities)")
    }

    @Test("Compare different trip creation methods")
    func compareDifferentTripCreationMethods() {
        // Method 1: Empty name
        let trip1 = Trip(name: "")
        print("DEBUG: Trip with empty name - totalActivities = \(trip1.totalActivities)")

        // Method 2: Default initializer
        let trip2 = Trip()
        print("DEBUG: Trip with default init - totalActivities = \(trip2.totalActivities)")

        // Method 3: Normal name
        let trip3 = Trip(name: "Normal Trip")
        print("DEBUG: Trip with normal name - totalActivities = \(trip3.totalActivities)")

        // Method 4: With dates
        let trip4 = Trip(name: "Trip with dates", startDate: Date(), endDate: Date())
        print("DEBUG: Trip with dates - totalActivities = \(trip4.totalActivities)")

        // Check if the issue is specific to empty name or general
        let allCounts = [trip1.totalActivities, trip2.totalActivities, trip3.totalActivities, trip4.totalActivities]
        print("DEBUG: All trip activity counts = \(allCounts)")
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

        print("DEBUG: Created empty activity")
        print("DEBUG: emptyActivity.name = '\(emptyActivity.name)'")
        print("DEBUG: emptyActivity.trip?.name = '\(emptyActivity.trip?.name ?? "nil")'")
        print("DEBUG: emptyActivity.organization?.name = '\(emptyActivity.organization?.name ?? "nil")'")

        // Check if creating the activity automatically adds it to the trip
        print("DEBUG: After creating activity, emptyTrip.totalActivities = \(emptyTrip.totalActivities)")
        print("DEBUG: emptyTrip.activity?.count = \(emptyTrip.activity.count)")

        // The issue might be that creating an Activity automatically adds it to the trip's activity array
    }
}
