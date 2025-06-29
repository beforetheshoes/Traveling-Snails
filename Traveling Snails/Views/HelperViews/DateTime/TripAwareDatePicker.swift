//
//  TripAwareDatePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct TripAwareDatePicker: View {
    let title: String
    @Binding var selection: Date
    let trip: Trip
    let displayedComponents: DatePicker.Components

    init(
        _ title: String,
        selection: Binding<Date>,
        trip: Trip,
        displayedComponents: DatePicker.Components = [.date, .hourAndMinute]
    ) {
        self.title = title
        self._selection = selection
        self.trip = trip
        self.displayedComponents = displayedComponents
    }

    private var dateRange: ClosedRange<Date>? {
        // Only constrain dates if the trip has BOTH start and end dates
        guard trip.hasDateRange,
              let tripRange = trip.dateRange else { return nil }

        return tripRange
    }

    private var shouldShowWarning: Bool {
        guard let range = dateRange else { return false }
        return !range.contains(selection)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let range = dateRange {
                DatePicker(
                    title,
                    selection: $selection,
                    in: range,
                    displayedComponents: displayedComponents
                )
            } else {
                DatePicker(
                    title,
                    selection: $selection,
                    displayedComponents: displayedComponents
                )
            }

            // Show helpful context about date constraints
            if let range = dateRange {
                Text("Limited to trip dates: \(formatDateRange(range))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if trip.hasStartDate || trip.hasEndDate {
                Text(partialRangeText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var partialRangeText: String {
        var rangeText = "Trip dates: "
        if trip.hasStartDate {
            rangeText += formatDate(trip.startDate)
        } else {
            rangeText += "No start"
        }
        rangeText += " - "
        if trip.hasEndDate {
            rangeText += formatDate(trip.endDate)
        } else {
            rangeText += "No end"
        }
        rangeText += " (partial range - no date restrictions)"
        return rangeText
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatDateRange(_ range: ClosedRange<Date>) -> String {
        "\(formatDate(range.lowerBound)) to \(formatDate(range.upperBound))"
    }
}
