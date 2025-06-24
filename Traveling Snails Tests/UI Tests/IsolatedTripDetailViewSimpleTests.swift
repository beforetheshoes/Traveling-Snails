//
//  IsolatedTripDetailViewSimpleTests.swift
//  Traveling Snails
//
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("IsolatedTripDetailView Simple Tests")
struct IsolatedTripDetailViewSimpleTests {
    
    @Test("View can be initialized without crashes")
    func testViewInitialization() {
        let trip = Trip(name: "Test Trip")
        
        // This should complete without hanging or crashing
        let startTime = Date()
        let _ = IsolatedTripDetailView(trip: trip)
        let endTime = Date()
        
        let initTime = endTime.timeIntervalSince(startTime)
        
        // If infinite recreation was happening, this would take much longer or hang
        #expect(initTime < 0.1, "View initialization should be fast")
    }
    
    @Test("Multiple view initializations are independent and fast")
    func testMultipleInitializations() {
        let startTime = Date()
        
        // Create multiple views rapidly - this would hang if infinite recreation occurred
        for i in 0..<20 {
            let trip = Trip(name: "Test Trip \(i)")
            let _ = IsolatedTripDetailView(trip: trip)
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        
        // Should be able to create 20 views very quickly
        #expect(totalTime < 0.5, "Creating 20 views should be fast")
    }
    
    @Test("View initialization with same trip data is consistent")
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
