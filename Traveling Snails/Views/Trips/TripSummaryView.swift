//
//  TripSummaryView.swift
//  Traveling Snails
//
//

import SwiftUI

struct TripSummaryView: View {
    let trip: Trip
    let activities: [ActivityWrapper]

    private var totalCost: Decimal {
        activities.reduce(0) { $0 + $1.tripActivity.cost }
    }

    private var dateRange: ClosedRange<Date>? {
        guard !activities.isEmpty else { return nil }
        let dates = activities.flatMap { [$0.tripActivity.start, $0.tripActivity.end] }
        guard let earliest = dates.min(), let latest = dates.max() else { return nil }
        return earliest...latest
    }

    var body: some View {
        HStack(spacing: 16) {
            // Activity counts
            VStack {
                Text("\(activities.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text("Activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Sharing status
            if trip.shareID != nil {
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("Shared")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .frame(height: 30)

            // Total cost
            VStack {
                Text(totalCost, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)

                Text("Total Cost")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let range = dateRange {
                Divider()
                    .frame(height: 30)

                // Date range
                VStack {
                    HStack(spacing: 2) {
                        Text(range.lowerBound, format: .dateTime.month(.defaultDigits).day())
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("-")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(range.upperBound, format: .dateTime.month(.defaultDigits).day())
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.purple)

                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}
