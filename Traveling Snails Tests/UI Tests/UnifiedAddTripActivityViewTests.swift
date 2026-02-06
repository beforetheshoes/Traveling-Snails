//
//  UnifiedAddTripActivityViewTests.swift
//  Traveling Snails
//

import Testing

@testable import Traveling_Snails

@Suite("Unified Add Trip Activity View Tests")
struct UnifiedAddTripActivityViewTests {
    @Test("UniversalAddTripActivityRootView initializes", .tags(.ui, .fast, .swiftui, .activity, .validation))
    @MainActor
    func universalAddTripActivityRootViewInitializes() {
        let trip = Trip(name: "Test Trip")
        _ = UniversalAddTripActivityRootView.forActivity(trip: trip)
        #expect(Bool(true))
    }
}
