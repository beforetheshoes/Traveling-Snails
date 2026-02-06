//
//  TestConfiguration.swift
//  Traveling Snails Tests
//
//

import Dependencies
import Foundation
import SQLiteData
@testable import Traveling_Snails

/// Ensures all tests use isolated data containers to prevent contamination of real app data
@MainActor
protocol TestDataIsolation {
    var testDatabase: DatabaseQueue { get }
}

/// Default implementation providing isolated in-memory storage
@MainActor
extension TestDataIsolation {
    var testDatabase: DatabaseQueue {
        do {
            let database = try DatabaseQueue()
            var migrator = makeMigrator()
            try migrator.migrate(database)
            return database
        } catch {
            fatalError("Failed to create test database: \(error)")
        }
    }
}

/// Base class that all data tests should inherit from
@MainActor
class IsolatedTestBase: TestDataIsolation {
    /// Clean slate for each test
    func clearTestData() throws {
        try testDatabase.write { db in
            try EmbeddedFileAttachment.delete().execute(db)
            try Activity.delete().execute(db)
            try Lodging.delete().execute(db)
            try Transportation.delete().execute(db)
            try Trip.delete().execute(db)
            try Organization.delete().execute(db)
            try Address.delete().execute(db)
        }
    }

    /// Verify test isolation
    func verifyIsolation() throws {
        let trips = try testDatabase.read { db in
            try Trip.fetchAll(db)
        }
        let organizations = try testDatabase.read { db in
            try Organization.fetchAll(db)
        }

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
        #if DEBUG
        let isInTests = NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isInTests {
            // Test environment logging suppressed to prevent hanging

            // Set a flag that other parts of the app can check
            UserDefaults.standard.set(true, forKey: "isRunningTests")

            // Force disable any CloudKit-related initialization
            UserDefaults.standard.set(true, forKey: "disableCloudKit")

            // Debug log to verify this is being called
            print("🧪 TestGuard: Test environment detected and configured")
        }
        #endif
    }

    static var isRunningTests: Bool {
        UserDefaults.standard.bool(forKey: "isRunningTests")
    }
}
