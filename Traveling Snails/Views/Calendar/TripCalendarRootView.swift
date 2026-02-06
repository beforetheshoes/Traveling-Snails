//
//  TripCalendarRootView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

/// Root view for trip calendar - coordinates ViewModel and handles dependencies
struct TripCalendarRootView: View {
    @Bindable var store: StoreOf<CalendarFeature>

    init(trip: Trip) {
        self.store = Store(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }
    }

    var body: some View {
        NavigationStack(path: $store.navigationPath) {
            CalendarContentView(store: store)
                .navigationDestination(for: DestinationType.self) { destination in
                    switch destination {
                    case .lodging(let lodging):
                        UnifiedTripActivityDetailView<Lodging>(activity: lodging)
                    case .transportation(let transportation):
                        UnifiedTripActivityDetailView<Transportation>(activity: transportation)
                    case .activity(let activity):
                        UnifiedTripActivityDetailView<Activity>(activity: activity)
                    }
                }
        }
    }
}

#Preview {
    let trip = Trip(name: "Sample Trip")
    TripCalendarRootView(trip: trip)
}
