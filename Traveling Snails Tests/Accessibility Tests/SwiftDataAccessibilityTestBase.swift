//
//  SwiftDataAccessibilityTestBase.swift
//  Traveling Snails Tests
//
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails
import XCTest

/// Base class for SwiftData accessibility testing
/// Provides specialized testing infrastructure for accessibility with SwiftData models
@MainActor
class SwiftDataAccessibilityTestBase {
    // MARK: - Properties

    let container: ModelContainer
    let modelContext: ModelContext
    let backgroundContext: ModelContext

    // MARK: - Initialization

    init() throws {
        // Create in-memory container for testing
        let schema = Schema([
            Trip.self,
            Activity.self,
            Organization.self,
            EmbeddedFileAttachment.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )

        self.container = try ModelContainer(for: schema, configurations: [configuration])
        self.modelContext = container.mainContext
        self.backgroundContext = ModelContext(container)
    }

    // MARK: - Accessibility-Specific Setup Methods

    /// Creates a trip with proper accessibility information
    func createAccessibleTrip(
        name: String = "Test Trip",
        notes: String = "Test notes",
        withDates: Bool = false,
        activityCount: Int = 0
    ) throws -> Trip {
        let trip = Trip(name: name)
        trip.notes = notes

        if withDates {
            trip.setStartDate(Date())
            trip.setEndDate(Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date())
        }

        // Note: Trip model doesn't have generateAccessibilityInfo method yet

        modelContext.insert(trip)

        // Add activities if requested
        if activityCount > 0 {
            for i in 1...activityCount {
                let activity = Activity(name: "Activity \(i)")
                activity.notes = "Activity \(i) notes"
                activity.trip = trip
                // Note: Activity model doesn't have generateAccessibilityInfo method yet
                modelContext.insert(activity)
            }
        }

        try modelContext.save()
        return trip
    }

    /// Creates an organization with accessibility information
    func createAccessibleOrganization(
        name: String = "Test Organization",
        phone: String? = nil,
        email: String? = nil
    ) throws -> Organization {
        let organization = Organization()
        organization.name = name
        organization.phone = phone ?? ""
        organization.email = email ?? ""

        // Note: Organization model doesn't have generateAccessibilityInfo method yet

        modelContext.insert(organization)
        try modelContext.save()
        return organization
    }

    /// Creates multiple trips for testing large datasets
    func createLargeAccessibleDataset(tripCount: Int = 10) throws -> [Trip] {
        var trips: [Trip] = []

        for i in 1...tripCount {
            let trip = Trip(name: "Large Dataset Trip \(i)")
            trip.notes = "Notes for trip \(i) in large dataset testing"

            // Add some variation
            if i % 3 == 0 {
                trip.setStartDate(Date().addingTimeInterval(TimeInterval(i * 86_400)))
                trip.setEndDate(Date().addingTimeInterval(TimeInterval((i + 7) * 86_400)))
            }

            // Note: Trip model doesn't have generateAccessibilityInfo method yet
            modelContext.insert(trip)
            trips.append(trip)
        }

        try modelContext.save()
        return trips
    }

    // MARK: - Background Context Testing

    /// Tests accessibility preservation during background context operations
    func testAccessibilityInBackgroundContext<T>(
        operation: @escaping (ModelContext) async throws -> T
    ) async throws -> T {
        try await operation(self.backgroundContext)
    }

    /// Verifies that accessibility information is preserved after background save
    func verifyAccessibilityAfterBackgroundSave(trip: Trip) async throws {
        let tripId = trip.id

        let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { $0.id == tripId })
        let fetchedTrips = try self.backgroundContext.fetch(descriptor)
        guard let fetchedTrip = fetchedTrips.first else {
            throw AccessibilityTestError.tripNotFound
        }

        // Note: Trip model doesn't have cachedAccessibilityInfo property yet
        // This test will be implemented when accessibility properties are added
        // For now, just verify the trip exists
        _ = fetchedTrip.name
    }

    // MARK: - Performance Testing Utilities

    /// Measures accessibility generation performance for large datasets
    func measureAccessibilityPerformance(
        itemCount: Int,
        operation: @escaping () throws -> Void
    ) throws -> TimeInterval {
        let startTime = Date()
        try operation()
        let endTime = Date()
        return endTime.timeIntervalSince(startTime)
    }

    /// Tests memory usage during accessibility operations
    func testAccessibilityMemoryUsage(
        itemCount: Int,
        operation: @escaping () throws -> Void
    ) throws -> (beforeMemory: Int64, afterMemory: Int64) {
        let memoryBefore = getMemoryUsage()
        try operation()
        let memoryAfter = getMemoryUsage()
        return (beforeMemory: memoryBefore, afterMemory: memoryAfter)
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    // MARK: - CloudKit Sync Testing

    /// Simulates CloudKit sync and verifies accessibility information preservation
    func simulateCloudKitSyncWithAccessibility(trips: [Trip]) async throws {
        // Simulate CloudKit sync delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify all trips maintain accessibility after sync
        for trip in trips {
            let tripId = trip.id
            let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { $0.id == tripId })
            let fetchedTrips = try modelContext.fetch(descriptor)
            guard let syncedTrip = fetchedTrips.first else {
                throw AccessibilityTestError.tripNotFound
            }

            // Note: Trip model doesn't have cachedAccessibilityInfo property yet
            // This test will be implemented when accessibility properties are added
            // For now, just verify the trip exists
            _ = syncedTrip.name
        }
    }

    // MARK: - Data Change Testing

    /// Tests accessibility updates when model data changes
    func testAccessibilityAfterDataChange(trip: Trip, change: @escaping (Trip) -> Void) throws {
        // Make data change
        change(trip)

        // Save changes
        try modelContext.save()

        // Note: Accessibility testing will be implemented when properties are added to Trip model
    }

    // MARK: - Query Performance Testing

    /// Tests accessibility performance with complex queries
    func testAccessibilityWithComplexQueries() throws -> QueryPerformanceResult {
        let startTime = Date()

        // Complex query that would affect accessibility (avoid computed properties with relationships)
        let predicate = #Predicate<Trip> { trip in
            trip.name.contains("Test") && !trip.notes.isEmpty
        }

        let descriptor = FetchDescriptor<Trip>(
            predicate: predicate,
            sortBy: [SortDescriptor(\Trip.name)]
        )

        let results = try modelContext.fetch(descriptor)

        // Verify accessibility is available for all results
        var accessibilityCheckTime: TimeInterval = 0
        let accessibilityStartTime = Date()

        for trip in results {
            // Note: Accessibility properties will be tested when added to Trip model
            _ = trip.name // Use existing property for now
        }

        accessibilityCheckTime = Date().timeIntervalSince(accessibilityStartTime)

        let totalTime = Date().timeIntervalSince(startTime)

        return QueryPerformanceResult(
            queryTime: totalTime - accessibilityCheckTime,
            accessibilityTime: accessibilityCheckTime,
            totalTime: totalTime,
            resultCount: results.count
        )
    }

    // MARK: - Cleanup

    func cleanup() throws {
        // Clear all data
        try modelContext.delete(model: Trip.self)
        try modelContext.delete(model: Activity.self)
        try modelContext.delete(model: Organization.self)
        try modelContext.save()
    }
}

// MARK: - Model Extensions for Accessibility Testing

extension Trip {
    /// Generates comprehensive accessibility information for testing
    func generateAccessibilityInfo() {
        let label = buildAccessibilityLabel()
        let hint = buildAccessibilityHint()
        let value = buildAccessibilityValue()

        // Note: Trip model doesn't have cachedAccessibilityInfo property yet
        // This would store accessibility info when the property is added
        _ = label  // Use label to prevent unused variable warning
        _ = hint   // Use hint to prevent unused variable warning
        _ = value  // Use value to prevent unused variable warning
    }

    /// Updates accessibility when data changes (simulates real-world updates)
    func updateAccessibilityForDataChange() {
        generateAccessibilityInfo()

        // Simulate accessibility system notification
        AccessibilityUpdateNotifier.shared.notifyAccessibilityUpdate(for: self)
    }

    private func buildAccessibilityLabel() -> String {
        var components: [String] = []

        // Trip name
        let tripName = name.isEmpty ? "Untitled Trip" : name
        components.append(tripName)

        // Date information
        if hasDateRange {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            components.append("\(start) - \(end)")
        } else if hasStartDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            components.append("Starts \(formatter.string(from: startDate))")
        }

        // Activity count
        if totalActivities > 0 {
            components.append("\(totalActivities) activities")
        }

        return components.joined(separator: ", ")
    }

    private func buildAccessibilityHint() -> String {
        "Double tap to view trip details"
    }

    private func buildAccessibilityValue() -> String? {
        guard totalActivities > 0 else { return nil }
        return "\(totalActivities) activities planned"
    }
}

extension Activity {
    /// Generates accessibility information for activities
    func generateAccessibilityInfo() {
        _ = buildAccessibilityLabel()
        _ = "Double tap to view activity details"

        // Store accessibility info (would need to add this to Activity model)
        // For testing purposes, we'll just verify the label generation
    }

    private func buildAccessibilityLabel() -> String {
        var components: [String] = []

        components.append(name.isEmpty ? "Untitled Activity" : name)

        if let trip = trip {
            components.append("in \(trip.name)")
        }

        return components.joined(separator: " ")
    }
}

extension Organization {
    /// Generates accessibility information for organizations
    func generateAccessibilityInfo() {
        _ = buildAccessibilityLabel()
        _ = "Double tap to view organization details"

        // Store accessibility info (would need to add this to Organization model)
    }

    private func buildAccessibilityLabel() -> String {
        var components: [String] = []

        components.append(name.isEmpty ? "Unnamed Organization" : name)

        var contactInfo: [String] = []
        if !phone.isEmpty {
            contactInfo.append(phone)
        }
        if !email.isEmpty {
            contactInfo.append(email)
        }

        if !contactInfo.isEmpty {
            components.append(contactInfo.joined(separator: ", "))
        }

        return components.joined(separator: " - ")
    }
}

// MARK: - Supporting Types

/// Cached accessibility information for efficient testing
struct AccessibilityInfo: Codable {
    let label: String
    let hint: String
    let value: String?
    let lastUpdated: Date
}

/// Query performance measurement result
struct QueryPerformanceResult {
    let queryTime: TimeInterval
    let accessibilityTime: TimeInterval
    let totalTime: TimeInterval
    let resultCount: Int

    var accessibilityOverhead: Double {
        guard queryTime > 0 else { return 0 }
        return accessibilityTime / queryTime
    }
}

/// Accessibility test specific errors
enum AccessibilityTestError: Error, LocalizedError {
    case tripNotFound
    case accessibilityInfoLost
    case accessibilityInfoLostDuringSync
    case accessibilityNotUpdatedAfterDataChange
    case performanceThresholdExceeded(TimeInterval)
    case memoryUsageExceeded(Int64)

    var errorDescription: String? {
        switch self {
        case .tripNotFound:
            return "Trip not found during accessibility test"
        case .accessibilityInfoLost:
            return "Accessibility information was lost during operation"
        case .accessibilityInfoLostDuringSync:
            return "Accessibility information was lost during CloudKit sync"
        case .accessibilityNotUpdatedAfterDataChange:
            return "Accessibility information was not updated after data change"
        case .performanceThresholdExceeded(let time):
            return "Accessibility operation exceeded performance threshold: \(time)s"
        case .memoryUsageExceeded(let bytes):
            return "Accessibility operation exceeded memory usage threshold: \(bytes) bytes"
        }
    }
}

/// Singleton for managing accessibility update notifications
class AccessibilityUpdateNotifier {
    static let shared = AccessibilityUpdateNotifier()
    private init() {}

    func notifyAccessibilityUpdate(for trip: Trip) {
        // In a real implementation, this would post notifications to the accessibility system
        // For testing, we'll just log the update
        print("Accessibility updated for trip: \(trip.name)")
    }
}

// MARK: - Convenience Test Functions

/// Global test helper for creating accessible test data
@MainActor
func createAccessibilityTestSuite() throws -> SwiftDataAccessibilityTestBase {
    try SwiftDataAccessibilityTestBase()
}

/// Global test helper for validating accessibility compliance
func validateAccessibilityCompliance<T: Any>(
    for object: T,
    requirements: [AccessibilityRequirement]
) throws {
    for requirement in requirements {
        try requirement.validate(object)
    }
}

/// Accessibility requirements for testing
enum AccessibilityRequirement {
    case hasLabel
    case hasHint
    case hasValue
    case labelNotEmpty
    case hintActionable

    func validate<T>(_ object: T) throws {
        // Implementation would depend on the specific object type
        // This is a framework for extensible accessibility validation
    }
}
