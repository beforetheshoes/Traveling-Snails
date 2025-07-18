//
//  UniversalAddTripActivityRootView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct UniversalAddTripActivityRootView: View {
    let trip: Trip
    let activityType: ActivityType
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // FIX: Create view model once using @State instead of recreating on every view update
    @State private var viewModel: UniversalActivityFormViewModel?

    var body: some View {
        NavigationStack {
            if let viewModel = viewModel {
                UniversalAddActivityFormContent(viewModel: viewModel)
                    .navigationTitle("Add \(activityType.displayName)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                    }
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        // Create view model only once
                        viewModel = UniversalActivityFormViewModel(
                            trip: trip,
                            activityType: activityType,
                            modelContext: modelContext
                        )
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
