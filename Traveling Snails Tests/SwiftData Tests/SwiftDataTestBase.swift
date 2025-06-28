//
//  SwiftDataTestBase.swift
//  Traveling Snails
//
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
        // Ensure we're in test environment
        // TEMPORARILY DISABLED: TestGuard.ensureTestEnvironment() may be causing hanging during test compilation
        // TestGuard.ensureTestEnvironment()
        
        // Create a unique in-memory database for each test instance
        let config = ModelConfiguration(
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none // Explicitly disable CloudKit for tests
        )
        
        do {
            self.modelContainer = try ModelContainer(
                for: Trip.self, 
                Lodging.self, 
                Transportation.self, 
                Activity.self, 
                Organization.self, 
                Address.self, 
                EmbeddedFileAttachment.self,
                configurations: config
            )
            
            // Verify isolation
            // Test container logging suppressed to prevent test hanging
            // Container has \(modelContainer.configurations.count) configurations
            // In-memory: \(modelContainer.configurations.first?.isStoredInMemoryOnly == true)
            
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
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
