import SwiftUI
import SwiftData

struct TripContentView: View {
    let trip: Trip
    @Binding var viewMode: TripDetailView.ViewMode
    @Binding var navigationPath: NavigationPath
    @Binding var showingLodgingSheet: Bool
    @Binding var showingTransportationSheet: Bool
    @Binding var showingActivitySheet: Bool
    @Binding var showingEditTripSheet: Bool
    @Binding var showingCalendarView: Bool
    private let authManager = BiometricAuthManager.shared
    let onLockTrip: () -> Void
    
    // Cache the expensive activities computation
    @State private var cachedActivities: [ActivityWrapper] = []
    @State private var lastTripID: UUID?
    
    init(trip: Trip, viewMode: Binding<TripDetailView.ViewMode>, navigationPath: Binding<NavigationPath>, showingLodgingSheet: Binding<Bool>, showingTransportationSheet: Binding<Bool>, showingActivitySheet: Binding<Bool>, showingEditTripSheet: Binding<Bool>, showingCalendarView: Binding<Bool>, onLockTrip: @escaping () -> Void = {}) {
        self.trip = trip
        self._viewMode = viewMode
        self._navigationPath = navigationPath
        self._showingLodgingSheet = showingLodgingSheet
        self._showingTransportationSheet = showingTransportationSheet
        self._showingActivitySheet = showingActivitySheet
        self._showingEditTripSheet = showingEditTripSheet
        self._showingCalendarView = showingCalendarView
        self.onLockTrip = onLockTrip
        // print("📋 TripContentView.init() for \(trip.name)")
    }
    
    // Update cached activities only when trip changes
    private func updateActivitiesIfNeeded() {
        if lastTripID != trip.id {
            let lodgingActivities = (trip.lodging).map { ActivityWrapper($0) }
            let transportationActivities = (trip.transportation).map { ActivityWrapper($0) }
            let activityActivities = (trip.activity).map { ActivityWrapper($0) }
            
            cachedActivities = (lodgingActivities + transportationActivities + activityActivities)
                .sorted { $0.tripActivity.start < $1.tripActivity.start }
            lastTripID = trip.id
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // View mode selector
            if !cachedActivities.isEmpty {
                VStack(spacing: 12) {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(TripDetailView.ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Trip summary
                    TripSummaryView(trip: trip, activities: cachedActivities)
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
            }
            
            // Content based on view mode
            Group {
                switch viewMode {
                case .list:
                    listView
                case .calendar:
                    calendarView
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updateActivitiesIfNeeded()
        }
        .onChange(of: trip.id) { _, _ in
            updateActivitiesIfNeeded()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingEditTripSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingActivitySheet = true
                    } label: {
                        Label("Add Activity", systemImage: "ticket")
                    }
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
                    
                    Divider()
                    
                    Button {
                        showingCalendarView = true
                    } label: {
                        Label("Full Calendar View", systemImage: "calendar.badge.plus")
                    }
                    
                    Divider()
                    
                    // Biometric protection controls
                    if authManager.canUseBiometrics() && authManager.isEnabled {
                        let isProtected = authManager.isProtected(trip)
                        let isAuthenticated = authManager.isAuthenticated(for: trip)
                        
                        if isProtected && isAuthenticated {
                            Button {
                                authManager.lockTrip(trip)
                                onLockTrip()
                            } label: {
                                Label("Lock Trip Now", systemImage: "lock.fill")
                            }
                        }
                        
                        Button {
                            authManager.toggleProtection(for: trip)
                        } label: {
                            if isProtected {
                                Label("Remove Protection", systemImage: "lock.open")
                            } else {
                                Label("Protect Trip", systemImage: "lock")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingActivitySheet) {
            NavigationStack {
                UniversalAddTripActivityRootView.forActivity(trip: trip)
            }
        }
        .sheet(isPresented: $showingLodgingSheet) {
            NavigationStack {
                UniversalAddTripActivityRootView.forLodging(trip: trip)
            }
        }
        .sheet(isPresented: $showingTransportationSheet) {
            NavigationStack {
                UniversalAddTripActivityRootView.forTransportation(trip: trip)
            }
        }
        .sheet(isPresented: $showingEditTripSheet) {
            NavigationStack {
                EditTripView(trip: trip)
            }
        }
        .fullScreenCover(isPresented: $showingCalendarView) {
            TripCalendarRootView(trip: trip)
        }
    }
    
    @ViewBuilder
    private var listView: some View {
        if cachedActivities.isEmpty {
            ContentUnavailableView(
                "No Activities Yet",
                systemImage: "calendar.badge.plus",
                description: Text("Add transportation, lodging, or activities to get started")
            )
        } else {
            List {
                ForEach(cachedActivities) { wrapper in
                    Button {
                        switch wrapper.tripActivity {
                        case let lodging as Lodging:
                            navigationPath.append(DestinationType.lodging(lodging))
                        case let transportation as Transportation:
                            navigationPath.append(DestinationType.transportation(transportation))
                        case let activity as Activity:
                            navigationPath.append(DestinationType.activity(activity))
                        default:
                            break
                        }
                    } label: {
                        ActivityRowView(wrapper: wrapper)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private var calendarView: some View {
        CompactCalendarView(trip: trip, activities: cachedActivities) { activity in
            // Handle activity selection in compact calendar
            switch activity {
            case let lodging as Lodging:
                navigationPath.append(DestinationType.lodging(lodging))
            case let transportation as Transportation:
                navigationPath.append(DestinationType.transportation(transportation))
            case let activityItem as Activity:
                navigationPath.append(DestinationType.activity(activityItem))
            default:
                break
            }
        }
    }
}
