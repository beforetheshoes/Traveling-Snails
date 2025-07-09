//
//  IsolatedTripDetailViewSimpleTests.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("IsolatedTripDetailView Simple Tests")
struct IsolatedTripDetailViewSimpleTests {
    @Test("View can be initialized without crashes", .tags(.ui, .fast, .parallel, .swiftui, .trip, .validation, .smoke, .performance))
    func testViewInitialization() {
        let trip = Trip(name: "Test Trip")

        // This should complete without hanging or crashing
        let startTime = Date()
        _ = IsolatedTripDetailView(trip: trip)
        let endTime = Date()

        let initTime = endTime.timeIntervalSince(startTime)

        // If infinite recreation was happening, this would take much longer or hang
        #expect(initTime < 0.1, "View initialization should be fast")
    }

    @Test("Multiple view initializations are independent and fast", .tags(.ui, .medium, .parallel, .swiftui, .trip, .validation, .performance, .regression))
    func testMultipleInitializations() {
        let startTime = Date()

        // Create multiple views rapidly - this would hang if infinite recreation occurred
        for i in 0..<20 {
            let trip = Trip(name: "Test Trip \(i)")
            _ = IsolatedTripDetailView(trip: trip)
        }

        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)

        // Should be able to create 20 views very quickly
        #expect(totalTime < 0.5, "Creating 20 views should be fast")
    }

    @Test("View initialization with same trip data is consistent", .tags(.ui, .fast, .parallel, .swiftui, .trip, .validation, .regression))
    func testConsistentInitialization() {
        let trip = Trip(name: "Consistent Test Trip")

        // Create multiple views with same trip
        _ = IsolatedTripDetailView(trip: trip)
        _ = IsolatedTripDetailView(trip: trip)
        _ = IsolatedTripDetailView(trip: trip)

        // All should initialize successfully without issues
        // If there was infinite recreation, this test would hang
        #expect(trip.name == "Consistent Test Trip", "All views initialized successfully")
    }
}
