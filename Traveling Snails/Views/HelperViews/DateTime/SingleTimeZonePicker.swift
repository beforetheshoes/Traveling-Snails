//
//  SingleTimeZonePicker.swift
//  Traveling Snails
//
//

import SwiftUI

struct SingleTimeZonePicker: View {
    private enum ActiveSheet: Identifiable {
        case picker
        var id: Int { 0 }
    }

    @Binding var selectedTimeZoneId: String
    let address: Address?

    @State private var activeSheet: ActiveSheet?
    @State private var detectedTimeZone: TimeZone?
    @State private var isDetectingTimeZone = false
    @State private var hasDetectedFromAddress = false
    @State private var hasUserMadeManualSelection = false
    @State private var detectionRequestID: UUID?

    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Timezone")
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                        .foregroundStyle(.blue)
                    }
                }

                Spacer()

                Button("Change") {
                    activeSheet = .picker
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.systemGray6)
            .clipShape(.rect(cornerRadius: 8))
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .picker:
                NavigationStack {
                    TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
                        .navigationTitle("Select Timezone")
                }
            }
        }
        .onAppear {
            if !hasUserMadeManualSelection {
                requestTimeZoneDetection()
            }
        }
        .onChange(of: address) { _, _ in
            if !hasUserMadeManualSelection {
                requestTimeZoneDetection()
            }
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            if oldValue != newValue {
                hasUserMadeManualSelection = true
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
        if let detectedTZ = timeZone,
           selectedTimeZoneId == TimeZone.current.identifier,
           !hasUserMadeManualSelection {
            selectedTimeZoneId = detectedTZ.identifier
            hasDetectedFromAddress = true
        }
    }
}
