//
//  ActivityRowView.swift
//  Traveling Snails
//
//

import SwiftUI

struct ActivityRowView: View {
    let wrapper: ActivityWrapper
    
    private var hasAttachments: Bool {
        switch wrapper.tripActivity {
        case let activity as Activity:
            return activity.hasAttachments
        case let lodging as Lodging:
            return lodging.hasAttachments
        case let transportation as Transportation:
            return transportation.hasAttachments
        default:
            return false
        }
    }
    
    private var attachmentCount: Int {
        switch wrapper.tripActivity {
        case let activity as Activity:
            return activity.attachmentCount
        case let lodging as Lodging:
            return lodging.attachmentCount
        case let transportation as Transportation:
            return transportation.attachmentCount
        default:
            return 0
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Image(systemName: wrapper.type.icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(wrapper.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Attachment indicator
                if hasAttachments {
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 8))
                                        .foregroundColor(wrapper.type.color)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 44, height: 44)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(wrapper.tripActivity.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if hasAttachments {
                        Text("(\(attachmentCount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label(formatDate(wrapper.tripActivity.start), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lodging = wrapper.tripActivity as? Lodging {
                        let nights = Calendar.current.dateComponents([.day], from: lodging.start, to: lodging.end).day ?? 0
                        Text("• \(nights) night\(nights == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("• \(formatTime(wrapper.tripActivity.start)) - \(formatTime(wrapper.tripActivity.end))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
                                        
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
