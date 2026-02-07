//
//  DepartureTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct DepartureTimeZonePicker: View {
    private enum ActiveSheet: Identifiable {
        case picker
        var id: Int { 0 }
    }

    @Binding var selectedTimeZoneId: String
    @State private var activeSheet: ActiveSheet?

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Departure Timezone")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                    .font(.body)

                Spacer()

                Button("Change") {
                    activeSheet = .picker
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(.rect(cornerRadius: 8))
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .picker:
                NavigationStack {
                    TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
                        .navigationTitle("Departure Timezone")
                }
            }
        }
    }
}
