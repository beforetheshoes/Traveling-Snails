//
//  TripCalendarViewTests.swift
//  Traveling Snails
//

import Testing

@testable import Traveling_Snails

@Suite("Trip Calendar View Tests")
struct TripCalendarViewTests {
    @Test("TripCalendarRootView initializes", .tags(.ui, .fast, .swiftui, .calendar, .validation))
    @MainActor
    func tripCalendarRootViewInitializes() {
        let trip = Trip(name: "Test Trip")
        _ = TripCalendarRootView(trip: trip)
        #expect(Bool(true))
    }
}
