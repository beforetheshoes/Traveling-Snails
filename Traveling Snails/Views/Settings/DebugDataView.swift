//
//  DebugDataView.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

struct DebugDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTrips: [Trip]
    @Query private var allOrganizations: [Organization]
    @Query private var allActivities: [Activity]
    @Query private var allLodging: [Lodging]
    @Query private var allTransportation: [Transportation]
    
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
                    _ = Organization.ensureUniqueNoneOrganization(in: modelContext)
                }
            }
            .navigationTitle("Debug Data")
        }
    }
    
    private func createTestData() {
        let trip = Trip(name: "Debug Test Trip")
        modelContext.insert(trip)
        
        let org = Organization.ensureUniqueNoneOrganization(in: modelContext)
        
        let activity = Activity(
            name: "Debug Test Activity",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        
        modelContext.insert(activity)
        
        do {
            try modelContext.save()
            print("✅ Created test data")
        } catch {
            print("❌ Error creating test data: \(error)")
        }
    }
}
