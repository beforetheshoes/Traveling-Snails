//
//  CompactActivityView.swift
//  Traveling Snails
//
//

import SwiftUI
import Foundation

struct CompactActivityView: View {
    let wrapper: ActivityWrapper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(wrapper.type.color)
                    .frame(width: 6, height: 6)
                
                Text(timeWithTimezone(wrapper.tripActivity.start, timezone: wrapper.tripActivity.startTZ))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(wrapper.tripActivity.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(wrapper.type.color.opacity(0.1))
        )
    }
    
    private func timeWithTimezone(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        let timeString = formatter.string(from: date)
        let abbreviation = TimeZoneHelper.getAbbreviation(for: timezone)
        return "\(timeString) \(abbreviation)"
    }
}
