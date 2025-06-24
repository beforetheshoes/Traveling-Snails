//
//  ActivityTimelineRow.swift
//  Traveling Snails
//
//

import SwiftUI

struct ActivityTimelineRow: View {
    let wrapper: ActivityWrapper
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(wrapper.tripActivity.start, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Rectangle()
                    .fill(wrapper.type.color)
                    .frame(width: 2, height: 20)
                
                Text(wrapper.tripActivity.end, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            
            // Activity content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: wrapper.type.icon)
                        .foregroundColor(wrapper.type.color)
                        .font(.caption)
                    
                    Text(wrapper.tripActivity.name)
                        .font(.headline)
                        .lineLimit(2)
                }
                
                if let organization = wrapper.tripActivity.organization, !organization.isNone {
                    Text(organization.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    let duration = wrapper.tripActivity.duration()
                    let hours = Int(duration) / 3600
                    let minutes = (Int(duration) % 3600) / 60
                    
                    Text("\(hours)h \(minutes)m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if wrapper.tripActivity.cost > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(wrapper.tripActivity.cost, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
