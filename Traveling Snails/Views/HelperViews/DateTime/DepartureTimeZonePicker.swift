//
//  DepartureTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct DepartureTimeZonePicker: View {
    @Binding var selectedTimeZoneId: String
    @State private var showingSheet = false

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Departure Timezone")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                    .font(.body)

                Spacer()

                Button("Change") {
                    showingSheet = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingSheet) {
            NavigationStack {
                TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
                    .navigationTitle("Departure Timezone")
            }
        }
    }
}
