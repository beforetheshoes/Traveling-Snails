//
//  CompactCalendarView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI

struct CompactCalendarView: View {
    let trip: Trip
    let activities: [ActivityWrapper]
    let onActivityTap: (any TripActivityProtocol) -> Void
    
    @State private var selectedWeekOffset = 0
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

    private var visibleWeekRange: [Date] {
        // For phones, just show first few days of the week
        if visibleDaysCount < 7 {
            return Array(currentWeek.prefix(visibleDaysCount))
        } else {
            return currentWeek
        }
    }

    private var calendar: Calendar { Calendar.current }
    
    private var currentWeek: [Date] {
        // Use trip dates instead of today
        let baseDate: Date
        if let tripRange = trip.actualDateRange {
            baseDate = tripRange.lowerBound
        } else {
            baseDate = Date() // Fallback only if no trip activities
        }
        
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: baseDate)?.start ?? baseDate
        let adjustedStart = calendar.date(byAdding: .weekOfYear, value: selectedWeekOffset, to: startOfWeek) ?? startOfWeek
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: adjustedStart)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Week navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedWeekOffset -= 1
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
                        selectedWeekOffset += 1
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
                // Add safety check here too
                if geometry.size.width > 0 && geometry.size.height > 0 {
                    dayScrollView(geometry: geometry)
                } else {
                    // Fallback view when geometry is invalid
                    Text("Loading...")
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
            // Debug the initial state
            print("=== CompactCalendarView onAppear ===")
            print("Visible days count: \(visibleDaysCount)")
            print("Current week: \(currentWeek)")
            print("Activities count: \(activities.count)")
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
        if visibleWeekRange.count > 1,
           let firstDay = visibleWeekRange.first,
           let lastDay = visibleWeekRange.last {
            return "\(firstDay.formatted(.dateTime.month(.abbreviated).day())) - \(lastDay.formatted(.dateTime.month(.abbreviated).day()))"
        } else if let singleDay = visibleWeekRange.first {
            return singleDay.formatted(.dateTime.month(.abbreviated).day())
        }
        return ""
    }

    private var headerSubtitleText: String {
        return currentWeek.first?.formatted(.dateTime.year()) ?? ""
    }
    
    private func dayScrollView(geometry: GeometryProxy) -> some View {
        // Debug logging
        print("=== GeometryReader Debug ===")
        print("Geometry size: \(geometry.size)")
        print("Available width: \(geometry.size.width - 48)")
        print("Visible days count: \(visibleDaysCount)")
        print("Current week count: \(currentWeek.count)")
        
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                dayHStack(geometry: geometry)
            }
            .onChange(of: selectedWeekOffset) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(0, anchor: .leading)
                }
            }
            .onAppear {
                // Start at beginning of week
                proxy.scrollTo(0, anchor: .leading)
            }
        }
    }

    private func dayHStack(geometry: GeometryProxy) -> some View {
        let safeWidth = max(100, geometry.size.width - 48) // Ensure minimum total width
        let safeDayCount = max(1, min(visibleDaysCount, currentWeek.count))
        let dayWidth = safeWidth / CGFloat(safeDayCount)
        
        print("=== HStack Debug ===")
        print("Safe width: \(safeWidth)")
        print("Safe day count: \(safeDayCount)")
        print("Day width: \(dayWidth)")
        
        return HStack(spacing: 12) {
            ForEach(Array(currentWeek.enumerated()), id: \.element) { index, date in
                dayView(for: date, index: index, dayWidth: dayWidth)
            }
        }
        .padding(.horizontal)
    }

    private func dayView(for date: Date, index: Int, dayWidth: CGFloat) -> some View {
        print("=== Day View Debug ===")
        print("Date: \(date)")
        print("Index: \(index)")
        print("Day width: \(dayWidth)")
        
        // Ensure width is always valid
        let validWidth = max(50, min(dayWidth, 500)) // Between 50 and 500 points
        
        return ZStack(alignment: .top) {
            CompactDayView(
                date: date,
                activities: activitiesForDate(date).filter { !isFullDayEvent($0) },
                onActivityTap: onActivityTap
            )
            
            fullDayEventsOverlay(for: date)
        }
        .frame(
            width: validWidth,
            height: .infinity
        )
        .id(index)
    }
    
    private func calculateDayViewWidth(geometry: GeometryProxy) -> CGFloat {
        let availableWidth = max(0, geometry.size.width - 48)
        let dayCount = max(1, min(visibleDaysCount, currentWeek.count))
        
        guard availableWidth > 0 && dayCount > 0 else {
            return 100
        }
        
        let calculatedWidth = availableWidth / CGFloat(dayCount)
        
        return max(50, calculatedWidth)
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
                                    Text(wrapper.tripActivity.start, style: .time)
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
                                Text(wrapper.tripActivity.end, style: .time)
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
        let allFullDayEvents = currentWeek.flatMap { date in
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
        let calendar = Calendar.current
        let start = wrapper.tripActivity.start
        let end = wrapper.tripActivity.end
        
        if wrapper.type == .lodging {
            return true
        }
        
        let startOfDay = calendar.startOfDay(for: start)
        let duration = end.timeIntervalSince(start)
        
        return start == startOfDay && duration >= 12 * 3600
    }
}
