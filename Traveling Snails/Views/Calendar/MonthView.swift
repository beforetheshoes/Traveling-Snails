//
//  MonthView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import SwiftUI

struct MonthView: View {
    let monthDates: [Date]
    let activities: [ActivityWrapper]
    let currentDisplayDate: Date
    let onDayTap: (Date) -> Void
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
                // Day headers
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                
                // Month days with padding
                ForEach(monthDaysWithPadding, id: \.self) { date in
                    if let date = date {
                        MonthDayCell(
                            date: date,
                            activities: activitiesForDate(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentDisplayDate, toGranularity: .month),
                            isToday: calendar.isDateInToday(date),
                            onTap: { onDayTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 90)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var monthDaysWithPadding: [Date?] {
        guard let firstDate = monthDates.first else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstDate)
        let paddingDays = Array(repeating: nil as Date?, count: firstWeekday - 1)
        
        return paddingDays + monthDates.map { Optional($0) }
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
