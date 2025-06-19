//
//  TimeZonePicker.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/31/25.
//

import SwiftUI

struct TimeZonePicker: View {
    @Binding var selectedTimeZoneId: String
    let address: Address?
    let label: String
    
    @State private var detectedTimeZone: TimeZone?
    @State private var isDetectingTimeZone = false
    @State private var showingAllTimeZones = false
    @State private var hasDetectedFromAddress = false
    @State private var hasUserMadeManualSelection = false // Track manual selections
    
    var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? TimeZone.current
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Button("Change") {
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
            TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
        }
        .onAppear {
            // Only detect timezone on initial appearance if no manual selection has been made
            if !hasUserMadeManualSelection {
                detectTimeZoneFromAddress()
            }
        }
        .onChange(of: address) { _, _ in
            // Only auto-detect if user hasn't made a manual selection
            if !hasUserMadeManualSelection {
                detectTimeZoneFromAddress()
            }
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            // Track when timezone changes (indicating user selection)
            if oldValue != newValue {
                hasUserMadeManualSelection = true
            }
        }
        .onChange(of: showingAllTimeZones) { _, isShowing in
            // When the timezone picker sheet is dismissed, mark as manual selection
            if !isShowing && hasUserMadeManualSelection {
                // User closed the picker, so they likely made a selection
                hasDetectedFromAddress = true
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
                // and we're still using the default timezone
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
