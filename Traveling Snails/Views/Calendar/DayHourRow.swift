//
//  DayHourRow.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI

struct DayHourRow: View {
    let hour: Int
    let date: Date
    let activities: [ActivityWrapper]
    let onDragStart: (CGPoint, Date) -> Void
    let onDragUpdate: (CGPoint, Date) -> Void
    let onDragEnd: (CGPoint, Date) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private var hourTime: Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Time label
            VStack {
                Text(hourFormatter.string(from: hourTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(width: 60)
            
            Divider()
            
            // Hour content with drag support
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(.systemBackground))
                    .overlay(
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                
                // Activities in this hour
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, wrapper in
                    ActivityBarView(
                        wrapper: wrapper,
                        hour: hour,
                        date: date,
                        offset: CGFloat(index * 8)
                    )
                }
                
                // Drag selection overlay
                if dragOffset > 0 {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: dragOffset)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStart(value.location, hourTime)
                        } else {
                            onDragUpdate(value.location, hourTime)
                        }
                        dragOffset = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        isDragging = false
                        let minutes = Int(value.translation.height / 60 * 60)
                        let endTime = Calendar.current.date(byAdding: .minute, value: max(15, minutes), to: hourTime) ?? hourTime
                        onDragEnd(value.location, endTime)
                        dragOffset = 0
                    }
            )
        }
    }
    
    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }
}
