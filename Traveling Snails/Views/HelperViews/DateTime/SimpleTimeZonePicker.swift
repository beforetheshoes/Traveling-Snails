//
//  SimpleTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct SimpleTimeZonePicker: View {
    private enum ActiveSheet: Identifiable {
        case allTimeZones
        var id: Int { 0 }
    }

    @Binding var selectedTimeZoneId: String
    let label: String

    @State private var activeSheet: ActiveSheet?

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Current selection display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                        .font(.body)
                }

                Spacer()

                Button("Change") {
                    Logger.shared.debug("Change button tapped for \(label)", category: .ui)
                    activeSheet = .allTimeZones
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 8))
        }
        .sheet(item: $activeSheet) { _ in
            TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            Logger.shared.debug("Timezone changed for \(label) from \(oldValue) to \(newValue)", category: .ui)
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            Logger.shared.debug(
                "Sheet state changed for \(label) from \(String(describing: oldValue)) to \(String(describing: newValue))",
                category: .ui
            )
        }
    }
}
