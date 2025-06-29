//
//  CalendarContentView.swift
//  Traveling Snails
//
//

import SwiftUI

struct CalendarContentView: View {
    @Bindable var viewModel: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced header
            CalendarHeaderView(
                trip: viewModel.trip,
                selectedDate: $viewModel.selectedDate,
                currentWeekOffset: $viewModel.currentWeekOffset,
                calendarMode: $viewModel.calendarMode,
                activities: viewModel.allActivities
            )

            // Calendar content with proper layout constraints
            GeometryReader { _ in
                ZStack {
                    Group {
                        switch viewModel.calendarMode {
                        case .day:
                            DayView(
                                date: viewModel.currentDisplayDate,
                                activities: viewModel.activitiesForCurrentPeriod,
                                onDragStart: viewModel.handleDragStart,
                                onDragUpdate: viewModel.handleDragUpdate,
                                onDragEnd: viewModel.handleDragEnd,
                                onActivityTap: viewModel.handleActivityTap
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .week:
                            WeekView(
                                currentWeek: viewModel.currentWeek,
                                activities: viewModel.allActivities,
                                onDayTap: viewModel.handleDayTap,
                                onLongPress: viewModel.handleLongPress,
                                onActivityTap: viewModel.handleActivityTap
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .month:
                            MonthView(
                                monthDates: viewModel.currentMonth,
                                activities: viewModel.allActivities,
                                currentDisplayDate: viewModel.currentDisplayDate,
                                onDayTap: viewModel.handleDayTap
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }

                    // Drag preview overlay positioned correctly
                    if viewModel.showingDragPreview {
                        DragPreviewView(frame: viewModel.dragPreviewFrame)
                            .clipped()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                CalendarToolbarMenu(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showingActivityCreation) {
            ActivityCreationSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Choose Activity Type",
            isPresented: $viewModel.showingActivityTypeSelector,
            titleVisibility: .visible
        ) {
            Button("🚗 Transportation") {
                viewModel.selectActivityType(.transportation)
            }
            Button("🏨 Lodging") {
                viewModel.selectActivityType(.lodging)
            }
            Button("🎟️ Activity") {
                viewModel.selectActivityType(.activity)
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelActivityCreation()
            }
        } message: {
            if let startTime = viewModel.pendingActivityData?.startTime {
                Text("Create activity for \(startTime.formatted(date: .abbreviated, time: .shortened))")
            } else {
                Text("What type of activity would you like to add?")
            }
        }
        .sheet(isPresented: $viewModel.showingDayDetail) {
            NavigationStack {
                DayDetailView(
                    date: viewModel.selectedDate,
                    activities: viewModel.selectedDayActivities,
                    trip: viewModel.trip
                )
            }
        }
        // Removed onDisappear cancelActivityCreation() to prevent interference with dialog interactions
    }
}

// MARK: - Calendar Toolbar Menu

struct CalendarToolbarMenu: View {
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        Menu {
            Button {
                viewModel.createQuickActivity()
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
    @Bindable var viewModel: CalendarViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.selectedActivityType {
                case .transportation:
                    if let data = viewModel.pendingActivityData {
                        PrefilledAddActivityView<Transportation>(
                            trip: viewModel.trip,
                            activityType: Transportation.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime
                        )
                    } else {
                        UniversalAddTripActivityRootView.forTransportation(trip: viewModel.trip)
                    }
                case .lodging:
                    if let data = viewModel.pendingActivityData {
                        PrefilledAddActivityView<Lodging>(
                            trip: viewModel.trip,
                            activityType: Lodging.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .day, value: 1, to: data.startTime) ?? data.startTime
                        )
                    } else {
                        UniversalAddTripActivityRootView.forLodging(trip: viewModel.trip)
                    }
                case .activity:
                    if let data = viewModel.pendingActivityData {
                        PrefilledAddActivityView<Activity>(
                            trip: viewModel.trip,
                            activityType: Activity.self,
                            startTime: data.startTime,
                            endTime: data.endTime ?? Calendar.current.date(byAdding: .hour, value: 2, to: data.startTime) ?? data.startTime
                        )
                    } else {
                        UniversalAddTripActivityRootView.forActivity(trip: viewModel.trip)
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
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                    .position(x: frame.midX, y: frame.midY)
            )
    }
}
