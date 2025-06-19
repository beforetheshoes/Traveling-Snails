//
//  FullDayEventBar.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI

struct FullDayEventBar: View {
    let wrapper: ActivityWrapper
    let weekDates: [Date]
    let onTap: () -> Void
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        HStack(spacing: 1) {
            // Time column spacer
            Color.clear
                .frame(width: 50)
            
            // Event bars across days
            HStack(spacing: 1) {
                ForEach(weekDates, id: \.self) { date in
                    if eventSpansDate(date) {
                        Button(action: onTap) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(wrapper.type.color)
                                .frame(height: 32)
                                .overlay(
                                    HStack {
                                        if isEventStart(date) {
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
                                        } else if isEventEnd(date) {
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
                                        } else if eventSpansDate(date) {
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
                                    .padding(.horizontal, 4)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }
    
    private func eventSpansDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return wrapper.tripActivity.start < endOfDay && wrapper.tripActivity.end > startOfDay
    }
    
    private func isEventStart(_ date: Date) -> Bool {
        calendar.isDate(wrapper.tripActivity.start, inSameDayAs: date)
    }
    
    private func isEventEnd(_ date: Date) -> Bool {
        calendar.isDate(wrapper.tripActivity.end, inSameDayAs: date)
    }
}
