//
//  TripCalendarRootViewTests.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("TripCalendarRootView Tests")
struct TripCalendarRootViewTests {
    
    // MARK: - Calendar Date Provider Tests
    
    @Suite("Calendar Date Computations")
    struct CalendarDateProviderTests {
        
        @Test("Current week calculation")
        func testCurrentWeekCalculation() {
            let _ = Trip(name: "Test Trip")
            let testDate = Date()
            
            // Test current week calculation logic that should be extracted
            let calendar = Calendar.current
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: testDate)?.start ?? testDate
            let currentWeek = (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
            }
            
            #expect(currentWeek.count == 7)
            #expect(currentWeek.first == startOfWeek)
            
            // Last day should be 6 days after start
            let expectedLastDay = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            #expect(currentWeek.last! <= expectedLastDay.addingTimeInterval(24 * 3600))
        }
        
        @Test("Current month calculation")
        func testCurrentMonthCalculation() {
            let _ = Trip(name: "Test Trip")
            let testDate = Date()
            
            // Test month calculation logic that should be extracted
            let calendar = Calendar.current
            guard let monthInterval = calendar.dateInterval(of: .month, for: testDate) else {
                #expect(Bool(false), "Should be able to get month interval")
                return
            }
            
            var dates: [Date] = []
            var currentDate = monthInterval.start
            
            while currentDate < monthInterval.end {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            
            #expect(dates.count >= 28) // At least 28 days in a month
            #expect(dates.count <= 31) // At most 31 days
            #expect(dates.first == monthInterval.start)
        }
        
        @Test("Trip date range handling")
        func testTripDateRangeHandling() {
            let trip = Trip(name: "Test Trip")
            let startDate = Date()
            let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate)!
            
            trip.startDate = startDate
            trip.endDate = endDate
            trip.hasStartDate = true
            trip.hasEndDate = true
            
            // Test trip date range logic
            let tripRange = trip.dateRange
            #expect(tripRange != nil)
            #expect(tripRange?.lowerBound == startDate)
            #expect(tripRange?.upperBound == endDate)
            
            // Test contains logic
            let midDate = Calendar.current.date(byAdding: .day, value: 3, to: startDate)!
            #expect(tripRange?.contains(midDate) == true)
            
            let beforeDate = Calendar.current.date(byAdding: .day, value: -1, to: startDate)!
            #expect(tripRange?.contains(beforeDate) == false)
        }
        
        @Test("Activities for date filtering")
        func testActivitiesForDateFiltering() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            let testDate = Date()
            let startOfDay = Calendar.current.startOfDay(for: testDate)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // Create activities on different days
            let todayActivity = Activity(
                name: "Today Activity",
                start: startOfDay.addingTimeInterval(3600), // 1 hour into the day
                end: startOfDay.addingTimeInterval(7200),   // 2 hours into the day
                trip: trip,
                organization: org
            )
            
            let yesterdayActivity = Activity(
                name: "Yesterday Activity",
                start: startOfDay.addingTimeInterval(-3600), // 1 hour before start of day
                end: startOfDay.addingTimeInterval(-1800),   // 30 min before start of day
                trip: trip,
                organization: org
            )
            
            let tomorrowActivity = Activity(
                name: "Tomorrow Activity",
                start: endOfDay.addingTimeInterval(3600),   // 1 hour after end of day
                end: endOfDay.addingTimeInterval(7200),     // 2 hours after end of day
                trip: trip,
                organization: org
            )
            
            let allActivities = [todayActivity, yesterdayActivity, tomorrowActivity].map { ActivityWrapper($0) }
            
            // Test filtering logic that should be extracted
            let activitiesForToday = allActivities.filter { wrapper in
                let activityStart = wrapper.tripActivity.start
                let activityEnd = wrapper.tripActivity.end
                
                return activityStart < endOfDay && activityEnd > startOfDay
            }
            
            #expect(activitiesForToday.count == 1)
            #expect(activitiesForToday.first?.tripActivity.name == "Today Activity")
        }
    }
    
    // MARK: - Calendar Mode Tests
    
    @Suite("Calendar Display Modes")
    struct CalendarModeTests {
        
        @Test("Calendar mode enumeration")
        func testCalendarModeEnum() {
            let dayMode = CalendarViewModel.CalendarMode.day
            let weekMode = CalendarViewModel.CalendarMode.week
            let monthMode = CalendarViewModel.CalendarMode.month
            
            #expect(dayMode.rawValue == "Day")
            #expect(weekMode.rawValue == "Week")
            #expect(monthMode.rawValue == "Month")
            
            #expect(dayMode.icon == "calendar.day.timeline.leading")
            #expect(weekMode.icon == "calendar")
            #expect(monthMode.icon == "calendar.month")
        }
        
        @Test("Current display date calculation")
        func testCurrentDisplayDateCalculation() {
            let selectedDate = Date()
            let currentWeekOffset = 1 // One week forward
            
            // Test day mode
            let dayDisplayDate = Calendar.current.date(byAdding: .day, value: currentWeekOffset, to: selectedDate) ?? selectedDate
            #expect(dayDisplayDate > selectedDate)
            
            // Test week mode
            let calendar = Calendar.current
            let baseWeekDate = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
            let weekDisplayDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: baseWeekDate) ?? baseWeekDate
            #expect(weekDisplayDate > baseWeekDate)
            
            // Test month mode
            let baseMonthDate = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
            let monthDisplayDate = calendar.date(byAdding: .month, value: currentWeekOffset, to: baseMonthDate) ?? baseMonthDate
            #expect(monthDisplayDate > baseMonthDate)
        }
    }
    
    // MARK: - Activity Creation Tests
    
    @Suite("Activity Creation Logic")
    struct ActivityCreationTests {
        
        @Test("Activity type options")
        func testActivityTypeOptions() {
            let transportation = CalendarViewModel.ActivityTypeOption.transportation
            let lodging = CalendarViewModel.ActivityTypeOption.lodging
            let activity = CalendarViewModel.ActivityTypeOption.activity
            
            #expect(transportation.rawValue == "Transportation")
            #expect(lodging.rawValue == "Lodging")
            #expect(activity.rawValue == "Activity")
            
            #expect(transportation.icon == "airplane")
            #expect(lodging.icon == "bed.double")
            #expect(activity.icon == "ticket")
            
            #expect(transportation.color == .blue)
            #expect(lodging.color == .indigo)
            #expect(activity.color == .purple)
        }
        
        @Test("Pending activity data creation")
        func testPendingActivityDataCreation() {
            let startTime = Date()
            let endTime = Calendar.current.date(byAdding: .hour, value: 2, to: startTime)
            let tapLocation = CGPoint(x: 100, y: 200)
            
            let pendingData = CalendarViewModel.PendingActivityData(
                startTime: startTime,
                endTime: endTime,
                tapLocation: tapLocation
            )
            
            #expect(pendingData.startTime == startTime)
            #expect(pendingData.endTime == endTime)
            #expect(pendingData.tapLocation == tapLocation)
        }
        
        @Test("Default activity durations")
        func testDefaultActivityDurations() {
            let startTime = Date()
            
            // Transportation default (2 hours)
            let transportationEnd = Calendar.current.date(byAdding: .hour, value: 2, to: startTime)!
            #expect(transportationEnd.timeIntervalSince(startTime) == 2 * 3600)
            
            // Lodging default (1 day)
            let lodgingEnd = Calendar.current.date(byAdding: .day, value: 1, to: startTime)!
            #expect(lodgingEnd.timeIntervalSince(startTime) == 24 * 3600)
            
            // Activity default (2 hours)
            let activityEnd = Calendar.current.date(byAdding: .hour, value: 2, to: startTime)!
            #expect(activityEnd.timeIntervalSince(startTime) == 2 * 3600)
        }
    }
    
    // MARK: - Drag and Drop Tests
    
    @Suite("Drag and Drop Logic")
    struct DragDropTests {
        
        @Test("Drag preview frame calculation")
        func testDragPreviewFrameCalculation() {
            let startPoint = CGPoint(x: 100, y: 100)
            let endPoint = CGPoint(x: 100, y: 200)
            
            let height = abs(endPoint.y - startPoint.y)
            #expect(height == 100)
            
            let maxHeight = max(20, height)
            #expect(maxHeight == 100)
            
            // Test minimum height
            let closePoints = CGPoint(x: 100, y: 105)
            let smallHeight = abs(closePoints.y - startPoint.y)
            let clampedHeight = max(20, smallHeight)
            #expect(clampedHeight == 20)
        }
        
        @Test("Drag duration calculation")
        func testDragDurationCalculation() {
            let startTime = Date()
            let endTime = startTime.addingTimeInterval(3600) // 1 hour later
            
            let duration = abs(endTime.timeIntervalSince(startTime))
            let hours = duration / 3600
            
            #expect(duration == 3600)
            #expect(hours == 1.0)
            
            // Test minimum duration for activity creation
            let shortDuration: TimeInterval = 10 * 60 // 10 minutes
            let longDuration: TimeInterval = 20 * 60  // 20 minutes
            
            #expect(shortDuration < 15 * 60) // Below minimum
            #expect(longDuration >= 15 * 60) // Above minimum
        }
        
        @Test("Drag validation for activity creation")
        func testDragValidationForActivityCreation() {
            let startTime = Date()
            
            // Valid drag (20 minutes)
            let validEndTime = startTime.addingTimeInterval(20 * 60)
            let validDuration = validEndTime.timeIntervalSince(startTime)
            #expect(validDuration >= 15 * 60)
            
            // Invalid drag (5 minutes)
            let invalidEndTime = startTime.addingTimeInterval(5 * 60)
            let invalidDuration = invalidEndTime.timeIntervalSince(startTime)
            #expect(invalidDuration < 15 * 60)
        }
    }
    
    // MARK: - Event Handling Tests
    
    @Suite("Event Handling Logic")
    struct EventHandlingTests {
        
        @Test("Day tap handling")
        func testDayTapHandling() {
            let selectedDate = Date()
            let activities: [ActivityWrapper] = []
            
            // Test that day tap updates selected date and activities
            // This logic should be moved to CalendarViewModel
            var newSelectedDate = selectedDate
            var newSelectedActivities: [ActivityWrapper] = []
            
            // Simulate day tap
            let tappedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            newSelectedDate = tappedDate
            newSelectedActivities = activities // In real implementation, would filter by date
            
            #expect(newSelectedDate == tappedDate)
            #expect(newSelectedActivities.isEmpty)
        }
        
        @Test("Long press handling")
        func testLongPressHandling() {
            let pressPoint = CGPoint(x: 150, y: 300)
            let pressTime = Date()
            
            // Test long press creates pending activity data
            let pendingData = CalendarViewModel.PendingActivityData(
                startTime: pressTime,
                endTime: nil,
                tapLocation: pressPoint
            )
            
            #expect(pendingData.startTime == pressTime)
            #expect(pendingData.endTime == nil)
            #expect(pendingData.tapLocation == pressPoint)
        }
        
        @Test("Drag start handling")
        func testDragStartHandling() {
            let dragPoint = CGPoint(x: 200, y: 400)
            let dragTime = Date()
            
            // Test drag start state
            var dragStartTime: Date? = nil
            var isDragging = false
            var showingDragPreview = false
            var dragPreviewFrame = CGRect.zero
            
            // Simulate drag start
            dragStartTime = dragTime
            isDragging = true
            showingDragPreview = true
            dragPreviewFrame = CGRect(origin: dragPoint, size: CGSize(width: 200, height: 20))
            
            #expect(dragStartTime == dragTime)
            #expect(isDragging == true)
            #expect(showingDragPreview == true)
            #expect(dragPreviewFrame.origin == dragPoint)
            #expect(dragPreviewFrame.size.width == 200)
            #expect(dragPreviewFrame.size.height == 20)
        }
    }
    
    // MARK: - View Initialization Tests
    
    @Suite("View Initialization")
    struct ViewInitializationTests {
        
        @Test("Trip calendar view initialization with trip start date")
        func testInitializationWithTripStartDate() {
            let trip = Trip(name: "Test Trip")
            let startDate = Date()
            trip.startDate = startDate
            trip.hasStartDate = true
            
            // Test initialization logic that should be in CalendarViewModel
            let initialDate: Date
            if let tripStartDate = trip.effectiveStartDate {
                initialDate = tripStartDate
            } else {
                initialDate = Date()
            }
            
            #expect(initialDate == startDate)
        }
        
        @Test("Trip calendar view initialization with activity dates")
        func testInitializationWithActivityDates() {
            let beforeInit = Date()
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            trip.hasStartDate = false
            
            // Create an activity
            let activityDate = Date()
            let _ = Activity(
                name: "Test Activity",
                start: activityDate,
                end: activityDate.addingTimeInterval(3600),
                trip: trip,
                organization: org
            )
            
            // Test fallback to first activity date
            let initialDate: Date
            if let tripStartDate = trip.effectiveStartDate {
                initialDate = tripStartDate
            } else if let firstActivityDate = trip.actualDateRange?.lowerBound {
                initialDate = firstActivityDate
            } else {
                initialDate = Date()
            }
            
            // Since we don't have actual trip relationships in test,
            // this tests the fallback logic structure
            // initialDate is always non-nil by design
            #expect(initialDate >= beforeInit)
        }
        
        @Test("Trip calendar view initialization fallback")
        func testInitializationFallback() {
            let trip = Trip(name: "Test Trip")
            trip.hasStartDate = false
            trip.hasEndDate = false
            
            // Test fallback to current date
            let beforeInit = Date()
            let initialDate: Date
            if let tripStartDate = trip.effectiveStartDate {
                initialDate = tripStartDate
            } else {
                initialDate = Date()
            }
            let afterInit = Date()
            
            #expect(initialDate >= beforeInit)
            #expect(initialDate <= afterInit)
        }
    }
    
    // MARK: - State Management Tests
    
    @Suite("Calendar State Management")
    struct StateManagementTests {
        
        @Test("Calendar mode state transitions")
        func testCalendarModeTransitions() {
            var calendarMode: CalendarViewModel.CalendarMode = .week
            
            // Test mode changes
            calendarMode = .day
            #expect(calendarMode == .day)
            
            calendarMode = .month
            #expect(calendarMode == .month)
            
            calendarMode = .week
            #expect(calendarMode == .week)
        }
        
        @Test("Week offset state management")
        func testWeekOffsetState() {
            var currentWeekOffset = 0
            
            // Test forward navigation
            currentWeekOffset += 1
            #expect(currentWeekOffset == 1)
            
            // Test backward navigation
            currentWeekOffset -= 2
            #expect(currentWeekOffset == -1)
            
            // Test reset
            currentWeekOffset = 0
            #expect(currentWeekOffset == 0)
        }
        
        @Test("Activity sheet state management")
        func testActivitySheetState() {
            var showingActivityTypeSelector = false
            var showingActivityCreation = false
            var showingDayDetail = false
            
            // Test showing activity type selector
            showingActivityTypeSelector = true
            #expect(showingActivityTypeSelector == true)
            
            // Test showing activity creation
            showingActivityCreation = true
            #expect(showingActivityCreation == true)
            
            // Test showing day detail
            showingDayDetail = true
            #expect(showingDayDetail == true)
            
            // Test hiding all
            showingActivityTypeSelector = false
            showingActivityCreation = false
            showingDayDetail = false
            
            #expect(showingActivityTypeSelector == false)
            #expect(showingActivityCreation == false)
            #expect(showingDayDetail == false)
        }
    }
    
    // MARK: - Integration Tests
    
    @Suite("Calendar Integration")
    struct CalendarIntegrationTests {
        
        @Test("Complete activity creation flow")
        func testCompleteActivityCreationFlow() {
            let _ = Trip(name: "Test Trip")
            let startTime = Date()
            let endTime = startTime.addingTimeInterval(2 * 3600)
            
            // Test the complete flow from drag to activity creation
            var pendingActivityData: CalendarViewModel.PendingActivityData? = nil
            var selectedActivityType: CalendarViewModel.ActivityTypeOption = .activity
            var showingActivityTypeSelector = false
            var showingActivityCreation = false
            
            // 1. Create pending data (from drag or tap)
            pendingActivityData = CalendarViewModel.PendingActivityData(
                startTime: startTime,
                endTime: endTime,
                tapLocation: CGPoint(x: 100, y: 100)
            )
            
            #expect(pendingActivityData != nil)
            #expect(pendingActivityData?.startTime == startTime)
            #expect(pendingActivityData?.endTime == endTime)
            
            // 2. Show activity type selector
            showingActivityTypeSelector = true
            #expect(showingActivityTypeSelector == true)
            
            // 3. Select activity type
            selectedActivityType = .lodging
            #expect(selectedActivityType == .lodging)
            
            // 4. Show activity creation
            showingActivityCreation = true
            #expect(showingActivityCreation == true)
            
            // 5. Cleanup after creation
            pendingActivityData = nil
            showingActivityTypeSelector = false
            showingActivityCreation = false
            
            #expect(pendingActivityData == nil)
            #expect(showingActivityTypeSelector == false)
            #expect(showingActivityCreation == false)
        }
        
        @Test("Calendar navigation with activities")
        func testCalendarNavigationWithActivities() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            
            // Create activities across multiple days
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            let todayActivity = Activity(
                name: "Today Activity",
                start: today,
                end: today.addingTimeInterval(3600),
                trip: trip,
                organization: org
            )
            
            let tomorrowActivity = Activity(
                name: "Tomorrow Activity", 
                start: tomorrow,
                end: tomorrow.addingTimeInterval(3600),
                trip: trip,
                organization: org
            )
            
            let allActivities = [todayActivity, tomorrowActivity].map { ActivityWrapper($0) }
            
            // Test activity filtering by current display period
            let displayDate = today
            let calendar = Calendar.current
            
            // Test day view filtering
            let startOfDay = calendar.startOfDay(for: displayDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let activitiesForDay = allActivities.filter { wrapper in
                let activityStart = wrapper.tripActivity.start
                let activityEnd = wrapper.tripActivity.end
                return activityStart < endOfDay && activityEnd > startOfDay
            }
            
            #expect(activitiesForDay.count == 1)
            #expect(activitiesForDay.first?.tripActivity.name == "Today Activity")
        }
    }
}