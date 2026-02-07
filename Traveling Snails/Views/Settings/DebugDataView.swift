//
//  DebugDataView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct DebugDataView: View {
    @State private var store: StoreOf<DebugDataFeature>
    @FetchAll private var allTrips: [Trip]
    @FetchAll private var allOrganizations: [Organization]
    @FetchAll private var allActivities: [Activity]
    @FetchAll private var allLodging: [Lodging]
    @FetchAll private var allTransportation: [Transportation]

    init(store: StoreOf<DebugDataFeature>? = nil) {
        let resolvedStore = store ?? Store(initialState: DebugDataFeature.State()) {
            DebugDataFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Debug Info") {
                    Text("Trips: \(allTrips.count)")
                    Text("Organizations: \(allOrganizations.count)")
                    Text("Activities: \(allActivities.count)")
                    Text("Lodging: \(allLodging.count)")
                    Text("Transportation: \(allTransportation.count)")
                }

                Section("Trips") {
                    ForEach(allTrips, id: \.id) { trip in
                        VStack(alignment: .leading) {
                            Text(trip.name.isEmpty ? "Unnamed Trip" : trip.name)
                                .font(.headline)
                            Text("Activities: \(trip.totalActivities)")
                            Text("Cost: \(trip.totalCost.description)")
                        }
                    }
                }

                Section("Organizations") {
                    ForEach(allOrganizations, id: \.id) { org in
                        VStack(alignment: .leading) {
                            Text(org.name)
                                .font(.headline)
                            Text("Transport: \(org.transportation.count)")
                            Text("Lodging: \(org.lodging.count)")
                            Text("Activities: \(org.activity.count)")
                        }
                    }
                }

                Button("Create Test Data") {
                    store.send(.createTestDataTapped)
                }

                Button("Fix None Organizations") {
                    store.send(.ensureNoneOrganizationTapped)
                }

                if !store.operationStatus.isEmpty {
                    Text(store.operationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Debug Data")
        }
    }
}
