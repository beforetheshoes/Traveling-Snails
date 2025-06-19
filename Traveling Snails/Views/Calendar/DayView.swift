//
//  DayView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import SwiftUI

struct DayView: View {
    let date: Date
    let activities: [ActivityWrapper]
    let onDragStart: (CGPoint, Date) -> Void
    let onDragUpdate: (CGPoint, Date) -> Void
    let onDragEnd: (CGPoint, Date) -> Void
    
    @State private var dragLocation: CGPoint = .zero
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        DayHourRow(
                            hour: hour,
                            date: date,
                            activities: activitiesForHour(hour),
                            onDragStart: { point, time in
                                onDragStart(point, time)
                            },
                            onDragUpdate: { point, time in
                                onDragUpdate(point, time)
                            },
                            onDragEnd: { point, time in
                                onDragEnd(point, time)
                            }
                        )
                        .frame(height: 60)
                    }
                }
            }
        }
    }
    
    private func activitiesForHour(_ hour: Int) -> [ActivityWrapper] {
        let startOfHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? startOfHour
        
        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            
            return activityStart < endOfHour && activityEnd > startOfHour
        }
    }
}
