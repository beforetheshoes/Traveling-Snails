//
//  UniversalAddTripActivityRootView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct UniversalAddTripActivityRootView: View {
    let store: StoreOf<UniversalActivityFormFeature>
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, activityType: ActivityType) {
        self.store = Store(initialState: UniversalActivityFormFeature.State(trip: trip, activityType: activityType)) {
            UniversalActivityFormFeature()
        }
    }

    var body: some View {
        NavigationStack {
            UniversalAddActivityFormContent(store: store)
                .navigationTitle("Add \(store.state.activityType.displayName)")
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
}
