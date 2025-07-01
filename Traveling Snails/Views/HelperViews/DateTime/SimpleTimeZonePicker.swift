//
//  SimpleTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct SimpleTimeZonePicker: View {
    @Binding var selectedTimeZoneId: String
    let label: String

    @State private var showingAllTimeZones = false

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            // Current selection display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                        .font(.body)
                }

                Spacer()

                Button("Change") {
                    Logger.shared.debug("Change button tapped for \(label)", category: .ui)
                    showingAllTimeZones = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingAllTimeZones) {
            Logger.shared.debug("Sheet dismissed for \(label)", category: .ui)
        } content: {
            TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            Logger.shared.debug("Timezone changed for \(label) from \(oldValue) to \(newValue)", category: .ui)
        }
        .onChange(of: showingAllTimeZones) { oldValue, newValue in
            Logger.shared.debug("Sheet state changed for \(label) from \(oldValue) to \(newValue)", category: .ui)
        }
    }
}
