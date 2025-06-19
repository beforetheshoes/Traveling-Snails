//
//  DateTimeZoneSection.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/31/25.
//

import SwiftUI

struct DateTimeZoneSection: View {
    let startLabel: String
    let endLabel: String
    var trip: Trip
    let syncTimezones: Bool // New parameter to control timezone syncing
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var startTimeZoneId: String
    @Binding var endTimeZoneId: String
    
    let address: Address?
    
    @State private var hasUserSetEndTimeZone = false
    
    init(
        startLabel: String,
        endLabel: String,
        trip: Trip,
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        startTimeZoneId: Binding<String>,
        endTimeZoneId: Binding<String>,
        address: Address?,
        syncTimezones: Bool = true // Default to true for backward compatibility
    ) {
        self.startLabel = startLabel
        self.endLabel = endLabel
        self.trip = trip
        self.syncTimezones = syncTimezones
        self._startDate = startDate
        self._endDate = endDate
        self._startTimeZoneId = startTimeZoneId
        self._endTimeZoneId = endTimeZoneId
        self.address = address
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Start Date/Time
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(startLabel, selection: $startDate)
                
                TimeZonePicker(
                    selectedTimeZoneId: $startTimeZoneId,
                    address: address,
                    label: "\(startLabel) Timezone"
                )
            }
            
            // End Date/Time
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(endLabel, selection: $endDate)
                
                TimeZonePicker(
                    selectedTimeZoneId: $endTimeZoneId,
                    address: address,
                    label: "\(endLabel) Timezone"
                )
            }
        }
        .onChange(of: startTimeZoneId) { oldValue, newValue in
            // Only auto-sync end timezone to start timezone if:
            // 1. syncTimezones is enabled
            // 2. User hasn't manually set a different end timezone
            // 3. The values actually changed (avoid infinite loops)
            // 4. We're not currently in the middle of a user selection
            if syncTimezones && !hasUserSetEndTimeZone && oldValue != newValue && endTimeZoneId != newValue {
                print("DEBUG: Syncing end timezone from \(endTimeZoneId) to \(newValue)")
                endTimeZoneId = newValue
            } else {
                print("DEBUG: NOT syncing timezones - syncTimezones: \(syncTimezones), hasUserSetEndTimeZone: \(hasUserSetEndTimeZone), oldValue: \(oldValue), newValue: \(newValue), endTimeZoneId: \(endTimeZoneId)")
            }
        }
        .onChange(of: endTimeZoneId) { oldValue, newValue in
            // Track when user manually changes end timezone
            // Only relevant when syncTimezones is enabled and the values actually changed
            if syncTimezones && oldValue != newValue && newValue != startTimeZoneId {
                print("DEBUG: User manually set end timezone to \(newValue)")
                hasUserSetEndTimeZone = true
            }
        }
    }
}
