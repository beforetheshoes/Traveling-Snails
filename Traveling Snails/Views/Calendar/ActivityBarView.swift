//
//  ActivityBarView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import SwiftUI

struct ActivityBarView: View {
    let wrapper: ActivityWrapper
    let hour: Int
    let date: Date
    let offset: CGFloat
    
    private var activityHeight: CGFloat {
        let duration = wrapper.tripActivity.duration()
        return min(60, max(15, CGFloat(duration / 3600) * 60))
    }
    
    private var activityStartOffset: CGFloat {
        let hourStart = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let activityStart = wrapper.tripActivity.start
        let minutesFromHourStart = activityStart.timeIntervalSince(hourStart) / 60
        return CGFloat(minutesFromHourStart / 60) * 60 // Convert to pixels
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(wrapper.type.color)
            .frame(height: activityHeight)
            .offset(x: offset, y: activityStartOffset)
            .overlay(
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(wrapper.tripActivity.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(wrapper.tripActivity.start, style: .time)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            )
            .padding(.leading, 4)
    }
}
