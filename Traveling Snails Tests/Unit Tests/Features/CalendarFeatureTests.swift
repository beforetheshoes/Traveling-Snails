//
//  CalendarFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("CalendarFeature Tests")
@MainActor
struct CalendarFeatureTests {
    @Test("Day tap selects date and shows day detail", .tags(.unit, .fast, .parallel, .calendar))
    func dayTapSelectsDate() async {
        let trip = Trip(name: "Test Trip")
        let store = TestStore(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }

        let targetDate = Date(timeIntervalSince1970: 1_700_000_000)

        await store.send(.dayTapped(targetDate)) {
            $0.selectedDate = targetDate
            $0.selectedDayActivities = []
            $0.showingDayDetail = true
        }
    }

    @Test("Long press sets pending activity data", .tags(.unit, .fast, .parallel, .calendar))
    func longPressSetsPendingData() async {
        let trip = Trip(name: "Test Trip")
        let store = TestStore(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }

        let point = CGPoint(x: 10, y: 20)
        let time = Date(timeIntervalSince1970: 1_700_000_100)

        await store.send(.longPress(point: point, time: time)) {
            $0.pendingActivityData = CalendarFeature.PendingActivityData(
                startTime: time,
                endTime: nil,
                tapLocation: point
            )
            $0.showingActivityTypeSelector = true
        }
    }

    @Test("Drag under 15 minutes does not create pending activity", .tags(.unit, .fast, .parallel, .calendar))
    func dragUnderThresholdDoesNotCreatePending() async {
        let trip = Trip(name: "Test Trip")
        let store = TestStore(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(10 * 60)

        await store.send(.dragStart(point: CGPoint(x: 10, y: 10), time: start)) {
            $0.dragStartTime = start
            $0.isDragging = true
            $0.showingDragPreview = true
            $0.dragPreviewFrame = CGRect(origin: CGPoint(x: 10, y: 10), size: CGSize(width: 200, height: 20))
        }

        await store.send(.dragEnd(point: CGPoint(x: 10, y: 50), time: end)) {
            $0.isDragging = false
            $0.showingDragPreview = false
            $0.dragStartTime = nil
            $0.dragEndTime = nil
            $0.pendingActivityData = nil
        }
    }

    @Test("Drag over 15 minutes creates pending activity", .tags(.unit, .fast, .parallel, .calendar))
    func dragOverThresholdCreatesPending() async {
        let trip = Trip(name: "Test Trip")
        let store = TestStore(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(20 * 60)

        await store.send(.dragStart(point: CGPoint(x: 10, y: 10), time: start)) {
            $0.dragStartTime = start
            $0.isDragging = true
            $0.showingDragPreview = true
            $0.dragPreviewFrame = CGRect(origin: CGPoint(x: 10, y: 10), size: CGSize(width: 200, height: 20))
        }

        await store.send(.dragEnd(point: CGPoint(x: 10, y: 50), time: end)) {
            $0.isDragging = false
            $0.showingDragPreview = false
            $0.dragStartTime = nil
            $0.dragEndTime = nil
            $0.pendingActivityData = CalendarFeature.PendingActivityData(
                startTime: start,
                endTime: end,
                tapLocation: .zero
            )
            $0.showingActivityTypeSelector = true
        }
    }

    @Test("Changing mode adjusts display date calculation", .tags(.unit, .fast, .parallel, .calendar))
    func modeChangeAffectsDisplayDate() async {
        var state = CalendarFeature.State(trip: Trip(name: "Test Trip"))
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        state.selectedDate = baseDate
        state.currentWeekOffset = 1

        let store = TestStore(initialState: state) {
            CalendarFeature()
        }

        await store.send(.binding(.set(\.calendarMode, .month))) {
            $0.calendarMode = .month
        }

        let displayDate = store.state.currentDisplayDate
        #expect(displayDate != baseDate)
    }
}
