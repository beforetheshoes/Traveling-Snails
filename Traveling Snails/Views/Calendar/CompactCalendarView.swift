//
//  CompactCalendarView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI
import Foundation

struct CompactCalendarView: View {
    let trip: Trip
    let activities: [ActivityWrapper]
    let onActivityTap: (any TripActivityProtocol) -> Void
    
    @State private var currentDateOffset = 0 // Day-based offset instead of week-based
    @State private var showingFullCalendar = false
    @State private var scrollPosition: CGFloat = 0 // Track scroll position

    // Add this computed property for visible days based on screen width
    private var visibleDaysCount: Int {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            return 3 // Show 3 days on phone for better readability
        } else {
            return 7 // iPad shows all 7
        }
        #else
        return 7 // Mac/other platforms
        #endif
    }

    private var calendar: Calendar { Calendar.current }
    
    private var baseStartDate: Date {
        // Use trip dates instead of today
        if let tripRange = trip.actualDateRange {
            return tripRange.lowerBound
        } else {
            return Date() // Fallback only if no trip activities
        }
    }
    
    private var currentStartDate: Date {
        return calendar.date(byAdding: .day, value: currentDateOffset, to: baseStartDate) ?? baseStartDate
    }
    
    private var visibleDateRange: [Date] {
        return (0..<visibleDaysCount).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: currentStartDate)
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Date range navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentDateOffset -= visibleDaysCount
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                headerTitleView
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentDateOffset += visibleDaysCount
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            
            // Week view with full height - takes all remaining space
            GeometryReader { geometry in
                // Comprehensive safety check for valid geometry
                if geometry.size.width.isFinite && geometry.size.width > 50 &&
                   geometry.size.height.isFinite && geometry.size.height > 50 {
                    dayScrollView(geometry: geometry)
                } else {
                    // Fallback view when geometry is invalid or too small
                    Text("Calculating layout...")
                        .frame(width: 100, height: 100)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Full calendar button - pinned to bottom
            Button {
                showingFullCalendar = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                    Text("Open Full Calendar")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .padding()
        }
        .onAppear {
            // Initialize calendar to proper starting position if needed
        }
        .fullScreenCover(isPresented: $showingFullCalendar) {
            TripCalendarRootView(trip: trip)
        }
    }
    
    private var headerTitleView: some View {
        VStack {
            Text(headerTitleText)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(headerSubtitleText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var headerTitleText: String {
        if visibleDateRange.count > 1,
           let firstDay = visibleDateRange.first,
           let lastDay = visibleDateRange.last {
            return "\(firstDay.formatted(.dateTime.month(.abbreviated).day())) - \(lastDay.formatted(.dateTime.month(.abbreviated).day()))"
        } else if let singleDay = visibleDateRange.first {
            return singleDay.formatted(.dateTime.month(.abbreviated).day())
        }
        return ""
    }

    private var headerSubtitleText: String {
        return visibleDateRange.first?.formatted(.dateTime.year()) ?? ""
    }
    
    private func dayScrollView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Full day events spanning across visible days
            fullDayEventBarsSection(geometry: geometry)
            
            // Day views - using simple HStack since we're showing exact visible days
            dayHStack(geometry: geometry)
        }
    }

    private func dayHStack(geometry: GeometryProxy) -> some View {
        let dayWidth = calculateDayWidth(geometry: geometry)
        
        return HStack(spacing: 12) {
            ForEach(Array(visibleDateRange.enumerated()), id: \.element) { index, date in
                dayView(for: date, index: index, dayWidth: dayWidth)
            }
        }
        .padding(.horizontal)
    }

    private func dayView(for date: Date, index: Int, dayWidth: CGFloat) -> some View {
        // Ensure width is always valid, finite, and positive
        let safeWidth = dayWidth.isFinite && dayWidth > 0 ? dayWidth : 100
        let validWidth = max(50, min(safeWidth, 500))
        
        return CompactDayView(
            date: date,
            activities: activitiesForDate(date).filter { !isFullDayEvent($0) },
            onActivityTap: onActivityTap
        )
        .frame(width: validWidth)
        .frame(maxHeight: .infinity)
        .id(index)
    }
    
    private func calculateDayWidth(geometry: GeometryProxy) -> CGFloat {
        // Comprehensive safety checks for geometry values
        guard geometry.size.width.isFinite,
              geometry.size.width > 0,
              geometry.size.height.isFinite,
              geometry.size.height > 0 else {
            return 100 // Safe fallback
        }
        
        let availableWidth = max(48, geometry.size.width - 48) // Ensure at least 48pt available
        let dayCount = max(1, visibleDaysCount)
        
        let calculatedWidth = availableWidth / CGFloat(dayCount)
        
        // Ensure the result is always finite, positive, and reasonable
        guard calculatedWidth.isFinite,
              calculatedWidth > 0,
              calculatedWidth < CGFloat.greatestFiniteMagnitude else {
            return 100 // Safe fallback
        }
        
        return max(50, min(calculatedWidth, 500)) // Bounded between 50-500pt
    }
    
    private func fullDayEventBarsSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 2) {
            ForEach(fullDayEvents, id: \.id) { wrapper in
                CompactFullDayEventBar(
                    wrapper: wrapper,
                    visibleDates: visibleDateRange,
                    onTap: {
                        onActivityTap(wrapper.tripActivity)
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func fullDayEventsOverlay(for date: Date) -> some View {
        VStack {
            Spacer()
                .frame(height: 68)
            
            VStack(spacing: 2) {
                ForEach(fullDayEventsForDate(date), id: \.id) { wrapper in
                    HStack(spacing: 0) {
                        if isEventStart(wrapper, date) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(wrapper.tripActivity.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                HStack(spacing: 4) {
                                    Text(timeWithTimezone(wrapper.tripActivity.start, timezone: wrapper.tripActivity.startTZ))
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("→")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                        } else if isEventEnd(wrapper, date) {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(wrapper.tripActivity.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(timeWithTimezone(wrapper.tripActivity.end, timezone: wrapper.tripActivity.endTZ))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        } else if eventSpansDate(wrapper, date) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(wrapper.tripActivity.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("All Day")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(wrapper.type.color)
                    )
                    .padding(.horizontal, 2)
                }
            }
            
            Spacer()
        }
    }

    private func isEventStart(_ wrapper: ActivityWrapper, _ date: Date) -> Bool {
        calendar.isDate(wrapper.tripActivity.start, inSameDayAs: date)
    }
    
    private func isEventEnd(_ wrapper: ActivityWrapper, _ date: Date) -> Bool {
        calendar.isDate(wrapper.tripActivity.end, inSameDayAs: date)
    }
    
    private func eventSpansDate(_ wrapper: ActivityWrapper, _ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return wrapper.tripActivity.start < endOfDay && wrapper.tripActivity.end > startOfDay
    }
    
    private func activitiesForDate(_ date: Date) -> [ActivityWrapper] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            
            return activityStart < endOfDay && activityEnd > startOfDay
        }
    }
    
    private var fullDayEvents: [ActivityWrapper] {
        let allFullDayEvents = visibleDateRange.flatMap { date in
            activitiesForDate(date).filter { isFullDayEvent($0) }
        }
        
        // Remove duplicates
        var uniqueEvents: [ActivityWrapper] = []
        for event in allFullDayEvents {
            if !uniqueEvents.contains(where: { $0.id == event.id }) {
                uniqueEvents.append(event)
            }
        }
        return uniqueEvents
    }
    
    private func fullDayEventsForDate(_ date: Date) -> [ActivityWrapper] {
        return fullDayEvents.filter { wrapper in
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            
            return wrapper.tripActivity.start < endOfDay && wrapper.tripActivity.end > startOfDay
        }
    }
    
    private func isFullDayEvent(_ wrapper: ActivityWrapper) -> Bool {
        let start = wrapper.tripActivity.start
        let end = wrapper.tripActivity.end
        
        // Lodging is always full-day
        if wrapper.type == .lodging {
            return true
        }
        
        // Check if any activity spans multiple days or is marked as all-day
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.startOfDay(for: end)
        let duration = end.timeIntervalSince(start)
        
        // Full day if:
        // 1. Activity spans multiple days
        // 2. Activity starts at midnight and lasts 8+ hours
        // 3. Activity duration is 16+ hours (likely full day)
        return startOfDay != endOfDay || 
               (start == startOfDay && duration >= 8 * 3600) ||
               duration >= 16 * 3600
    }
    
    private func timeWithTimezone(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        let timeString = formatter.string(from: date)
        let abbreviation = TimeZoneHelper.getAbbreviation(for: timezone)
        return "\(timeString) \(abbreviation)"
    }
}
