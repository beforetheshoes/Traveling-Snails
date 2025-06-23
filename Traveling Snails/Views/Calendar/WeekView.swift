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
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Full-day events section with consistent height
                if !fullDayEventBars.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(fullDayEventBars, id: \.id) { wrapper in
                            FullDayEventBar(
                                wrapper: wrapper,
                                weekDates: currentWeek,
                                onTap: { onDayTap(dateForEvent(wrapper)) },
                                timeColumnWidth: 50
                            )
                        }
                    }
                    .frame(minHeight: 40)
                    .background(Color(.systemGray6))
                    .padding(.vertical, 8)
                }
                
                // Hourly grid with fixed layout
                GeometryReader { geometry in
                    HStack(alignment: .top, spacing: 1) {
                        // Fixed time column
                        VStack(spacing: 0) {
                            // Header spacer for alignment
                            Color.clear
                                .frame(height: 50)
                            
                            ForEach(0..<24, id: \.self) { hour in
                                Text(hourFormatter.string(from: timeForHour(hour)))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, height: 60, alignment: .topTrailing)
                                    .padding(.trailing, 4)
                            }
                        }
                        
                        // Days columns with proper width distribution
                        HStack(alignment: .top, spacing: 1) {
                            ForEach(currentWeek, id: \.self) { date in
                                WeekDayColumn(
                                    date: date,
                                    activities: activitiesForDate(date).filter { !isFullDayEvent($0) },
                                    onDayTap: { onDayTap(date) },
                                    onLongPress: onLongPress
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(24 * 60 + 50)) // Fixed height for 24 hours + header
            }
        }
        .background(Color(.systemBackground))
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
    
    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }
    
    private func timeForHour(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
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
    
    private var fullDayEventBars: [ActivityWrapper] {
        let allFullDayEvents = currentWeek.flatMap { date in
            activitiesForDate(date).filter { isFullDayEvent($0) }
        }
        
        var uniqueEvents: [ActivityWrapper] = []
        for event in allFullDayEvents {
            if !uniqueEvents.contains(where: { $0.id == event.id }) {
                uniqueEvents.append(event)
            }
        }
        return uniqueEvents
    }
    
    private func dateForEvent(_ wrapper: ActivityWrapper) -> Date {
        return wrapper.tripActivity.start
    }
}
