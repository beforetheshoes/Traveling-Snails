//
//  CalendarContentView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
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
            
            // Calendar content with drag support
            ZStack {
                Group {
                    switch viewModel.calendarMode {
                    case .day:
                        DayView(
                            date: viewModel.currentDisplayDate,
                            activities: viewModel.activitiesForCurrentPeriod,
                            onDragStart: viewModel.handleDragStart,
                            onDragUpdate: viewModel.handleDragUpdate,
                            onDragEnd: viewModel.handleDragEnd
                        )
                    case .week:
                        WeekView(
                            currentWeek: viewModel.currentWeek,
                            activities: viewModel.allActivities,
                            onDayTap: viewModel.handleDayTap,
                            onLongPress: viewModel.handleLongPress
                        )
                    case .month:
                        MonthView(
                            monthDates: viewModel.currentMonth,
                            activities: viewModel.allActivities,
                            currentDisplayDate: viewModel.currentDisplayDate,
                            onDayTap: viewModel.handleDayTap
                        )
                    }
                }
                
                // Drag preview overlay
                if viewModel.showingDragPreview {
                    DragPreviewView(frame: viewModel.dragPreviewFrame)
                }
            }
        }
        .navigationTitle("\(viewModel.trip.name)")
        .navigationBarTitleDisplayMode(.inline)
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
        .actionSheet(isPresented: $viewModel.showingActivityTypeSelector) {
            createActivityTypeActionSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingDayDetail) {
            DayDetailView(
                date: viewModel.selectedDate,
                activities: viewModel.selectedDayActivities,
                trip: viewModel.trip
            )
        }
        .onDisappear {
            viewModel.cancelActivityCreation()
        }
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

// MARK: - Activity Type Action Sheet

private func createActivityTypeActionSheet(viewModel: CalendarViewModel) -> ActionSheet {
    ActionSheet(
        title: Text("Choose Activity Type"),
        message: viewModel.pendingActivityData?.startTime != nil ?
            Text("Create activity for \(viewModel.pendingActivityData?.startTime.formatted(date: .abbreviated, time: .shortened) ?? "")") :
            Text("What type of activity would you like to add?"),
        buttons: [
            .default(Text("🚗 Transportation")) {
                viewModel.selectActivityType(.transportation)
            },
            .default(Text("🏨 Lodging")) {
                viewModel.selectActivityType(.lodging)
            },
            .default(Text("🎟️ Activity")) {
                viewModel.selectActivityType(.activity)
            },
            .cancel {
                viewModel.cancelActivityCreation()
            }
        ]
    )
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