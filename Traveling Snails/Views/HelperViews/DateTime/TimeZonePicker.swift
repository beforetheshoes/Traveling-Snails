//
//  TimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct TimeZonePicker: View {
    private enum ActiveSheet: Identifiable {
        case allTimeZones
        var id: Int { 0 }
    }

    @Binding var selectedTimeZoneId: String
    let address: Address?
    let label: String

    @State private var detectedTimeZone: TimeZone?
    @State private var isDetectingTimeZone = false
    @State private var activeSheet: ActiveSheet?
    @State private var hasDetectedFromAddress = false
    @State private var hasUserMadeManualSelection = false // Track manual selections
    @State private var detectionRequestID: UUID?

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isDetectingTimeZone {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }

            // Current selection display
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(TimeZoneHelper.formatTimeZone(selectedTimeZone))
                        .font(.body)

                    // Only show detected timezone suggestion if user hasn't made manual selection
                    if let detectedTZ = detectedTimeZone,
                       detectedTZ.identifier != selectedTimeZoneId,
                       !hasDetectedFromAddress,
                       !hasUserMadeManualSelection {
                        Button("Use detected: \(TimeZoneHelper.formatTimeZone(detectedTZ))") {
                            selectedTimeZoneId = detectedTZ.identifier
                            hasDetectedFromAddress = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                Button("Change") {
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .allTimeZones:
                TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
            }
        }
        .onAppear {
            // Only detect timezone on initial appearance if no manual selection has been made
            if !hasUserMadeManualSelection {
                requestTimeZoneDetection()
            }
        }
        .onChange(of: address) { _, _ in
            // Only auto-detect if user hasn't made a manual selection
            if !hasUserMadeManualSelection {
                requestTimeZoneDetection()
            }
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            // Track when timezone changes (indicating user selection)
            if oldValue != newValue {
                hasUserMadeManualSelection = true
            }
        }
        .onChange(of: activeSheet) { _, newValue in
            // When the timezone picker sheet is dismissed, mark as manual selection
            if newValue == nil && hasUserMadeManualSelection {
                // User closed the picker, so they likely made a selection
                hasDetectedFromAddress = true
            }
        }
        .task(id: detectionRequestID) {
            await detectTimeZoneFromAddress()
        }
    }

    private func requestTimeZoneDetection() {
        detectionRequestID = UUID()
    }

    @MainActor
    private func detectTimeZoneFromAddress() async {
        guard let address = address, !hasDetectedFromAddress, !hasUserMadeManualSelection else { return }

        isDetectingTimeZone = true

        let timeZone = await TimeZoneHelper.getTimeZone(from: address)

        isDetectingTimeZone = false
        detectedTimeZone = timeZone

        // Auto-apply detected timezone only if user hasn't manually selected one
        // and we're still using the default timezone
        if let detectedTZ = timeZone,
           selectedTimeZoneId == TimeZone.current.identifier,
           !hasUserMadeManualSelection {
            selectedTimeZoneId = detectedTZ.identifier
            hasDetectedFromAddress = true
        }
    }
}
