//
//  SimpleTimeZonePicker.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/31/25.
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
                    print("DEBUG: \(label) - Change button tapped")
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
            print("DEBUG: \(label) - Sheet dismissed")
        } content: {
            TimeZonePickerSheet(selectedTimeZoneId: $selectedTimeZoneId)
        }
        .onChange(of: selectedTimeZoneId) { oldValue, newValue in
            print("DEBUG: \(label) - Timezone changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: showingAllTimeZones) { oldValue, newValue in
            print("DEBUG: \(label) - Sheet state changed from \(oldValue) to \(newValue)")
        }
    }
}
