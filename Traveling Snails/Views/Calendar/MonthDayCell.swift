//
//  MonthDayCell.swift
//  Traveling Snails
//
//

import SwiftUI

struct MonthDayCell: View {
    let date: Date
    let activities: [ActivityWrapper]
    let isCurrentMonth: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(isToday ? .bold : .medium)
                        .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                        .frame(width: 24, height: 24)
                        .background(isToday ? Color.blue : Color.clear)
                        .clipShape(Circle())
                    
                    Spacer()
                    
                    if !activities.isEmpty {
                        Text("\(activities.count)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                
                // Activity indicators with better layout
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 4), spacing: 1) {
                    ForEach(Array(activities.prefix(8).enumerated()), id: \.offset) { index, wrapper in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(wrapper.type.color)
                            .frame(height: 3)
                    }
                }
                .frame(height: 12)
                
                if activities.count > 8 {
                    Text("+\(activities.count - 8)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .frame(height: 90)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(activities.isEmpty ? Color.clear : Color(.systemGray6))
        )
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
}
