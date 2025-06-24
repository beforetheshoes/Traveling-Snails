//
//  DayDetailView.swift
//  Traveling Snails
//
//

import SwiftUI

struct DayDetailView: View {
    let date: Date
    let activities: [ActivityWrapper]
    let trip: Trip
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingActivityCreation = false
    
    private var sortedActivities: [ActivityWrapper] {
        activities.sorted { $0.tripActivity.start < $1.tripActivity.start }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(date, style: .date)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button {
                                showingActivityCreation = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        HStack {
                            Text("\(activities.count) activities")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !activities.isEmpty {
                                let totalDuration = activities.reduce(0) { $0 + $1.tripActivity.duration() }
                                let hours = Int(totalDuration) / 3600
                                let minutes = (Int(totalDuration) % 3600) / 60
                                
                                Text("\(hours)h \(minutes)m total")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if activities.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No Activities",
                            systemImage: "calendar",
                            description: Text("No activities scheduled for this day")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section("Timeline") {
                        ForEach(sortedActivities) { wrapper in
                            ActivityTimelineRow(wrapper: wrapper)
                        }
                    }
                }
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingActivityCreation) {
                NavigationStack {
                    PrefilledAddActivityView(
                        trip: trip,
                        activityType: Activity.self,
                        startTime: Calendar.current.startOfDay(for: date),
                        endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date
                    )
                }
            }
        }
    }
}
