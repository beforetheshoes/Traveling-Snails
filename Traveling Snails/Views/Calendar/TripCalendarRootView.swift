//
//  TripCalendarRootView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

/// Root view for trip calendar - coordinates ViewModel and handles dependencies
struct TripCalendarRootView: View {
    @State private var store: StoreOf<CalendarFeature>

    init(
        trip: Trip,
        store: StoreOf<CalendarFeature>? = nil
    ) {
        let resolvedStore = store ?? Store(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.navigationPath) {
            CalendarContentView(store: store)
                .navigationDestination(for: DestinationType.self) { destination in
                    switch destination {
                    case .lodging(let lodging):
                        TripActivityDetailView<Lodging>(activity: lodging)
                    case .transportation(let transportation):
                        TripActivityDetailView<Transportation>(activity: transportation)
                    case .activity(let activity):
                        TripActivityDetailView<Activity>(activity: activity)
                    }
                }
        }
    }
}

#Preview {
    let trip = Trip(name: "Sample Trip")
    TripCalendarRootView(trip: trip)
}
