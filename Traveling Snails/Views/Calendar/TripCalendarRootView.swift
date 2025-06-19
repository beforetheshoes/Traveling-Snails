//
//  TripCalendarRootView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
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
        NavigationStack {
            CalendarContentView(viewModel: viewModel)
        }
    }
}

#Preview {
    let trip = Trip(name: "Sample Trip")
    TripCalendarRootView(trip: trip)
}
