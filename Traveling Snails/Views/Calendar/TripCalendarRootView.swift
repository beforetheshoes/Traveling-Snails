//
//  TripCalendarRootView.swift
//  Traveling Snails
//
//

import SwiftUI

/// Root view for trip calendar - coordinates ViewModel and handles dependencies
struct TripCalendarRootView: View {
    let trip: Trip
    
    @State private var viewModel: CalendarViewModel
    
    init(trip: Trip) {
        self.trip = trip
        self._viewModel = State(wrappedValue: CalendarViewModel(trip: trip))
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            CalendarContentView(viewModel: viewModel)
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
