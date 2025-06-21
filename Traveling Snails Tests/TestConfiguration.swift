//
//  TestConfiguration.swift
//  Traveling Snails Tests
//
//  Created by Ryan Williams on 6/19/25.
//

import Foundation
import SwiftData
@testable import Traveling_Snails

/// Ensures all tests use isolated data containers to prevent contamination of real app data
@MainActor
protocol TestDataIsolation {
    var testModelContainer: ModelContainer { get }
    var testModelContext: ModelContext { get }
}

/// Default implementation providing isolated in-memory storage
@MainActor
extension TestDataIsolation {
    var testModelContainer: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(
                for: Trip.self, 
                Lodging.self, 
                Transportation.self, 
                Activity.self, 
                Organization.self, 
                Address.self, 
                EmbeddedFileAttachment.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }
    
    var testModelContext: ModelContext {
        testModelContainer.mainContext
    }
}

/// Note: Removed TestIsolated macro - not needed for basic SwiftData testing
/// Tests should use ModelConfiguration(isStoredInMemoryOnly: true) for isolation

/// Base class that all SwiftData tests should inherit from
@MainActor
class IsolatedTestBase: TestDataIsolation {
    
    /// Clean slate for each test
    func clearTestData() throws {
        let trips = try testModelContext.fetch(FetchDescriptor<Trip>())
        let lodgings = try testModelContext.fetch(FetchDescriptor<Lodging>())
        let transportation = try testModelContext.fetch(FetchDescriptor<Transportation>())
        let activities = try testModelContext.fetch(FetchDescriptor<Activity>())
        let organizations = try testModelContext.fetch(FetchDescriptor<Organization>())
        let addresses = try testModelContext.fetch(FetchDescriptor<Address>())
        let attachments = try testModelContext.fetch(FetchDescriptor<EmbeddedFileAttachment>())
        
        trips.forEach { testModelContext.delete($0) }
        lodgings.forEach { testModelContext.delete($0) }
        transportation.forEach { testModelContext.delete($0) }
        activities.forEach { testModelContext.delete($0) }
        organizations.forEach { testModelContext.delete($0) }
        addresses.forEach { testModelContext.delete($0) }
        attachments.forEach { testModelContext.delete($0) }
        
        try testModelContext.save()
    }
    
    /// Verify test isolation
    func verifyIsolation() throws {
        let trips = try testModelContext.fetch(FetchDescriptor<Trip>())
        let organizations = try testModelContext.fetch(FetchDescriptor<Organization>())
        
        guard trips.isEmpty && organizations.isEmpty else {
            throw TestIsolationError.dataContamination
        }
    }
}

/// Errors related to test isolation
enum TestIsolationError: Error {
    case dataContamination
    case mainContainerAccess
    
    var localizedDescription: String {
        switch self {
        case .dataContamination:
            return "Test data found in isolated container - tests may be contaminating each other"
        case .mainContainerAccess:
            return "Test attempted to access main app container instead of isolated test container"
        }
    }
}

/// Guard to prevent accidental access to main app data in tests
@MainActor
struct TestGuard {
    static func ensureTestEnvironment() {
        // In test environment, we should never access the main app's ModelContainer
        // This guard helps catch tests that might accidentally access real data
        
        #if DEBUG
        let isInTests = NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        
        if isInTests {
            print("🧪 Test environment detected - ensuring data isolation")
            
            // Set a flag that other parts of the app can check
            UserDefaults.standard.set(true, forKey: "isRunningTests")
        }
        #endif
    }
    
    static var isRunningTests: Bool {
        UserDefaults.standard.bool(forKey: "isRunningTests")
    }
}
