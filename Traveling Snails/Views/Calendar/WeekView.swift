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
        ScrollView {
            VStack(spacing: 0) {
                // Full-day events as continuous bars
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
                .background(Color(.systemGray5))
                .padding(.vertical, 8)
                
                // Hourly grid
                HStack(alignment: .top, spacing: 1) {
                    // Time column
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hourFormatter.string(from: timeForHour(hour)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 50, height: 60, alignment: .topTrailing)
                                .padding(.trailing, 4)
                        }
                    }
                    
                    // Days columns
                    HStack(alignment: .top, spacing: 1) {
                        ForEach(currentWeek, id: \.self) { date in
                            WeekDayColumn(
                                date: date,
                                activities: activitiesForDate(date).filter { !isFullDayEvent($0) },
                                onDayTap: { onDayTap(date) },
                                onLongPress: onLongPress
                            )
                        }
                    }
                }
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
        
        if wrapper.type == .lodging {
            return true
        }
        
        let startOfDay = calendar.startOfDay(for: start)
        let duration = end.timeIntervalSince(start)
        
        return start == startOfDay && duration >= 12 * 3600
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
