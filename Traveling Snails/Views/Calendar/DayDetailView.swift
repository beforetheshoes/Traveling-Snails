//
//  DayDetailView.swift
//  Traveling Snails
//
//

import SwiftUI
import ComposableArchitecture

struct DayDetailView: View {
    private enum ActiveSheet: Identifiable {
        case addActivity

        var id: Int { 0 }
    }

    let date: Date
    let activities: [ActivityWrapper]
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @State private var activeSheet: ActiveSheet?

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
                                activeSheet = .addActivity
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                        }

                        HStack {
                            Text("\(activities.count) activities")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !activities.isEmpty {
                                let totalDuration = activities.reduce(0) { $0 + $1.tripActivity.duration() }
                                let hours = Int(totalDuration) / 3600
                                let minutes = (Int(totalDuration) % 3600) / 60

                                Text("\(hours)h \(minutes)m total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addActivity:
                    NavigationStack {
                        PrefilledAddActivityView(
                            trip: trip,
                            activityType: Activity.self,
                            startTime: Calendar.current.startOfDay(for: date),
                            endTime: Calendar.current.date(byAdding: .hour, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date,
                            store: Store(
                                initialState: PrefilledAddActivityFeature.State(
                                    trip: trip,
                                    activityKind: .activity,
                                    editData: TripActivityEditData(
                                        from: Activity(
                                            name: "New Activity",
                                            start: Calendar.current.startOfDay(for: date),
                                            end: Calendar.current.date(byAdding: .hour, value: 1, to: Calendar.current.startOfDay(for: date)) ?? date,
                                            trip: nil,
                                            organization: nil
                                        )
                                    )
                                )
                            ) {
                                PrefilledAddActivityFeature()
                            }
                        )
                    }
                }
            }
        }
    }
}
