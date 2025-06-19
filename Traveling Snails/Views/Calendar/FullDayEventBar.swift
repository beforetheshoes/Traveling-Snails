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
    let timeColumnWidth: CGFloat
    
    private var calendar: Calendar { Calendar.current }
    
    #if os(iOS)
    private var isCompact: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    #else
    private var isCompact: Bool { false }
    #endif
    
    init(wrapper: ActivityWrapper, weekDates: [Date], onTap: @escaping () -> Void, timeColumnWidth: CGFloat = 50) {
        self.wrapper = wrapper
        self.weekDates = weekDates
        self.onTap = onTap
        self.timeColumnWidth = timeColumnWidth
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Time column spacer
            if timeColumnWidth > 0 {
                Color.clear
                    .frame(width: timeColumnWidth)
            }
            
            // Single unified event bar spanning all event days
            unifiedEventBar
        }
    }
    
    private var unifiedEventBar: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dayWidth = totalWidth / CGFloat(weekDates.count)
            
            // Calculate which days the event spans and their positions
            let spanningDays = weekDates.enumerated().compactMap { index, date -> (index: Int, date: Date)? in
                eventSpansDate(date) ? (index, date) : nil
            }
            
            if !spanningDays.isEmpty {
                let startIndex = spanningDays.first!.index
                let endIndex = spanningDays.last!.index
                let barWidth = CGFloat(endIndex - startIndex + 1) * dayWidth
                let barXOffset = CGFloat(startIndex) * dayWidth
                
                Button(action: onTap) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(wrapper.type.color)
                        .frame(width: barWidth, height: eventBarHeight)
                        .overlay(
                            unifiedEventContent
                        )
                }
                .buttonStyle(.plain)
                .offset(x: barXOffset)
            }
        }
        .frame(height: eventBarHeight)
    }
    
    private var unifiedEventContent: some View {
        HStack {
            // Start time on left - only show if event starts within visible range
            if eventStartsInVisibleRange {
                VStack(alignment: .leading, spacing: 2) {
                    if !isCompact {
                        Text(wrapper.tripActivity.start, style: .time)
                            .font(subtitleFont)
                            .foregroundColor(.white.opacity(0.9))
                            .fontWeight(.medium)
                    } else {
                        Text(wrapper.tripActivity.start, style: .time)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            } else {
                // Show continuation indicator if event started before visible range
                VStack(alignment: .leading, spacing: 2) {
                    Text("←")
                        .font(isCompact ? .caption2 : subtitleFont)
                        .foregroundColor(.white.opacity(0.7))
                        .fontWeight(.medium)
                }
            }
            
            Spacer()
            
            // Event title in center
            VStack(spacing: 1) {
                Text(wrapper.tripActivity.name)
                    .font(isCompact ? .caption : .callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                
                if !isCompact && eventSpansMultipleDays {
                    Text("\(eventDurationText)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            // End time on right - only show if event ends within visible range
            if eventEndsInVisibleRange {
                VStack(alignment: .trailing, spacing: 2) {
                    if !isCompact {
                        Text(wrapper.tripActivity.end, style: .time)
                            .font(subtitleFont)
                            .foregroundColor(.white.opacity(0.9))
                            .fontWeight(.medium)
                    } else {
                        Text(wrapper.tripActivity.end, style: .time)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            } else {
                // Show continuation indicator if event continues beyond visible range
                VStack(alignment: .trailing, spacing: 2) {
                    Text("→")
                        .font(isCompact ? .caption2 : subtitleFont)
                        .foregroundColor(.white.opacity(0.7))
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.horizontal, contentPadding)
    }
    
    // MARK: - Computed Properties
    
    private var eventBarHeight: CGFloat {
        isCompact ? 32 : 44
    }
    
    private var subtitleFont: Font {
        isCompact ? .caption2 : .caption
    }
    
    private var contentPadding: CGFloat {
        isCompact ? 6 : 12
    }
    
    private var eventSpansMultipleDays: Bool {
        let startDay = calendar.startOfDay(for: wrapper.tripActivity.start)
        let endDay = calendar.startOfDay(for: wrapper.tripActivity.end)
        return startDay != endDay
    }
    
    private var eventStartsInVisibleRange: Bool {
        weekDates.contains { date in
            calendar.isDate(wrapper.tripActivity.start, inSameDayAs: date)
        }
    }
    
    private var eventEndsInVisibleRange: Bool {
        weekDates.contains { date in
            calendar.isDate(wrapper.tripActivity.end, inSameDayAs: date)
        }
    }
    
    private var eventDurationText: String {
        if eventSpansMultipleDays {
            let startDate = wrapper.tripActivity.start
            let endDate = wrapper.tripActivity.end
            let daysDifference = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            
            if daysDifference == 0 {
                return "Same day"
            } else if daysDifference == 1 {
                return "2 days"
            } else {
                return "\(daysDifference + 1) days"
            }
        }
        return ""
    }
    
    // MARK: - Helper Methods
    
    private func eventSpansDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        return wrapper.tripActivity.start < endOfDay && wrapper.tripActivity.end > startOfDay
    }
}

// MARK: - Compact Version for Minimal Calendar Views

struct CompactFullDayEventBar: View {
    let wrapper: ActivityWrapper
    let visibleDates: [Date]
    let onTap: () -> Void
    
    var body: some View {
        FullDayEventBar(
            wrapper: wrapper,
            weekDates: visibleDates,
            onTap: onTap,
            timeColumnWidth: 0 // No time column in compact view
        )
    }
}
