//
//  CompactActivityView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI

struct CompactActivityView: View {
    let wrapper: ActivityWrapper
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(wrapper.type.color)
                    .frame(width: 6, height: 6)
                
                Text(wrapper.tripActivity.start, style: .time)
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
}
