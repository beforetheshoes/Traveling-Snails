//
//  CalendarContentView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct CalendarContentView: View {
    private enum ActiveSheet: Identifiable {
        case activityCreation
        case dayDetail

        var id: Int {
            switch self {
            case .activityCreation: 0
            case .dayDetail: 1
            }
        }
    }

    @Bindable var store: StoreOf<CalendarFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced header
            CalendarHeaderView(
                trip: store.trip,
                selectedDate: $store.selectedDate,
                currentWeekOffset: $store.currentWeekOffset,
                calendarMode: $store.calendarMode,
                activities: store.allActivities
            )

                // Calendar content with proper layout constraints
                GeometryReader { _ in
                    ZStack {
                        Group {
                            switch store.calendarMode {
                            case .day:
                                DayView(
                                    date: store.currentDisplayDate,
                                    activities: store.activitiesForCurrentPeriod,
                                    onDragStart: { point, time in
                                        store.send(.dragStart(point: point, time: time))
                                    },
                                    onDragUpdate: { point, time in
                                        store.send(.dragUpdate(point: point, time: time))
                                    },
                                    onDragEnd: { point, time in
                                        store.send(.dragEnd(point: point, time: time))
                                    },
                                    onActivityTap: { activity in
                                        if let destination = DestinationType.from(activity) {
                                            store.send(.activityTapped(destination))
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .week:
                                WeekView(
                                    currentWeek: store.currentWeek,
                                    activities: store.allActivities,
                                    onDayTap: { date in
                                        store.send(.dayTapped(date))
                                    },
                                    onLongPress: { point, time in
                                        store.send(.longPress(point: point, time: time))
                                    },
                                    onActivityTap: { activity in
                                        if let destination = DestinationType.from(activity) {
                                            store.send(.activityTapped(destination))
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .month:
                                MonthView(
                                    monthDates: store.currentMonth,
                                    activities: store.allActivities,
                                    currentDisplayDate: store.currentDisplayDate,
                                    onDayTap: { date in
                                        store.send(.dayTapped(date))
                                    }
                                )
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }

                        // Drag preview overlay positioned correctly
                        if store.showingDragPreview {
                            DragPreviewView(frame: store.dragPreviewFrame)
                                .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
        }
        .navigationTitle(store.trip.name)
        .inlineNavigationBarTitle()
        .background(Color.systemBackground)
        .toolbar {
            ToolbarItem(placement: .platformLeading) {
                Button("Done") { dismiss() }
            }

                ToolbarItem(placement: .platformTrailing) {
                    CalendarToolbarMenu(store: store)
                }
            }
            .confirmationDialog(
                "Choose Activity Type",
                isPresented: $store.showingActivityTypeSelector,
                titleVisibility: .visible
            ) {
                Button("🚗 Transportation") {
                    store.send(.selectActivityType(.transportation))
                }
                Button("🏨 Lodging") {
                    store.send(.selectActivityType(.lodging))
                }
                Button("🎟️ Activity") {
                    store.send(.selectActivityType(.activity))
                }
                Button("Cancel", role: .cancel) {
                    store.send(.cancelActivityCreation)
                }
            } message: {
                if let startTime = store.pendingActivityData?.startTime {
                    Text("Create activity for \(startTime.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("What type of activity would you like to add?")
                }
            }
        .sheet(item: activeSheet) { sheet in
            switch sheet {
            case .activityCreation:
                ActivityCreationSheet(store: store)
            case .dayDetail:
                NavigationStack {
                    DayDetailView(
                        date: store.selectedDate,
                        activities: store.selectedDayActivities,
                        trip: store.trip
                    )
                }
            }
        }
        // Removed onDisappear cancelActivityCreation() to prevent interference with dialog interactions
    }

    private var activeSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                if store.showingActivityCreation { return .activityCreation }
                if store.showingDayDetail { return .dayDetail }
                return nil
            },
            set: { newValue in
                $store.showingActivityCreation.wrappedValue = (newValue == .activityCreation)
                $store.showingDayDetail.wrappedValue = (newValue == .dayDetail)
            }
        )
    }
}

// MARK: - Calendar Toolbar Menu

struct CalendarToolbarMenu: View {
    let store: StoreOf<CalendarFeature>

    var body: some View {
        Menu {
            Button {
                store.send(.quickAddTapped)
            } label: {
                Label("Add Activity", systemImage: "plus.circle.fill")
            }

            Divider()

            Button {
                // Export calendar view
            } label: {
                Label("Export Calendar", systemImage: "square.and.arrow.up")
            }

            Button {
                // Calendar settings
            } label: {
                Label("Calendar Settings", systemImage: "gear")
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}

// MARK: - Activity Creation Sheet

struct ActivityCreationSheet: View {
    let store: StoreOf<CalendarFeature>

    var body: some View {
        NavigationStack {
            Group {
                switch store.selectedActivityType {
                case .transportation:
                    if let data = store.pendingActivityData {
                        PrefilledAddActivityView<Transportation>(
                            trip: store.trip,
                            activityType: Transportation.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime,
                            store: Store(
                                initialState: PrefilledAddActivityFeature.State(
                                    trip: store.trip,
                                    activityKind: .transportation,
                                    editData: TripActivityEditData(
                                        from: Transportation(
                                            name: "New Transportation",
                                            start: data.startTime,
                                            end: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime,
                                            trip: nil,
                                            organization: nil
                                        )
                                    )
                                )
                            ) {
                                PrefilledAddActivityFeature()
                            }
                        )
                    } else {
                        AddTripActivityView.forTransportation(trip: store.trip)
                    }
                case .lodging:
                    if let data = store.pendingActivityData {
                        PrefilledAddActivityView<Lodging>(
                            trip: store.trip,
                            activityType: Lodging.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .day, value: 1, to: data.startTime) ?? data.startTime,
                            store: Store(
                                initialState: PrefilledAddActivityFeature.State(
                                    trip: store.trip,
                                    activityKind: .lodging,
                                    editData: TripActivityEditData(
                                        from: Lodging(
                                            name: "New Lodging",
                                            start: data.startTime,
                                            end: data.endTime ?? Calendar.current.date(byAdding: .day, value: 1, to: data.startTime) ?? data.startTime,
                                            trip: nil,
                                            organization: nil
                                        )
                                    )
                                )
                            ) {
                                PrefilledAddActivityFeature()
                            }
                        )
                    } else {
                        AddTripActivityView.forLodging(trip: store.trip)
                    }
                case .activity:
                    if let data = store.pendingActivityData {
                        PrefilledAddActivityView<Activity>(
                            trip: store.trip,
                            activityType: Activity.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime,
                            store: Store(
                                initialState: PrefilledAddActivityFeature.State(
                                    trip: store.trip,
                                    activityKind: .activity,
                                    editData: TripActivityEditData(
                                        from: Activity(
                                            name: "New Activity",
                                            start: data.startTime,
                                            end: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime,
                                            trip: nil,
                                            organization: nil
                                        )
                                    )
                                )
                            ) {
                                PrefilledAddActivityFeature()
                            }
                        )
                    } else {
                        AddTripActivityView.forActivity(trip: store.trip)
                    }
                }
            }
        }
    }
}


// MARK: - Drag Preview Component

struct DragPreviewView: View {
    let frame: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.blue.opacity(0.3))
            .stroke(Color.blue, lineWidth: 2)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .overlay(
                Text("New Activity")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
                    .position(x: frame.midX, y: frame.midY)
            )
    }
}
