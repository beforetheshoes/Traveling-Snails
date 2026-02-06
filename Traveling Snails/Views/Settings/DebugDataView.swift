//
//  DebugDataView.swift
//  Traveling Snails
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct DebugDataView: View {
    @Dependency(\.defaultDatabase) private var database
    @FetchAll private var allTrips: [Trip]
    @FetchAll private var allOrganizations: [Organization]
    @FetchAll private var allActivities: [Activity]
    @FetchAll private var allLodging: [Lodging]
    @FetchAll private var allTransportation: [Transportation]

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
                    createTestData()
                }

                Button("Fix None Organizations") {
                    ensureNoneOrganization()
                }
            }
            .navigationTitle("Debug Data")
        }
    }

    private func createTestData() {
        do {
            let trip = Trip(name: "Debug Test Trip")
            let org = ensureNoneOrganization()
            let activity = Activity(
                name: "Debug Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            try database.write { db in
                try Trip.upsert { trip }.execute(db)
                try Organization.upsert { org }.execute(db)
                try Activity.upsert { activity }.execute(db)
            }
            #if DEBUG
            Logger.shared.info("Created test data", category: .debug)
            #endif
        } catch {
            Logger.shared.error("Error creating test data: \(error.localizedDescription)", category: .debug)
        }
    }

    @discardableResult
    private func ensureNoneOrganization() -> Organization {
        do {
            if let existing = try database.read({ db in
                try Organization.where { $0.name.eq("None") }.fetchOne(db)
            }) {
                return existing
            }

            let noneOrg = Organization(name: "None")
            try database.write { db in
                try Organization.insert { noneOrg }.execute(db)
            }
            return noneOrg
        } catch {
            Logger.shared.error("Error ensuring None organization: \(error.localizedDescription)", category: .database)
            return Organization(name: "None")
        }
    }
}
