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
        store: StoreOf<TripActivityFormFeature>
    ) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        NavigationStack {
            AddTripActivityFormView(store: store)
                .navigationTitle("Add \(store.state.activityType.displayName)")
                .inlineNavigationBarTitle()
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
        AddTripActivityView(
            store: StoreOf<TripActivityFormFeature>.init(initialState: TripActivityFormFeature.State(trip: trip, activityType: .activity)) {
                TripActivityFormFeature()
            }
        )
    }

    static func forLodging(trip: Trip) -> AddTripActivityView {
        AddTripActivityView(
            store: StoreOf<TripActivityFormFeature>.init(initialState: TripActivityFormFeature.State(trip: trip, activityType: .lodging)) {
                TripActivityFormFeature()
            }
        )
    }

    static func forTransportation(trip: Trip) -> AddTripActivityView {
        AddTripActivityView(
            store: StoreOf<TripActivityFormFeature>.init(initialState: TripActivityFormFeature.State(trip: trip, activityType: .transportation)) {
                TripActivityFormFeature()
            }
        )
    }
}

#Preview {
    AddTripActivityView(
        store: StoreOf<TripActivityFormFeature>.init(initialState: TripActivityFormFeature.State(trip: Trip(name: "Test Trip"), activityType: .activity)) {
            TripActivityFormFeature()
        }
    )
}
