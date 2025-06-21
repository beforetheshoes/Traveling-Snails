//
//  UniversalAddTripActivityRootView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import SwiftUI
import SwiftData

struct UniversalAddTripActivityRootView: View {
    let trip: Trip
    let activityType: ActivityType
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            UniversalAddActivityFormContent(
                viewModel: UniversalActivityFormViewModel(
                    trip: trip,
                    activityType: activityType,
                    modelContext: modelContext
                )
            )
            .navigationTitle("Add \(activityType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Factory Methods for Backwards Compatibility

extension UniversalAddTripActivityRootView {
    static func forActivity(trip: Trip) -> UniversalAddTripActivityRootView {
        UniversalAddTripActivityRootView(trip: trip, activityType: .activity)
    }
    
    static func forLodging(trip: Trip) -> UniversalAddTripActivityRootView {
        UniversalAddTripActivityRootView(trip: trip, activityType: .lodging)
    }
    
    static func forTransportation(trip: Trip) -> UniversalAddTripActivityRootView {
        UniversalAddTripActivityRootView(trip: trip, activityType: .transportation)
    }
}

#Preview {
    UniversalAddTripActivityRootView(
        trip: Trip(name: "Test Trip"),
        activityType: .activity
    )
    .modelContainer(for: [Trip.self, Activity.self, Organization.self], inMemory: true)
}
