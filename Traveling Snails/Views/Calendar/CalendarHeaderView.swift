//
//  CalendarHeaderView.swift
//  Traveling Snails
//
//

import SwiftUI

struct CalendarHeaderView: View {
    let trip: Trip
    @Binding var selectedDate: Date
    @Binding var currentWeekOffset: Int
    @Binding var calendarMode: CalendarViewModel.CalendarMode
    let activities: [ActivityWrapper]
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        VStack(spacing: 16) {
            // Trip info summary with date context
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(activities.count) total activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let tripRange = trip.dateRange {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Trip Dates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(tripRange.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(tripRange.upperBound.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                } else if let actualRange = trip.actualDateRange {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Activity Dates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(actualRange.lowerBound.formatted(date: .abbreviated, time: .omitted)) - \(actualRange.upperBound.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal)
            
            // Mode selector
            Picker("Calendar Mode", selection: $calendarMode) {
                ForEach(CalendarViewModel.CalendarMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // Navigation controls
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentWeekOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack {
                    Text(headerTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if calendarMode != .month {
                        Text(headerSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentWeekOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            Button("Go to Trip Start") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if let tripRange = trip.dateRange {
                        selectedDate = tripRange.lowerBound
                    } else if let actualRange = trip.actualDateRange {
                        selectedDate = actualRange.lowerBound
                    } else {
                        selectedDate = Date()
                    }
                    currentWeekOffset = 0
                }
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
    
    private var headerTitle: String {
        let formatter = DateFormatter()
        
        switch calendarMode {
        case .day:
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            return formatter.string(from: currentDisplayDate)
        case .week:
            let week = currentWeek
            guard let firstDay = week.first, let lastDay = week.last else { return "" }
            
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: firstDay)
            let endString = formatter.string(from: lastDay)
            
            return "\(startString) - \(endString)"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: currentDisplayDate)
        }
    }
    
    private var headerSubtitle: String {
        let activitiesInPeriod = activitiesForCurrentPeriod
        return "\(activitiesInPeriod.count) activities"
    }
    
    private var currentDisplayDate: Date {
        switch calendarMode {
        case .day:
            return calendar.date(byAdding: .day, value: currentWeekOffset, to: selectedDate) ?? selectedDate
        case .week, .month:
            let baseDate = calendar.dateInterval(of: calendarMode == .week ? .weekOfYear : .month, for: selectedDate)?.start ?? selectedDate
            return calendar.date(byAdding: calendarMode == .week ? .weekOfYear : .month, value: currentWeekOffset, to: baseDate) ?? baseDate
        }
    }
    
    private var currentWeek: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let adjustedStart = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: startOfWeek) ?? startOfWeek
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: adjustedStart)
        }
    }
    
    private var activitiesForCurrentPeriod: [ActivityWrapper] {
        let displayDate = currentDisplayDate
        
        switch calendarMode {
        case .day:
            return activitiesForDate(displayDate)
        case .week:
            let week = currentWeek
            guard let startOfWeek = week.first, let endOfWeek = week.last else { return [] }
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
    
    private func activitiesForDate(_ date: Date) -> [ActivityWrapper] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            
            return activityStart < endOfDay && activityEnd > startOfDay
        }
    }
}
