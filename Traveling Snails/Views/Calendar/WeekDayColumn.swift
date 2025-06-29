//
//  WeekDayColumn.swift
//  Traveling Snails
//
//

import SwiftUI

struct WeekDayColumn: View {
    let date: Date
    let activities: [ActivityWrapper]
    let onDayTap: () -> Void
    let onLongPress: (CGPoint, Date) -> Void

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }

    var body: some View {
        VStack(spacing: 0) {
            // Day header
            dayHeaderView

            // Hours
            ForEach(0..<24, id: \.self) { hour in
                Rectangle()
                    .fill(Color(.systemGray6))
                    .frame(height: 60)
                    .overlay(
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                    .overlay(
                        VStack(spacing: 1) {
                            ForEach(activitiesForHour(hour), id: \.id) { wrapper in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(wrapper.type.color)
                                    .frame(height: 12)
                                    .overlay(
                                        Text(wrapper.tripActivity.name)
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .padding(.horizontal, 2)
                                    )
                            }
                        }
                        .padding(2)
                    )
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        let hourTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
                        onLongPress(.zero, hourTime)
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dayHeaderView: some View {
        Button(action: onDayTap) {
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(calendar.component(.day, from: date))")
                    .font(.headline)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(isToday ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(isToday ? Color.blue : Color.clear)
                    .clipShape(Circle())

                if !activities.isEmpty {
                    Text("\(activities.count)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .frame(height: 50)
    }

    private func activitiesForHour(_ hour: Int) -> [ActivityWrapper] {
        let startOfHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        let endOfHour = calendar.date(byAdding: .hour, value: 1, to: startOfHour) ?? startOfHour

        return activities.filter { wrapper in
            let activityStart = wrapper.tripActivity.start
            let activityEnd = wrapper.tripActivity.end
            return activityStart < endOfHour && activityEnd > startOfHour
        }
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }
}
