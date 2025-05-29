//
//  TripsNavigationView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import SwiftData

struct TripsNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var selectedTrip: Trip?
    @State private var showingAddTrip = false
    @State private var navigationPath = NavigationPath()
    
    @Binding var selectedTab: Int
    let tabIndex: Int
    
    var body: some View {
        NavigationSplitView {
            NavigationStack(path: $navigationPath) {
                List(trips, selection: $selectedTrip) { trip in
                    NavigationLink(value: trip) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.name)
                                .font(.headline)
                            
                            HStack {
                                Text("\(trip.transportation.count) transportation")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("\(trip.lodging.count) lodging")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Trips")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddTrip) {
                    NavigationStack {
                        AddTrip()
                    }
                }
            }
        } detail: {
            // Detail View - Selected Trip
            if let selectedTrip = selectedTrip {
                TripDetailView(trip: selectedTrip)
            } else {
                ContentUnavailableView(
                    "Select a Trip",
                    systemImage: "suitcase",
                    description: Text("Choose a trip from the sidebar to view its details")
                )
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == tabIndex && oldValue == tabIndex {
                navigationPath = NavigationPath()
                selectedTrip = nil
            }
        }
    }
}
