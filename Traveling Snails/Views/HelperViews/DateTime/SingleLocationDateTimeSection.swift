//
//  SingleLocationDateTimeSection.swift
//  Traveling Snails
//
//

import SwiftUI

struct SingleLocationDateTimeSection: View {
    let startLabel: String
    let endLabel: String
    let activityType: ActivityWrapper.ActivityType
    let trip: Trip
    
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var timeZoneId: String // Single timezone for both start and end
    
    let address: Address?
    
    var selectedTimeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? TimeZone.current
    }
    
    var sectionIcon: String {
        switch activityType {
        case .lodging: return "🏨"
        case .activity: return "🎟️"
        case .transportation: return "🚗" // Won't be used but included for completeness
        }
    }
    
    var sectionColor: Color {
        switch activityType {
        case .lodging: return .indigo
        case .activity: return .purple
        case .transportation: return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
//            Text("\(sectionIcon) Schedule")
//                .font(.headline)
//                .foregroundColor(sectionColor)
            
            VStack(spacing: 16) {
                // Start Date/Time - FIX: Add timezone environment
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(startLabel, selection: $startDate)
                        .environment(\.timeZone, selectedTimeZone)
                }
                
                // End Date/Time - FIX: Add timezone environment
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker(endLabel, selection: $endDate)
                        .environment(\.timeZone, selectedTimeZone)
                }
                
                Divider()
                
                // Single Timezone Picker
                SingleTimeZonePicker(
                    selectedTimeZoneId: $timeZoneId,
                    address: address
                )
            }
        }
        .padding()
        .background(sectionColor.opacity(0.05))
        .cornerRadius(12)
    }
}
