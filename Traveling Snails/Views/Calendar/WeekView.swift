//
//  WeekView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import SwiftUI

struct WeekView: View {
    let currentWeek: [Date]
    let activities: [ActivityWrapper]
    let onDayTap: (Date) -> Void
    let onLongPress: (CGPoint, Date) -> Void
    let onActivityTap: ((any TripActivityProtocol) -> Void)?
    
    private var calendar: Calendar { Calendar.current }
    
    @State private var hasAutoScrolled = false // Track if we've already auto-scrolled to prevent resets
    
    private var isCompactDevice: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
    
    // MARK: - Timezone Conversion Helpers
    
    private func convertToLocalTime(_ date: Date, from sourceTimeZone: TimeZone) -> Date {
        // Extract time components from the date in its original timezone
        var calendar = Calendar.current
        calendar.timeZone = sourceTimeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        // Create a new date with the same time components but in local timezone
        calendar.timeZone = TimeZone.current
        return calendar.date(from: components) ?? date
    }
    
    private func getLocalActivityTimes(_ activity: ActivityWrapper) -> (start: Date, end: Date) {
        let localStart = convertToLocalTime(activity.tripActivity.start, from: activity.tripActivity.startTZ)
        let localEnd = convertToLocalTime(activity.tripActivity.end, from: activity.tripActivity.endTZ)
        return (start: localStart, end: localEnd)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Full-day events section outside ScrollView with responsive layout
            if !fullDayEventBars.isEmpty {
                LazyVStack(spacing: isCompactDevice ? 1 : 3) {
                    ForEach(fullDayEventBars, id: \.id) { wrapper in
                        FullDayEventBar(
                            wrapper: wrapper,
                            weekDates: currentWeek,
                            onTap: { 
                                if let onActivityTap = onActivityTap {
                                    onActivityTap(wrapper.tripActivity)
                                } else {
                                    onDayTap(dateForEvent(wrapper))
                                }
                            },
                            timeColumnWidth: 50
                        )
                        .frame(height: isCompactDevice ? 36 : 42) // Responsive height
                    }
                }
                .background(Color(.systemGray6))
                .padding(.vertical, isCompactDevice ? 4 : 6)
            }
            
            // Day/Date header row outside ScrollView
            HStack(alignment: .top, spacing: 1) {
                // Time column spacer to align with scrollable content
                Color.clear
                    .frame(width: 50, height: 50)
                
                // Day headers
                HStack(alignment: .top, spacing: 1) {
                    ForEach(currentWeek, id: \.self) { date in
                        dayHeaderView(for: date)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Color(.systemBackground))
            
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hourly grid with fixed layout (no header spacer needed now)
                        GeometryReader { geometry in
                            HStack(alignment: .top, spacing: 1) {
                                // Fixed time column
                                VStack(spacing: 0) {
                                    ForEach(0..<24, id: \.self) { hour in
                                        Text(hourFormatter.string(from: timeForHour(hour)))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 50, height: 60, alignment: .topTrailing)
                                            .padding(.trailing, 2)
                                            .id("hour-\(hour)")
                                    }
                                }
                                .frame(width: 50)
                                
                                // Days columns with proper width distribution (no headers)
                                HStack(alignment: .top, spacing: 1) {
                                    ForEach(currentWeek, id: \.self) { date in
                                        WeekDayColumnContent(
                                            date: date,
                                            activities: activitiesForDate(date).filter { !isFullDayEvent($0) },
                                            onLongPress: onLongPress,
                                            onActivityTap: onActivityTap
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .frame(height: CGFloat(24 * 60)) // Fixed height for 24 hours (no header)
                    }
                    .onAppear {
                        if !hasAutoScrolled {
                            scrollToOptimalStartTime(proxy: proxy)
                            hasAutoScrolled = true
                        }
                    }
                    .onChange(of: currentWeek) { _, _ in
                        hasAutoScrolled = false // Reset auto-scroll flag when week changes
                    }
                    // Removed onChange(of: activities) to prevent unwanted scroll resets during dialog interactions
                }
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func activitiesForDate(_ date: Date) -> [ActivityWrapper] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return activities.filter { wrapper in
            let localTimes = getLocalActivityTimes(wrapper)
            
            return localTimes.start < endOfDay && localTimes.end > startOfDay
        }
    }
    
    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }
    
    private func timeForHour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private func scrollToOptimalStartTime(proxy: ScrollViewProxy) {
        let startHour = calculateOptimalStartHour()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.5)) {
                proxy.scrollTo("hour-\(startHour)", anchor: .top)
            }
        }
    }
    
    private func calculateOptimalStartHour() -> Int {
        // Find the earliest event across all days in the current week
        var earliestHour = 6 // Default to 6am
        
        for date in currentWeek {
            let dayActivities = activitiesForDate(date)
            for wrapper in dayActivities {
                let localTimes = getLocalActivityTimes(wrapper)
                let hour = calendar.component(.hour, from: localTimes.start)
                
                if hour < earliestHour {
                    earliestHour = hour
                }
            }
        }
        
        return earliestHour
    }
    
    private func isFullDayEvent(_ wrapper: ActivityWrapper) -> Bool {
        let localTimes = getLocalActivityTimes(wrapper)
        
        // Lodging is always full-day
        if wrapper.type == .lodging {
            return true
        }
        
        // Check if any activity spans multiple days or is marked as all-day
        let startOfDay = calendar.startOfDay(for: localTimes.start)
        let endOfDay = calendar.startOfDay(for: localTimes.end)
        let duration = localTimes.end.timeIntervalSince(localTimes.start)
        
        // Full day if:
        // 1. Activity spans multiple days
        // 2. Activity starts at midnight and lasts 8+ hours
        // 3. Activity duration is 16+ hours (likely full day)
        return startOfDay != endOfDay || 
               (localTimes.start == startOfDay && duration >= 8 * 3600) ||
               duration >= 16 * 3600
    }
    
    private var fullDayEventBars: [ActivityWrapper] {
        let allFullDayEvents = currentWeek.flatMap { date in
            activitiesForDate(date).filter { isFullDayEvent($0) }
        }
        
        var uniqueEvents: [ActivityWrapper] = []
        for event in allFullDayEvents {
            if !uniqueEvents.contains(where: { $0.tripActivity.id == event.tripActivity.id }) {
                uniqueEvents.append(event)
            }
        }
        return uniqueEvents
    }
    
    private func dateForEvent(_ wrapper: ActivityWrapper) -> Date {
        let localTimes = getLocalActivityTimes(wrapper)
        return localTimes.start
    }
    
    // Day header extracted from WeekDayColumn
    @ViewBuilder
    private func dayHeaderView(for date: Date) -> some View {
        Button(action: { onDayTap(date) }) {
            VStack(spacing: 4) {
                // Day name (e.g., "Mon", "Tue")
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Day number with styling
                Text("\(calendar.component(.day, from: date))")
                    .font(.headline)
                    .fontWeight(isToday(date) ? .bold : .medium)
                    .foregroundColor(isToday(date) ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isToday(date) ? Color.blue : Color.clear)
                    .clipShape(Circle())
                
                // Activity count indicator removed per user request
            }
        }
        .frame(height: 50)
        .buttonStyle(.plain)
    }
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
}

// Content-only version of WeekDayColumn (without header)
struct WeekDayColumnContent: View {
    let date: Date
    let activities: [ActivityWrapper]
    let onLongPress: (CGPoint, Date) -> Void
    let onActivityTap: ((any TripActivityProtocol) -> Void)?
    
    private var calendar: Calendar { Calendar.current }
    private let hourHeight: CGFloat = 60
    
    // MARK: - Timezone Conversion Helpers
    
    private func convertToLocalTime(_ date: Date, from sourceTimeZone: TimeZone) -> Date {
        // Extract time components from the date in its original timezone
        var calendar = Calendar.current
        calendar.timeZone = sourceTimeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        // Create a new date with the same time components but in local timezone
        calendar.timeZone = TimeZone.current
        return calendar.date(from: components) ?? date
    }
    
    private func getLocalActivityTimes(_ activity: ActivityWrapper) -> (start: Date, end: Date) {
        let localStart = convertToLocalTime(activity.tripActivity.start, from: activity.tripActivity.startTZ)
        let localEnd = convertToLocalTime(activity.tripActivity.end, from: activity.tripActivity.endTZ)
        return (start: localStart, end: localEnd)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Rectangle()
                            .fill(Color(.systemGray6))
                            .frame(height: hourHeight)
                            .overlay(
                                Rectangle()
                                    .fill(Color(.separator))
                                    .frame(height: 0.5),
                                alignment: .bottom
                            )
                    }
                }
                
                // Activity blocks positioned absolutely
                ForEach(activities.enumerated().map { ActivityPosition(activity: $0.element, index: $0.offset) }, id: \.activity.id) { activityPos in
                    let position = calculateActivityPosition(activityPos.activity, geometry: geometry, index: activityPos.index)
                    
                    Button(action: {
                        if let onActivityTap = onActivityTap {
                            onActivityTap(activityPos.activity.tripActivity)
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(activityPos.activity.type.color)
                            .frame(width: position.width, height: position.height)
                            .overlay(
                                Text(activityPos.activity.tripActivity.name)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .lineLimit(nil)
                                    .padding(.horizontal, 4)
                                    .frame(width: position.width, height: position.height, alignment: .topLeading)
                            )
                    }
                    .buttonStyle(.plain)
                    .position(x: position.x, y: position.y)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let hour = Int(value.location.y / hourHeight)
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                        onLongPress(value.location, hourTime)
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private func calculateActivityPosition(_ activity: ActivityWrapper, geometry: GeometryProxy, index: Int) -> ActivityBlockPosition {
        let startOfDay = calendar.startOfDay(for: date)
        
        // Convert activity times to local timezone for display
        let localTimes = getLocalActivityTimes(activity)
        let activityStart = localTimes.start
        let activityEnd = localTimes.end
        
        // Calculate time offsets from start of day
        let startOffset = max(0, activityStart.timeIntervalSince(startOfDay))
        let endOffset = min(24 * 3600, activityEnd.timeIntervalSince(startOfDay))
        let duration = endOffset - startOffset
        
        // Convert to pixel positions
        let startY = (startOffset / 3600) * hourHeight
        let height = max(20, (duration / 3600) * hourHeight) // Minimum 20pt height
        
        // Handle overlapping activities by adjusting width and x position
        let overlappingActivities = getOverlappingActivities(activity)
        let totalOverlapping = overlappingActivities.count
        let activityIndex = overlappingActivities.firstIndex(where: { $0.tripActivity.id == activity.tripActivity.id }) ?? 0
        
        let availableWidth = geometry.size.width - 8 // 4pt padding on each side
        let activityWidth = totalOverlapping > 1 ? availableWidth / CGFloat(totalOverlapping) : availableWidth
        let xPosition = 4 + (activityWidth * CGFloat(activityIndex)) + (activityWidth / 2)
        let yPosition = startY + (height / 2)
        
        return ActivityBlockPosition(
            x: xPosition,
            y: yPosition,
            width: activityWidth,
            height: height
        )
    }
    
    private func getOverlappingActivities(_ targetActivity: ActivityWrapper) -> [ActivityWrapper] {
        let targetLocalTimes = getLocalActivityTimes(targetActivity)
        
        return activities.filter { activity in
            let activityLocalTimes = getLocalActivityTimes(activity)
            
            return targetLocalTimes.start < activityLocalTimes.end && targetLocalTimes.end > activityLocalTimes.start
        }.sorted {
            let times1 = getLocalActivityTimes($0)
            let times2 = getLocalActivityTimes($1)
            return times1.start < times2.start
        }
    }
}

struct ActivityPosition {
    let activity: ActivityWrapper
    let index: Int
}

struct ActivityBlockPosition {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}
