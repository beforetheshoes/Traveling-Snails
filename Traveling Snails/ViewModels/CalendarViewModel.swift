//
//  CalendarViewModel.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import Foundation
import SwiftUI
import Observation

@Observable
class CalendarViewModel {
    // MARK: - Properties
    
    let trip: Trip
    private let dateProvider: CalendarDateProvider
    private let eventHandler: CalendarEventHandler
    
    // Calendar state
    var selectedDate: Date
    var currentWeekOffset = 0
    var calendarMode: CalendarMode = .week
    
    // Activity creation state
    var pendingActivityData: PendingActivityData?
    var showingActivityTypeSelector = false
    var showingActivityCreation = false
    var selectedActivityType: ActivityTypeOption = .activity
    
    // Day detail state
    var showingDayDetail = false
    var selectedDayActivities: [ActivityWrapper] = []
    
    // Navigation state
    var navigationPath = NavigationPath()
    
    // Drag state
    var dragStartTime: Date?
    var dragEndTime: Date?
    var isDragging = false
    var dragPreviewFrame: CGRect = .zero
    var showingDragPreview = false
    
    // MARK: - Initialization
    
    init(trip: Trip) {
        self.trip = trip
        self.dateProvider = CalendarDateProvider(trip: trip)
        self.eventHandler = CalendarEventHandler()
        
        // Initialize with trip's start date or first activity date
        if let tripStartDate = trip.effectiveStartDate {
            self.selectedDate = tripStartDate
        } else if let firstActivityDate = trip.actualDateRange?.lowerBound {
            self.selectedDate = firstActivityDate
        } else {
            self.selectedDate = Date()
        }
    }
    
    // MARK: - Computed Properties
    
    var allActivities: [ActivityWrapper] {
        let lodgingActivities = trip.lodging.map { ActivityWrapper($0) }
        let transportationActivities = trip.transportation.map { ActivityWrapper($0) }
        let activityActivities = trip.activity.map { ActivityWrapper($0) }
        
        return (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
    }
    
    var currentWeek: [Date] {
        dateProvider.currentWeek(for: selectedDate, offset: currentWeekOffset)
    }
    
    var currentMonth: [Date] {
        dateProvider.currentMonth(for: selectedDate, offset: currentWeekOffset)
    }
    
    var currentDisplayDate: Date {
        dateProvider.currentDisplayDate(for: selectedDate, mode: calendarMode, offset: currentWeekOffset)
    }
    
    var activitiesForCurrentPeriod: [ActivityWrapper] {
        dateProvider.activitiesForPeriod(
            activities: allActivities,
            displayDate: currentDisplayDate,
            mode: calendarMode,
            currentWeek: currentWeek
        )
    }
    
    // MARK: - Actions
    
    func handleDayTap(date: Date) {
        eventHandler.handleDayTap(
            date: date,
            activities: allActivities,
            onDateSelected: { [weak self] newDate, activities in
                self?.selectedDate = newDate
                self?.selectedDayActivities = activities
                self?.showingDayDetail = true
            }
        )
    }
    
    func handleLongPress(at point: CGPoint, time: Date) {
        eventHandler.handleLongPress(
            at: point,
            time: time,
            onActivityCreationRequested: { [weak self] pendingData in
                self?.pendingActivityData = pendingData
                self?.showingActivityTypeSelector = true
            }
        )
    }
    
    func handleActivityTap(_ activity: any TripActivityProtocol) {
        let destination = DestinationType.from(activity)
        navigationPath.append(destination)
    }
    
    func handleDragStart(at point: CGPoint, time: Date) {
        eventHandler.handleDragStart(
            at: point,
            time: time,
            onDragStateChanged: { [weak self] dragState in
                self?.dragStartTime = dragState.startTime
                self?.isDragging = dragState.isDragging
                self?.showingDragPreview = dragState.showingPreview
                self?.dragPreviewFrame = dragState.previewFrame
            }
        )
    }
    
    func handleDragUpdate(to point: CGPoint, time: Date) {
        guard let startTime = dragStartTime else { return }
        
        eventHandler.handleDragUpdate(
            to: point,
            time: time,
            startTime: startTime,
            currentFrame: dragPreviewFrame,
            onFrameUpdated: { [weak self] newFrame in
                self?.dragEndTime = time
                self?.dragPreviewFrame = newFrame
            }
        )
    }
    
    func handleDragEnd(at point: CGPoint, time: Date) {
        guard let startTime = dragStartTime else { return }
        
        eventHandler.handleDragEnd(
            at: point,
            time: time,
            startTime: startTime,
            onDragComplete: { [weak self] pendingData in
                self?.isDragging = false
                self?.showingDragPreview = false
                self?.dragStartTime = nil
                self?.dragEndTime = nil
                
                if let pendingData = pendingData {
                    self?.pendingActivityData = pendingData
                    self?.showingActivityTypeSelector = true
                }
            }
        )
    }
    
    func createQuickActivity() {
        pendingActivityData = PendingActivityData(
            startTime: Date(),
            endTime: nil,
            tapLocation: .zero
        )
        showingActivityTypeSelector = true
    }
    
    func selectActivityType(_ type: ActivityTypeOption) {
        selectedActivityType = type
        showingActivityTypeSelector = false // Close the type selector first
        showingActivityCreation = true
    }
    
    func cancelActivityCreation() {
        pendingActivityData = nil
        showingActivityTypeSelector = false
        showingActivityCreation = false
    }
    
    func completeActivityCreation() {
        cancelActivityCreation()
    }
}

// MARK: - Supporting Types

extension CalendarViewModel {
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
    
    struct PendingActivityData {
        let startTime: Date
        let endTime: Date?
        let tapLocation: CGPoint
    }
}

// MARK: - CalendarDateProvider

class CalendarDateProvider {
    private let trip: Trip
    private let calendar = Calendar.current
    
    init(trip: Trip) {
        self.trip = trip
    }
    
    private var tripDateRange: ClosedRange<Date>? {
        if let tripRange = trip.dateRange {
            return tripRange
        } else if let actualRange = trip.actualDateRange {
            return actualRange
        }
        return nil
    }
    
    func currentWeek(for selectedDate: Date, offset: Int) -> [Date] {
        let baseDate: Date
        if let tripRange = tripDateRange {
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
    
    func currentMonth(for selectedDate: Date, offset: Int) -> [Date] {
        let baseDate: Date
        if let tripRange = tripDateRange {
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
    
    func currentDisplayDate(for selectedDate: Date, mode: CalendarViewModel.CalendarMode, offset: Int) -> Date {
        switch mode {
        case .day:
            return calendar.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
        case .week, .month:
            let baseDate = calendar.dateInterval(of: mode == .week ? .weekOfYear : .month, for: selectedDate)?.start ?? selectedDate
            return calendar.date(byAdding: mode == .week ? .weekOfYear : .month, value: offset, to: baseDate) ?? baseDate
        }
    }
    
    func activitiesForPeriod(
        activities: [ActivityWrapper],
        displayDate: Date,
        mode: CalendarViewModel.CalendarMode,
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
    
    func activitiesForDate(_ activities: [ActivityWrapper], date: Date) -> [ActivityWrapper] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            
            return activityStart < endOfDay && activityEnd > startOfDay
        }
    }
}

// MARK: - CalendarEventHandler

class CalendarEventHandler {
    func handleDayTap(
        date: Date,
        activities: [ActivityWrapper],
        onDateSelected: (Date, [ActivityWrapper]) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        let activitiesForDate = activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            
            return activityStart < endOfDay && activityEnd > startOfDay
        }
        
        onDateSelected(date, activitiesForDate)
    }
    
    func handleLongPress(
        at point: CGPoint,
        time: Date,
        onActivityCreationRequested: (CalendarViewModel.PendingActivityData) -> Void
    ) {
        let pendingData = CalendarViewModel.PendingActivityData(
            startTime: time,
            endTime: nil,
            tapLocation: point
        )
        onActivityCreationRequested(pendingData)
    }
    
    func handleDragStart(
        at point: CGPoint,
        time: Date,
        onDragStateChanged: (DragState) -> Void
    ) {
        let dragState = DragState(
            startTime: time,
            isDragging: true,
            showingPreview: true,
            previewFrame: CGRect(origin: point, size: CGSize(width: 200, height: 20))
        )
        onDragStateChanged(dragState)
    }
    
    func handleDragUpdate(
        to point: CGPoint,
        time: Date,
        startTime: Date,
        currentFrame: CGRect,
        onFrameUpdated: (CGRect) -> Void
    ) {
        let height = abs(point.y - currentFrame.origin.y)
        let newHeight = max(20, height)
        
        let duration = abs(time.timeIntervalSince(startTime))
        let hours = duration / 3600
        let newWidth = max(200, CGFloat(hours * 100))
        
        let newFrame = CGRect(
            origin: currentFrame.origin,
            size: CGSize(width: newWidth, height: newHeight)
        )
        
        onFrameUpdated(newFrame)
    }
    
    func handleDragEnd(
        at point: CGPoint,
        time: Date,
        startTime: Date,
        onDragComplete: (CalendarViewModel.PendingActivityData?) -> Void
    ) {
        let earlierTime = min(startTime, time)
        let laterTime = max(startTime, time)
        
        // Only create activity if drag duration is at least 15 minutes
        if laterTime.timeIntervalSince(earlierTime) >= 15 * 60 {
            let pendingData = CalendarViewModel.PendingActivityData(
                startTime: earlierTime,
                endTime: laterTime,
                tapLocation: .zero
            )
            onDragComplete(pendingData)
        } else {
            onDragComplete(nil)
        }
    }
    
    struct DragState {
        let startTime: Date
        let isDragging: Bool
        let showingPreview: Bool
        let previewFrame: CGRect
    }
}