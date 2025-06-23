//
//  NavigationRestorationIntegrationTests.swift
//  Traveling Snails Tests
//
//  Created by Ryan Williams on 6/22/25.
//

import Testing
import SwiftUI
import SwiftData
import Foundation
@testable import Traveling_Snails

@Suite("Navigation Restoration Integration Tests")
struct NavigationRestorationIntegrationTests {
    
    // MARK: - Test Environment Setup
    
    @MainActor
    private func makeTestEnvironment() -> (ModelContainer, Trip, Activity) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, Activity.self, Lodging.self, Transportation.self, configurations: config)
        
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
    
    // MARK: - ActivityNavigationReference Tests
    
    @Test("ActivityNavigationReference correctly stores and recreates DestinationType for Activity")
    @MainActor func testActivityNavigationReferenceForActivity() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data using SwiftDataTestBase pattern
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()
        
        // Create destination type
        let destinationType = DestinationType.activity(activity)
        
        // Create navigation reference
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Verify reference properties
        #expect(reference.activityId == activity.id)
        #expect(reference.activityType == .activity)
        #expect(reference.tripId == trip.id)
        
        // Test recreation
        let recreatedDestination = reference.createDestination(from: trip)
        #expect(recreatedDestination != nil)
        
        if case .activity(let recreatedActivity) = recreatedDestination {
            #expect(recreatedActivity.name == activity.name)
        } else {
            Issue.record("Failed to recreate activity destination")
        }
    }
    
    @Test("ActivityNavigationReference correctly stores and recreates DestinationType for Lodging")
    @MainActor func testActivityNavigationReferenceForLodging() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, Lodging.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        lodging.start = Date()
        lodging.end = Calendar.current.date(byAdding: .day, value: 1, to: lodging.start) ?? lodging.start
        
        container.mainContext.insert(trip)
        container.mainContext.insert(lodging)
        try! container.mainContext.save()
        
        // Create destination type
        let destinationType = DestinationType.lodging(lodging)
        
        // Create navigation reference
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Verify reference properties
        #expect(reference.activityId == lodging.id)
        #expect(reference.activityType == .lodging)
        #expect(reference.tripId == trip.id)
        
        // Test recreation
        let recreatedDestination = reference.createDestination(from: trip)
        #expect(recreatedDestination != nil)
        
        if case .lodging(let recreatedLodging) = recreatedDestination {
            #expect(recreatedLodging.name == lodging.name)
        } else {
            Issue.record("Failed to recreate lodging destination")
        }
    }
    
    @Test("ActivityNavigationReference correctly stores and recreates DestinationType for Transportation")
    @MainActor func testActivityNavigationReferenceForTransportation() async {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Trip.self, Transportation.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        let transportation = Transportation(name: "Test Flight", trip: trip)
        transportation.start = Date()
        transportation.end = Calendar.current.date(byAdding: .hour, value: 3, to: transportation.start) ?? transportation.start
        
        container.mainContext.insert(trip)
        container.mainContext.insert(transportation)
        try! container.mainContext.save()
        
        // Create destination type
        let destinationType = DestinationType.transportation(transportation)
        
        // Create navigation reference
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Verify reference properties
        #expect(reference.activityId == transportation.id)
        #expect(reference.activityType == .transportation)
        #expect(reference.tripId == trip.id)
        
        // Test recreation
        let recreatedDestination = reference.createDestination(from: trip)
        #expect(recreatedDestination != nil)
        
        if case .transportation(let recreatedTransportation) = recreatedDestination {
            #expect(recreatedTransportation.name == transportation.name)
        } else {
            Issue.record("Failed to recreate transportation destination")
        }
    }
    
    @Test("ActivityNavigationReference gracefully handles missing activity")
    @MainActor func testActivityNavigationReferenceHandlesMissingActivity() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data using SwiftDataTestBase pattern
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()
        
        // Create destination type
        let destinationType = DestinationType.activity(activity)
        
        // Create navigation reference
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Create a different trip without the activity
        let emptyTrip = Trip(name: "Empty Trip")
        testBase.modelContext.insert(emptyTrip)
        try testBase.modelContext.save()
        
        // Test recreation with wrong trip (should return nil)
        let recreatedDestination = reference.createDestination(from: emptyTrip)
        #expect(recreatedDestination == nil)
    }
    
    // MARK: - Codable Tests
    
    @Test("ActivityNavigationReference is properly Codable")
    @MainActor func testActivityNavigationReferenceCodeable() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data using SwiftDataTestBase pattern
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()
        
        // Create destination type and reference
        let destinationType = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try! encoder.encode(reference)
        #expect(data.count > 0)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedReference = try! decoder.decode(ActivityNavigationReference.self, from: data)
        
        // Verify decoded properties
        #expect(decodedReference.activityId == reference.activityId)
        #expect(decodedReference.activityType == reference.activityType)
        #expect(decodedReference.tripId == reference.tripId)
    }
    
    // MARK: - UserDefaults Integration Tests
    
    @Test("Navigation restoration works with UserDefaults")
    @MainActor func testNavigationRestorationWithUserDefaults() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data using SwiftDataTestBase pattern
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()
        
        // Create destination type and reference
        let destinationType = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        
        // Store in UserDefaults (simulate what IsolatedTripDetailView does)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(reference)
        let key = "activityNavigation_\(trip.id)"
        UserDefaults.standard.set(data, forKey: key)
        
        // Retrieve from UserDefaults
        let retrievedData = UserDefaults.standard.data(forKey: key)
        #expect(retrievedData != nil)
        
        // Decode and verify
        let decoder = JSONDecoder()
        let retrievedReference = try! decoder.decode(ActivityNavigationReference.self, from: retrievedData!)
        
        #expect(retrievedReference.activityId == activity.id)
        #expect(retrievedReference.activityType == .activity)
        #expect(retrievedReference.tripId == trip.id)
        
        // Test recreation from retrieved reference
        let recreatedDestination = retrievedReference.createDestination(from: trip)
        #expect(recreatedDestination != nil)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    @Test("Navigation state cleanup works correctly")
    @MainActor func testNavigationStateCleanup() async throws {
        let testBase = SwiftDataTestBase()
        
        // Create test data using SwiftDataTestBase pattern
        let trip = Trip(name: "Test Trip")
        testBase.modelContext.insert(trip)
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 2, to: startDate) ?? startDate
        let activity = Activity(
            name: "Test Activity",
            start: startDate,
            end: endDate,
            trip: trip
        )
        testBase.modelContext.insert(activity)
        try testBase.modelContext.save()
        
        // Store navigation state
        let destinationType = DestinationType.activity(activity)
        let reference = ActivityNavigationReference(from: destinationType, tripId: trip.id)
        let data = try! JSONEncoder().encode(reference)
        let key = "activityNavigation_\(trip.id)"
        
        UserDefaults.standard.set(data, forKey: key)
        #expect(UserDefaults.standard.data(forKey: key) != nil)
        
        // Simulate cleanup (what IsolatedTripDetailView does after restoration)
        UserDefaults.standard.removeObject(forKey: key)
        #expect(UserDefaults.standard.data(forKey: key) == nil)
    }
    
    // MARK: - DestinationType Tests
    
    @Test("DestinationType activityId property works correctly")
    @MainActor func testDestinationTypeActivityId() async {
        let (container, trip, activity) = makeTestEnvironment()
        
        let activityDestination = DestinationType.activity(activity)
        #expect(activityDestination.activityId == activity.id)
        
        // Test with lodging
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        container.mainContext.insert(lodging)
        try! container.mainContext.save()
        
        let lodgingDestination = DestinationType.lodging(lodging)
        #expect(lodgingDestination.activityId == lodging.id)
        
        // Test with transportation
        let transportation = Transportation(name: "Test Flight", trip: trip)
        container.mainContext.insert(transportation)
        try! container.mainContext.save()
        
        let transportationDestination = DestinationType.transportation(transportation)
        #expect(transportationDestination.activityId == transportation.id)
    }
    
    @Test("DestinationType equality works correctly")
    @MainActor func testDestinationTypeEquality() async {
        let (container, trip, activity) = makeTestEnvironment()
        
        let destination1 = DestinationType.activity(activity)
        let destination2 = DestinationType.activity(activity)
        
        #expect(destination1 == destination2)
        
        // Test inequality with different activities
        let anotherActivity = Activity(
            name: "Another Activity",
            trip: trip
        )
        container.mainContext.insert(anotherActivity)
        try! container.mainContext.save()
        
        let destination3 = DestinationType.activity(anotherActivity)
        
        #expect(destination1 != destination3)
    }
    
    @Test("DestinationType hashing works correctly")
    @MainActor func testDestinationTypeHashing() async {
        let (container, trip, activity) = makeTestEnvironment()
        
        let destination1 = DestinationType.activity(activity)
        let destination2 = DestinationType.activity(activity)
        
        // Same destinations should have same hash
        #expect(destination1.hashValue == destination2.hashValue)
        
        // Different activity types should have different hashes
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        container.mainContext.insert(lodging)
        try! container.mainContext.save()
        
        let lodgingDestination = DestinationType.lodging(lodging)
        
        #expect(destination1.hashValue != lodgingDestination.hashValue)
    }
}