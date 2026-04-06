//
//  TransportationDateTimeSection.swift
//  Traveling Snails
//
//

import SwiftUI

struct TransportationDateTimeSection: View {
    let trip: Trip

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var startTimeZoneId: String
    @Binding var endTimeZoneId: String

    let address: Address?

    var startTimeZone: TimeZone {
        TimeZone(identifier: startTimeZoneId) ?? TimeZone.current
    }

    var endTimeZone: TimeZone {
        TimeZone(identifier: endTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(spacing: 24) {
            // Departure Section
            VStack(alignment: .leading, spacing: 16) {
                Text("🛫 Departure")
                    .font(.headline)
                    .foregroundStyle(.blue)

                // FIX: Add timezone environment
                DatePicker("Date & Time", selection: $startDate)
                    .environment(\.timeZone, startTimeZone)

                DepartureTimeZonePicker(selectedTimeZoneId: $startTimeZoneId)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .clipShape(.rect(cornerRadius: 12))

            // Arrival Section
            VStack(alignment: .leading, spacing: 16) {
                Text("🛬 Arrival")
                    .font(.headline)
                    .foregroundStyle(.green)

                // FIX: Add timezone environment
                DatePicker("Date & Time", selection: $endDate)
                    .environment(\.timeZone, endTimeZone)

                ArrivalTimeZonePicker(selectedTimeZoneId: $endTimeZoneId)
            }
            .padding()
            .background(Color.green.opacity(0.05))
            .clipShape(.rect(cornerRadius: 12))
        }
    }
}
