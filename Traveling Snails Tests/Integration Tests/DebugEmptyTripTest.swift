//
//  DebugEmptyTripTest.swift
//  Traveling Snails
//
//

import Foundation
import os
import Testing
import SwiftData

@testable import Traveling_Snails

@Suite("Debug Empty Trip Issue")
struct DebugEmptyTripIssue {
    @Test("Investigate empty trip activity count", .tags(.integration, .fast, .parallel, .trip, .swiftdata, .regression, .validation))
    func investigateEmptyTripActivityCount() throws {
        // Use in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, Activity.self, Lodging.self, Transportation.self, Organization.self, EmbeddedFileAttachment.self, configurations: config)
        let context = ModelContext(container)
        
        let emptyTrip = Trip(name: "")
        context.insert(emptyTrip)

        #if DEBUG
        Logger.secure(category: .debug).debug("Empty trip created with ID: \(emptyTrip.id, privacy: .public)")
        Logger.secure(category: .debug).debug("Trip lodging count: \(emptyTrip.lodging.count, privacy: .public)")
        Logger.secure(category: .debug).debug("Trip transportation count: \(emptyTrip.transportation.count, privacy: .public)")
        Logger.secure(category: .debug).debug("Trip activity count: \(emptyTrip.activity.count, privacy: .public)")
        Logger.secure(category: .debug).debug("Trip totalActivities: \(emptyTrip.totalActivities, privacy: .public)")
        Logger.secure(category: .debug).debug("Trip totalCost: \(emptyTrip.totalCost, privacy: .public)")
        #endif

        // Let's check each component
        let lodgingCount = emptyTrip.lodging.count
        let transportationCount = emptyTrip.transportation.count
        let activityCount = emptyTrip.activity.count

        #if DEBUG
        Logger.secure(category: .debug).debug("Lodging count: \(lodgingCount, privacy: .public)")
        Logger.secure(category: .debug).debug("Transportation count: \(transportationCount, privacy: .public)")
        Logger.secure(category: .debug).debug("Activity count: \(activityCount, privacy: .public)")
        Logger.secure(category: .debug).debug("Manual total: \(lodgingCount + transportationCount + activityCount, privacy: .public)")
        #endif

        // Check if any arrays are non-nil but have unexpected content
        #if DEBUG
        Logger.secure(category: .debug).debug("Lodging array exists with \(emptyTrip.lodging.count, privacy: .public) items")
        for (index, item) in emptyTrip.lodging.enumerated() {
            Logger.secure(category: .debug).debug("Lodging[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        #if DEBUG
        Logger.secure(category: .debug).debug("Transportation array exists with \(emptyTrip.transportation.count, privacy: .public) items")
        for (index, item) in emptyTrip.transportation.enumerated() {
            Logger.secure(category: .debug).debug("Transportation[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        #if DEBUG
        Logger.secure(category: .debug).debug("Activity array exists with \(emptyTrip.activity.count, privacy: .public) items")
        for (index, item) in emptyTrip.activity.enumerated() {
            Logger.secure(category: .debug).debug("Activity[\(index, privacy: .public)] ID: \(item.id, privacy: .public)")
        }
        #endif

        // This test will fail until we fix the issue, but it will give us debug info
        #expect(emptyTrip.totalActivities == 0, "Expected 0 activities but got \(emptyTrip.totalActivities)")
    }

    @Test("Compare different trip creation methods", .tags(.integration, .fast, .parallel, .trip, .swiftdata, .regression, .validation))
    func compareDifferentTripCreationMethods() throws {
        // Use in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, Activity.self, Lodging.self, Transportation.self, Organization.self, EmbeddedFileAttachment.self, configurations: config)
        let context = ModelContext(container)
        
        // Method 1: Empty name
        let trip1 = Trip(name: "")
        context.insert(trip1)
        #if DEBUG
        Logger.secure(category: .debug).debug("Trip1 (empty name) ID: \(trip1.id, privacy: .public) - totalActivities: \(trip1.totalActivities, privacy: .public)")
        #endif

        // Method 2: With name
        let trip2 = Trip(name: "Normal Trip")
        context.insert(trip2)
        #if DEBUG
        Logger.secure(category: .debug).debug("Trip2 (normal name) ID: \(trip2.id, privacy: .public) - totalActivities: \(trip2.totalActivities, privacy: .public)")
        #endif

        // Method 3: With dates
        let trip3 = Trip(name: "Trip with dates", startDate: Date(), endDate: Date())
        context.insert(trip3)
        #if DEBUG
        Logger.secure(category: .debug).debug("Trip3 (with dates) ID: \(trip3.id, privacy: .public) - totalActivities: \(trip3.totalActivities, privacy: .public)")
        #endif

        // Check if the issue is specific to empty name or general
        let allCounts = [trip1.totalActivities, trip2.totalActivities, trip3.totalActivities]
        #if DEBUG
        Logger.secure(category: .debug).debug("All trip activity counts: \(allCounts, privacy: .public)")
        #endif
    }

    @Test("Investigate empty activity creation", .tags(.integration, .fast, .parallel, .activity, .swiftdata, .regression, .validation))
    func investigateEmptyActivityCreation() throws {
        // Use in-memory container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, Activity.self, Lodging.self, Transportation.self, Organization.self, EmbeddedFileAttachment.self, configurations: config)
        let context = ModelContext(container)
        
        let emptyTrip = Trip(name: "")
        let emptyOrg = Organization(name: "")
        context.insert(emptyTrip)
        context.insert(emptyOrg)

        let emptyActivity = Activity(
            name: "",
            start: Date(),
            end: Date(),
            trip: emptyTrip,
            organization: emptyOrg
        )
        context.insert(emptyActivity)

        #if DEBUG
        Logger.secure(category: .debug).debug("Created empty activity with ID: \(emptyActivity.id, privacy: .public)")
        Logger.secure(category: .debug).debug("Activity trip ID: \(emptyActivity.trip?.id.uuidString ?? "nil", privacy: .public)")
        Logger.secure(category: .debug).debug("Activity organization ID: \(emptyActivity.organization?.id.uuidString ?? "nil", privacy: .public)")

        // Check if creating the activity automatically adds it to the trip
        Logger.secure(category: .debug).debug("After creating activity, emptyTrip.totalActivities: \(emptyTrip.totalActivities, privacy: .public)")
        Logger.secure(category: .debug).debug("EmptyTrip.activity count: \(emptyTrip.activity.count, privacy: .public)")
        #endif

        // The issue might be that creating an Activity automatically adds it to the trip's activity array
    }
}
