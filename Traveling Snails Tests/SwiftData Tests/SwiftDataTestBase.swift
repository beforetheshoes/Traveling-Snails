//
//  SwiftDataTestBase.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import SwiftData
import Testing
@testable import Traveling_Snails

/// Base class for SwiftData tests that provides isolated in-memory database for each test
@MainActor
class SwiftDataTestBase {
    
    // Create a fresh container for each test instance
    let modelContainer: ModelContainer
    var modelContext: ModelContext {
        modelContainer.mainContext
    }
    
    init() {
        // Create a unique in-memory database for each test instance
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            self.modelContainer = try ModelContainer(for: Trip.self, Lodging.self, Transportation.self, Activity.self, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Helper method to clear all data from the test database
    func clearDatabase() throws {
        let trips = try modelContext.fetch(FetchDescriptor<Trip>())
        let lodgings = try modelContext.fetch(FetchDescriptor<Lodging>())
        let transportation = try modelContext.fetch(FetchDescriptor<Transportation>())
        let activities = try modelContext.fetch(FetchDescriptor<Activity>())
        
        trips.forEach { modelContext.delete($0) }
        lodgings.forEach { modelContext.delete($0) }
        transportation.forEach { modelContext.delete($0) }
        activities.forEach { modelContext.delete($0) }
        
        try modelContext.save()
    }
    
    /// Helper method to verify database is empty
    func verifyDatabaseEmpty() throws {
        let trips = try modelContext.fetch(FetchDescriptor<Trip>())
        let lodgings = try modelContext.fetch(FetchDescriptor<Lodging>())
        let transportation = try modelContext.fetch(FetchDescriptor<Transportation>())
        let activities = try modelContext.fetch(FetchDescriptor<Activity>())
        
        #expect(trips.isEmpty, "Trips should be empty at test start")
        #expect(lodgings.isEmpty, "Lodgings should be empty at test start")
        #expect(transportation.isEmpty, "Transportation should be empty at test start")
        #expect(activities.isEmpty, "Activities should be empty at test start")
    }
}
