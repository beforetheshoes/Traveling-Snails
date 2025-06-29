//
//  CompactDayView.swift
//  Traveling Snails
//
//

import SwiftUI

struct CompactDayView: View {
    let date: Date
    let activities: [ActivityWrapper]
    let onActivityTap: (any TripActivityProtocol) -> Void

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 8) {
            // Day header - fixed height
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(calendar.component(.day, from: date))")
                    .font(.title2)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(isToday ? .white : .primary)
                    .frame(width: 36, height: 36)
                    .background(isToday ? Color.blue : Color.clear)
                    .clipShape(Circle())
            }
            .frame(height: 60) // Fixed header height

            // Activities (excluding full-day events) - flexible height
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(activities.filter { !isFullDayEvent($0) }.sorted { $0.tripActivity.start < $1.tripActivity.start }) { wrapper in
                        Button {
                            onActivityTap(wrapper.tripActivity)
                        } label: {
                            CompactActivityView(wrapper: wrapper)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Take all available space
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Take full container size
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(activities.isEmpty ? Color.clear : Color(.systemGray6))
                .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
        )
    }

    // Add this helper function
    private func isFullDayEvent(_ wrapper: ActivityWrapper) -> Bool {
        let calendar = Calendar.current
        let start = wrapper.tripActivity.start
        let end = wrapper.tripActivity.end

        if wrapper.type == .lodging {
            return true
        }

        let startOfDay = calendar.startOfDay(for: start)
        let duration = end.timeIntervalSince(start)

        return start == startOfDay && duration >= 12 * 3600
    }
}
