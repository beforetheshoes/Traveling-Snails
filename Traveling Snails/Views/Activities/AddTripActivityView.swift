//
//  AddTripActivityView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct AddTripActivityView: View {
    @State private var store: StoreOf<TripActivityFormFeature>
    @Environment(\.dismiss) private var dismiss

    init(
        trip: Trip,
        activityType: ActivityType,
        store: StoreOf<TripActivityFormFeature>? = nil
    ) {
        let resolvedStore = store ?? Store(initialState: TripActivityFormFeature.State(trip: trip, activityType: activityType)) {
            TripActivityFormFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        NavigationStack {
            AddTripActivityFormView(store: store)
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

extension AddTripActivityView {
    static func forActivity(trip: Trip) -> AddTripActivityView {
        AddTripActivityView(trip: trip, activityType: .activity)
    }

    static func forLodging(trip: Trip) -> AddTripActivityView {
        AddTripActivityView(trip: trip, activityType: .lodging)
    }

    static func forTransportation(trip: Trip) -> AddTripActivityView {
        AddTripActivityView(trip: trip, activityType: .transportation)
    }
}

#Preview {
    AddTripActivityView(
        trip: Trip(name: "Test Trip"),
        activityType: .activity
    )
}
