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
        store: StoreOf<CalendarFeature>
    ) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack(path: $store.navigationPath) {
            CalendarContentView(store: store)
                .navigationDestination(for: DestinationType.self) { destination in
                    switch destination {
                    case .lodging(let lodging):
                        TripActivityDetailView<Lodging>(
                            activity: lodging,
                            store: Store(
                                initialState: TripActivityDetailFeature.State(
                                    snapshot: TripActivityDetailFeature.ActivityTarget(activity: lodging)
                                )
                            ) {
                                TripActivityDetailFeature()
                            }
                        )
                    case .transportation(let transportation):
                        TripActivityDetailView<Transportation>(
                            activity: transportation,
                            store: Store(
                                initialState: TripActivityDetailFeature.State(
                                    snapshot: TripActivityDetailFeature.ActivityTarget(activity: transportation)
                                )
                            ) {
                                TripActivityDetailFeature()
                            }
                        )
                    case .activity(let activity):
                        TripActivityDetailView<Activity>(
                            activity: activity,
                            store: Store(
                                initialState: TripActivityDetailFeature.State(
                                    snapshot: TripActivityDetailFeature.ActivityTarget(activity: activity)
                                )
                            ) {
                                TripActivityDetailFeature()
                            }
                        )
                    }
                }
        }
    }
}

#Preview {
    let trip = Trip(name: "Sample Trip")
    TripCalendarRootView(
        store: StoreOf<CalendarFeature>.init(initialState: CalendarFeature.State(trip: trip)) {
            CalendarFeature()
        }
    )
}
