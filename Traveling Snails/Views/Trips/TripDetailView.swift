//
//  TripDetailView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData


struct TripDetailView: View {
    let trip: Trip
    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    
    struct ActivityWrapper: Identifiable {
        let id = UUID()
        let activity: any TripActivity
        let type: String
        
        init(_ activity: any TripActivity) {
            self.activity = activity
            let fullTypeName = String(describing: Swift.type(of: activity))
            self.type = fullTypeName.components(separatedBy: ".").last ?? fullTypeName
        }
    }
    
    var allActivities: [ActivityWrapper] {
        let lodgingActivities = trip.lodging.map { ActivityWrapper($0) }
        let transportationActivities = trip.transportation.map { ActivityWrapper($0) }
        
        return (lodgingActivities + transportationActivities)
            .sorted { $0.activity.start < $1.activity.start }
    }
    
    var body: some View {
        VStack {
            if allActivities.isEmpty {
                ContentUnavailableView(
                    "No Acitivities Yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Add transportation or lodging to get started")
                )
            } else {
                List {
                    ForEach(allActivities) { wrapper in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(wrapper.activity.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(wrapper.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                            
                            HStack {
                                Text("Start: \(wrapper.activity.start, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("End: \(wrapper.activity.end, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingLodgingSheet = true
                    } label: {
                        Label("Add Lodging", systemImage: "bed.double")
                    }
                    
                    Button {
                        showingTransportationSheet = true
                    } label: {
                        Label("Add Transportation", systemImage: "airplane")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingLodgingSheet) {
            NavigationStack {
                AddLodgingView(trip: trip)
            }
        }
        .sheet(isPresented: $showingTransportationSheet) {
            NavigationStack {
                AddTransportationView(trip: trip)
            }
        }
    }
}

#Preview {
    TripDetailView(trip: .init(name: "Test Trip"))
}
