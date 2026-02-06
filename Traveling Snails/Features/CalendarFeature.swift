//
//  CalendarFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct CalendarFeature {
    @ObservableState
    struct State: Equatable {
        let trip: Trip

        var selectedDate: Date
        var currentWeekOffset = 0
        var calendarMode: CalendarMode = .week

        var pendingActivityData: PendingActivityData?
        var showingActivityTypeSelector = false
        var showingActivityCreation = false
        var selectedActivityType: ActivityTypeOption = .activity

        var showingDayDetail = false
        var selectedDayActivities: [ActivityWrapper] = []

        var navigationPath = NavigationPath()

        var dragStartTime: Date?
        var dragEndTime: Date?
        var isDragging = false
        var dragPreviewFrame: CGRect = .zero
        var showingDragPreview = false

        init(trip: Trip) {
            self.trip = trip

            if let tripStartDate = trip.effectiveStartDate {
                self.selectedDate = tripStartDate
            } else if let firstActivityDate = trip.actualDateRange?.lowerBound {
                self.selectedDate = firstActivityDate
            } else {
                self.selectedDate = Date()
            }
        }

        var allActivities: [ActivityWrapper] {
            let lodgingActivities = trip.lodging.map { ActivityWrapper($0) }
            let transportationActivities = trip.transportation.map { ActivityWrapper($0) }
            let activityActivities = trip.activity.map { ActivityWrapper($0) }

            return (lodgingActivities + transportationActivities + activityActivities)
                .sorted { $0.tripActivity.start < $1.tripActivity.start }
        }

        var currentWeek: [Date] {
            CalendarHelpers.currentWeek(for: selectedDate, offset: currentWeekOffset, trip: trip)
        }

        var currentMonth: [Date] {
            CalendarHelpers.currentMonth(for: selectedDate, offset: currentWeekOffset, trip: trip)
        }

        var currentDisplayDate: Date {
            CalendarHelpers.currentDisplayDate(for: selectedDate, mode: calendarMode, offset: currentWeekOffset)
        }

        var activitiesForCurrentPeriod: [ActivityWrapper] {
            CalendarHelpers.activitiesForPeriod(
                activities: allActivities,
                displayDate: currentDisplayDate,
                mode: calendarMode,
                currentWeek: currentWeek
            )
        }

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.trip.id == rhs.trip.id
                && lhs.selectedDate == rhs.selectedDate
                && lhs.currentWeekOffset == rhs.currentWeekOffset
                && lhs.calendarMode == rhs.calendarMode
                && lhs.pendingActivityData == rhs.pendingActivityData
                && lhs.showingActivityTypeSelector == rhs.showingActivityTypeSelector
                && lhs.showingActivityCreation == rhs.showingActivityCreation
                && lhs.selectedActivityType == rhs.selectedActivityType
                && lhs.showingDayDetail == rhs.showingDayDetail
                && lhs.selectedDayActivities == rhs.selectedDayActivities
                && lhs.dragStartTime == rhs.dragStartTime
                && lhs.dragEndTime == rhs.dragEndTime
                && lhs.isDragging == rhs.isDragging
                && lhs.dragPreviewFrame == rhs.dragPreviewFrame
                && lhs.showingDragPreview == rhs.showingDragPreview
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case dayTapped(Date)
        case longPress(point: CGPoint, time: Date)
        case activityTapped(DestinationType)
        case dragStart(point: CGPoint, time: Date)
        case dragUpdate(point: CGPoint, time: Date)
        case dragEnd(point: CGPoint, time: Date)
        case quickAddTapped
        case selectActivityType(ActivityTypeOption)
        case cancelActivityCreation
        case completeActivityCreation
        case showDayDetail(Date)
        case hideDayDetail
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .dayTapped(let date):
                let activitiesForDate = CalendarHelpers.activitiesForDate(state.allActivities, date: date)
                state.selectedDate = date
                state.selectedDayActivities = activitiesForDate
                state.showingDayDetail = true
                return .none
            case .longPress(let point, let time):
                state.pendingActivityData = PendingActivityData(
                    startTime: time,
                    endTime: nil,
                    tapLocation: point
                )
                state.showingActivityTypeSelector = true
                return .none
            case .activityTapped(let destination):
                state.navigationPath.append(destination)
                return .none
            case .dragStart(let point, let time):
                state.dragStartTime = time
                state.isDragging = true
                state.showingDragPreview = true
                state.dragPreviewFrame = CGRect(origin: point, size: CGSize(width: 200, height: 20))
                return .none
            case .dragUpdate(let point, let time):
                guard let startTime = state.dragStartTime else { return .none }

                let height = abs(point.y - state.dragPreviewFrame.origin.y)
                let newHeight = max(20, height)

                let duration = abs(time.timeIntervalSince(startTime))
                let hours = duration / 3600
                let newWidth = max(200, CGFloat(hours * 100))

                state.dragEndTime = time
                state.dragPreviewFrame = CGRect(
                    origin: state.dragPreviewFrame.origin,
                    size: CGSize(width: newWidth, height: newHeight)
                )
                return .none
            case .dragEnd(_, let time):
                guard let startTime = state.dragStartTime else { return .none }

                state.isDragging = false
                state.showingDragPreview = false
                state.dragStartTime = nil
                state.dragEndTime = nil

                let earlierTime = min(startTime, time)
                let laterTime = max(startTime, time)

                if laterTime.timeIntervalSince(earlierTime) >= 15 * 60 {
                    state.pendingActivityData = PendingActivityData(
                        startTime: earlierTime,
                        endTime: laterTime,
                        tapLocation: .zero
                    )
                    state.showingActivityTypeSelector = true
                } else {
                    state.pendingActivityData = nil
                }
                return .none
            case .quickAddTapped:
                state.pendingActivityData = PendingActivityData(
                    startTime: Date(),
                    endTime: nil,
                    tapLocation: .zero
                )
                state.showingActivityTypeSelector = true
                return .none
            case .selectActivityType(let type):
                state.selectedActivityType = type
                state.showingActivityTypeSelector = false
                state.showingActivityCreation = true
                return .none
            case .cancelActivityCreation:
                state.pendingActivityData = nil
                state.showingActivityTypeSelector = false
                state.showingActivityCreation = false
                return .none
            case .completeActivityCreation:
                state.pendingActivityData = nil
                state.showingActivityTypeSelector = false
                state.showingActivityCreation = false
                return .none
            case .showDayDetail(let date):
                state.selectedDate = date
                state.selectedDayActivities = CalendarHelpers.activitiesForDate(state.allActivities, date: date)
                state.showingDayDetail = true
                return .none
            case .hideDayDetail:
                state.showingDayDetail = false
                return .none
            }
        }
    }
}

// MARK: - Supporting Types

extension CalendarFeature {
    enum CalendarMode: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var icon: String {
            switch self {
            case .day: return "calendar.day.timeline.leading"
            case .week: return "calendar"
            case .month: return "calendar.month"
            }
        }
    }

    enum ActivityTypeOption: String, CaseIterable {
        case transportation = "Transportation"
        case lodging = "Lodging"
        case activity = "Activity"

        var icon: String {
            switch self {
            case .transportation: return "airplane"
            case .lodging: return "bed.double"
            case .activity: return "ticket"
            }
        }

        var color: Color {
            switch self {
            case .transportation: return .blue
            case .lodging: return .indigo
            case .activity: return .purple
            }
        }
    }

    struct PendingActivityData: Equatable {
        let startTime: Date
        let endTime: Date?
        let tapLocation: CGPoint
    }
}

// MARK: - Calendar Helpers

enum CalendarHelpers {
    private static let calendar = Calendar.current

    private static func tripDateRange(for trip: Trip) -> ClosedRange<Date>? {
        if let tripRange = trip.dateRange {
            return tripRange
        }
        if let actualRange = trip.actualDateRange {
            return actualRange
        }
        return nil
    }

    static func currentWeek(for selectedDate: Date, offset: Int, trip: Trip) -> [Date] {
        let baseDate: Date
        if let tripRange = tripDateRange(for: trip) {
            if tripRange.contains(selectedDate) {
                baseDate = selectedDate
            } else {
                baseDate = tripRange.lowerBound
            }
        } else {
            baseDate = selectedDate
        }

        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: baseDate)?.start ?? baseDate
        let adjustedStart = calendar.date(byAdding: .weekOfYear, value: offset, to: startOfWeek) ?? startOfWeek

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: adjustedStart)
        }
    }

    static func currentMonth(for selectedDate: Date, offset: Int, trip: Trip) -> [Date] {
        let baseDate: Date
        if let tripRange = tripDateRange(for: trip) {
            if tripRange.contains(selectedDate) {
                baseDate = selectedDate
            } else {
                baseDate = tripRange.lowerBound
            }
        } else {
            baseDate = selectedDate
        }

        guard let monthInterval = calendar.dateInterval(of: .month, for: baseDate) else { return [] }
        let adjustedMonth = calendar.date(byAdding: .month, value: offset, to: monthInterval.start) ?? monthInterval.start
        guard let adjustedInterval = calendar.dateInterval(of: .month, for: adjustedMonth) else { return [] }

        var dates: [Date] = []
        var currentDate = adjustedInterval.start

        while currentDate < adjustedInterval.end {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return dates
    }

    static func currentDisplayDate(for selectedDate: Date, mode: CalendarFeature.CalendarMode, offset: Int) -> Date {
        switch mode {
        case .day:
            return calendar.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
        case .week, .month:
            let baseDate = calendar.dateInterval(of: mode == .week ? .weekOfYear : .month, for: selectedDate)?.start ?? selectedDate
            return calendar.date(byAdding: mode == .week ? .weekOfYear : .month, value: offset, to: baseDate) ?? baseDate
        }
    }

    static func activitiesForPeriod(
        activities: [ActivityWrapper],
        displayDate: Date,
        mode: CalendarFeature.CalendarMode,
        currentWeek: [Date]
    ) -> [ActivityWrapper] {
        switch mode {
        case .day:
            return activitiesForDate(activities, date: displayDate)
        case .week:
            guard let startOfWeek = currentWeek.first, let endOfWeek = currentWeek.last else { return [] }
            let endOfDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endOfWeek) ?? endOfWeek)

            return activities.filter { wrapper in
                let activityStart = wrapper.tripActivity.start
                return activityStart >= startOfWeek && activityStart < endOfDay
            }
        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: displayDate) else { return [] }

            return activities.filter { wrapper in
                let activityStart = wrapper.tripActivity.start
                return activityStart >= monthInterval.start && activityStart < monthInterval.end
            }
        }
    }

    static func activitiesForDate(_ activities: [ActivityWrapper], date: Date) -> [ActivityWrapper] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end

            return activityStart < endOfDay && activityEnd > startOfDay
        }
    }
}
