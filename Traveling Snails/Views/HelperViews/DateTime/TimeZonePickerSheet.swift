//
//  TimeZonePickerSheet.swift
//  Traveling Snails
//
//

import SwiftUI

struct TimeZonePickerSheet: View {
    @Binding var selectedTimeZoneId: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var showingAllTimeZones = false

    var commonTimeZones: [TimeZone] {
        TimeZoneHelper.commonTimeZones
    }

    var filteredCommonTimeZones: [TimeZone] {
        if searchText.isEmpty {
            return commonTimeZones
        }
        return commonTimeZones.filter { timeZone in
            timeZone.identifier.localizedCaseInsensitiveContains(searchText) ||
            TimeZoneHelper.formatTimeZone(timeZone).localizedCaseInsensitiveContains(searchText)
        }
    }

    var filteredAllTimeZones: [String: [TimeZone]] {
        let grouped = TimeZoneHelper.groupedTimeZones
        if searchText.isEmpty {
            return grouped
        }

        var filtered: [String: [TimeZone]] = [:]
        for (region, timeZones) in grouped {
            let matchingTimeZones = timeZones.filter { timeZone in
                timeZone.identifier.localizedCaseInsensitiveContains(searchText) ||
                TimeZoneHelper.formatTimeZone(timeZone).localizedCaseInsensitiveContains(searchText)
            }
            if !matchingTimeZones.isEmpty {
                filtered[region] = matchingTimeZones
            }
        }
        return filtered
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search timezones...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)

                // Toggle between common and all timezones
                Picker("", selection: $showingAllTimeZones) {
                    Text("Common").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    if showingAllTimeZones {
                        // All timezones grouped by region
                        ForEach(filteredAllTimeZones.keys.sorted(), id: \.self) { region in
                            Section(region) {
                                ForEach(filteredAllTimeZones[region] ?? [], id: \.identifier) { timeZone in
                                    timeZoneRow(for: timeZone)
                                }
                            }
                        }
                    } else {
                        // Common timezones
                        ForEach(filteredCommonTimeZones, id: \.identifier) { timeZone in
                            timeZoneRow(for: timeZone)
                        }
                    }
                }
            }
            .navigationTitle("Select Timezone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func timeZoneRow(for timeZone: TimeZone) -> some View {
        Button {
            selectedTimeZoneId = timeZone.identifier
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeZoneHelper.formatTimeZone(timeZone))
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(timeZone.identifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if timeZone.identifier == selectedTimeZoneId {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
