//
//  SingleTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct SingleTimeZonePicker: View {
    @Binding var selectedTimeZoneId: String
    let address: Address?

    @State private var showingSheet = false
    @State private var detectedTimeZone: TimeZone?
    @State private var isDetectingTimeZone = false
    @State private var hasDetectedFromAddress = false
    @State private var hasUserMadeManualSelection = false

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timezone")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if isDetectingTimeZone {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                        .font(.body)

                    // Show detected timezone suggestion if available
                    if let detectedTZ = detectedTimeZone,
                       detectedTZ.identifier != selectedTimeZoneId,
                       !hasDetectedFromAddress,
                       !hasUserMadeManualSelection {
                        Button("Use detected: \(TimeZoneHelper.formatTimeZone(detectedTZ))") {
                            selectedTimeZoneId = detectedTZ.identifier
                            hasDetectedFromAddress = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }

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
                    .navigationTitle("Select Timezone")
            }
        }
        .onAppear {
            if !hasUserMadeManualSelection {
                detectTimeZoneFromAddress()
            }
        }
        .onChange(of: address) { _, _ in
            if !hasUserMadeManualSelection {
                detectTimeZoneFromAddress()
            }
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            if oldValue != newValue {
                hasUserMadeManualSelection = true
            }
        }
    }

    private func detectTimeZoneFromAddress() {
        guard let address = address, !hasDetectedFromAddress, !hasUserMadeManualSelection else { return }

        isDetectingTimeZone = true

        Task {
            let timeZone = await TimeZoneHelper.getTimeZone(from: address)

            await MainActor.run {
                isDetectingTimeZone = false
                detectedTimeZone = timeZone

                // Auto-apply detected timezone only if user hasn't manually selected one
                if let detectedTZ = timeZone,
                   selectedTimeZoneId == TimeZone.current.identifier,
                   !hasUserMadeManualSelection {
                    selectedTimeZoneId = detectedTZ.identifier
                    hasDetectedFromAddress = true
                }
            }
        }
    }
}
