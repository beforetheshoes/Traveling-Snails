//
//  SimpleNavigationRestorationTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Simple Navigation Restoration Tests")
struct SimpleNavigationRestorationTests {
    // MARK: - ActivityNavigationReference Tests (Core Functionality)

    @Test("ActivityNavigationReference Codable works with minimal setup", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testActivityNavigationReferenceCodeable() async throws {
        // Create minimal SwiftData setup to get real objects
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, configurations: config)

        let activity = Activity(name: "Test Activity", trip: nil)
        container.mainContext.insert(activity)
        try container.mainContext.save()

        let tripId = UUID()
        let destination = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destination, tripId: tripId)

        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(reference)
        #expect(!data.isEmpty)

        // Test decoding
        let decoder = JSONDecoder()
        let decodedReference = try decoder.decode(ActivityNavigationReference.self, from: data)

        // Verify decoded properties
        #expect(decodedReference.activityId == activity.id)
        #expect(decodedReference.activityType == .activity)
        #expect(decodedReference.tripId == tripId)
    }

    @Test("ActivityNavigationReference handles all activity types", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testActivityNavigationReferenceTypes() async throws {
        // Since we can only create ActivityNavigationReference from DestinationType,
        // we'll test the core types that can be created
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, Lodging.self, Transportation.self, configurations: config)

        let activity = Activity(name: "Test Activity", trip: nil)
        let lodging = Lodging(name: "Test Hotel", trip: nil)
        let transportation = Transportation(name: "Test Flight", trip: nil)

        container.mainContext.insert(activity)
        container.mainContext.insert(lodging)
        container.mainContext.insert(transportation)
        try container.mainContext.save()

        let tripId = UUID()

        // Test activity type
        let activityDestination = DestinationType.activity(activity)
        let activityRef = ActivityNavigationReference(from: activityDestination, tripId: tripId)
        let activityData = try JSONEncoder().encode(activityRef)
        let decodedActivityRef = try JSONDecoder().decode(ActivityNavigationReference.self, from: activityData)
        #expect(decodedActivityRef.activityType == .activity)

        // Test lodging type
        let lodgingDestination = DestinationType.lodging(lodging)
        let lodgingRef = ActivityNavigationReference(from: lodgingDestination, tripId: tripId)
        let lodgingData = try JSONEncoder().encode(lodgingRef)
        let decodedLodgingRef = try JSONDecoder().decode(ActivityNavigationReference.self, from: lodgingData)
        #expect(decodedLodgingRef.activityType == .lodging)

        // Test transportation type
        let transportationDestination = DestinationType.transportation(transportation)
        let transportationRef = ActivityNavigationReference(from: transportationDestination, tripId: tripId)
        let transportationData = try JSONEncoder().encode(transportationRef)
        let decodedTransportationRef = try JSONDecoder().decode(ActivityNavigationReference.self, from: transportationData)
        #expect(decodedTransportationRef.activityType == .transportation)
    }

    @Test("UserDefaults navigation state storage works", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testUserDefaultsNavigationStorage() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, configurations: config)

        let activity = Activity(name: "Test Activity", trip: nil)
        container.mainContext.insert(activity)
        try container.mainContext.save()

        let tripId = UUID()
        let key = "test_activityNavigation_\(tripId)"

        // Clean up any existing data
        UserDefaults.standard.removeObject(forKey: key)

        // Create and store reference
        let destination = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destination, tripId: tripId)

        let data = try JSONEncoder().encode(reference)
        UserDefaults.standard.set(data, forKey: key)

        // Verify storage
        let retrievedData = UserDefaults.standard.data(forKey: key)
        #expect(retrievedData != nil)

        // Verify decoding
        let retrieved = try JSONDecoder().decode(ActivityNavigationReference.self, from: retrievedData!)
        #expect(retrieved.activityId == activity.id)
        #expect(retrieved.activityType == .activity)
        #expect(retrieved.tripId == tripId)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
        #expect(UserDefaults.standard.data(forKey: key) == nil)
    }

    // MARK: - DestinationType Core Tests

    @Test("DestinationType activityId computed property works", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testDestinationTypeActivityId() async throws {
        // Create a simple in-memory SwiftData setup
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, configurations: config)

        let activity = Activity(name: "Test Activity", trip: nil)
        container.mainContext.insert(activity)
        try container.mainContext.save()

        let destination = DestinationType.activity(activity)
        #expect(destination.activityId == activity.id)
    }

    @Test("Navigation restoration implementation matches expected pattern", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .regression, .mainActor))
    @MainActor func testNavigationRestorationPattern() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, configurations: config)

        let activity = Activity(name: "Test Activity", trip: nil)
        container.mainContext.insert(activity)
        try container.mainContext.save()

        let tripId = UUID()

        // Step 1: Create reference (simulating saveActivityNavigationState)
        let destination = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destination, tripId: tripId)

        // Step 2: Store in UserDefaults
        let data = try JSONEncoder().encode(reference)
        let key = "activityNavigation_\(tripId)"
        UserDefaults.standard.set(data, forKey: key)

        // Step 3: Simulate retrieval (handleNavigationRestoration)
        let retrievedData = UserDefaults.standard.data(forKey: key)
        #expect(retrievedData != nil)

        let decodedReference = try JSONDecoder().decode(ActivityNavigationReference.self, from: retrievedData!)
        #expect(decodedReference.activityId == activity.id)

        // Step 4: Cleanup after restoration
        UserDefaults.standard.removeObject(forKey: key)
        #expect(UserDefaults.standard.data(forKey: key) == nil)
    }

    @Test("Multiple trip navigation states can coexist", .tags(.ui, .medium, .parallel, .swiftui, .navigation, .activity, .validation, .mainActor))
    @MainActor func testMultipleTripNavigationStates() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Activity.self, Lodging.self, configurations: config)

        let activity1 = Activity(name: "Test Activity 1", trip: nil)
        let lodging2 = Lodging(name: "Test Hotel 2", trip: nil)

        container.mainContext.insert(activity1)
        container.mainContext.insert(lodging2)
        try container.mainContext.save()

        let trip1Id = UUID()
        let trip2Id = UUID()

        // Store navigation state for trip 1
        let destination1 = DestinationType.activity(activity1)
        let ref1 = ActivityNavigationReference(from: destination1, tripId: trip1Id)
        let data1 = try JSONEncoder().encode(ref1)
        UserDefaults.standard.set(data1, forKey: "activityNavigation_\(trip1Id)")

        // Store navigation state for trip 2
        let destination2 = DestinationType.lodging(lodging2)
        let ref2 = ActivityNavigationReference(from: destination2, tripId: trip2Id)
        let data2 = try JSONEncoder().encode(ref2)
        UserDefaults.standard.set(data2, forKey: "activityNavigation_\(trip2Id)")

        // Verify both exist
        #expect(UserDefaults.standard.data(forKey: "activityNavigation_\(trip1Id)") != nil)
        #expect(UserDefaults.standard.data(forKey: "activityNavigation_\(trip2Id)") != nil)

        // Verify each can be decoded correctly
        let retrieved1Data = UserDefaults.standard.data(forKey: "activityNavigation_\(trip1Id)")!
        let retrieved1 = try JSONDecoder().decode(ActivityNavigationReference.self, from: retrieved1Data)
        #expect(retrieved1.activityId == activity1.id)
        #expect(retrieved1.activityType == .activity)

        let retrieved2Data = UserDefaults.standard.data(forKey: "activityNavigation_\(trip2Id)")!
        let retrieved2 = try JSONDecoder().decode(ActivityNavigationReference.self, from: retrieved2Data)
        #expect(retrieved2.activityId == lodging2.id)
        #expect(retrieved2.activityType == .lodging)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "activityNavigation_\(trip1Id)")
        UserDefaults.standard.removeObject(forKey: "activityNavigation_\(trip2Id)")
    }
}
