import SwiftData
import SwiftUI

struct TripContentView: View {
    let trip: Trip
    let activities: [ActivityWrapper] // FIXED: Receive activities as parameter instead of relationship access
    @Binding var viewMode: TripDetailView.ViewMode
    @Binding var navigationPath: NavigationPath
    @Binding var showingLodgingSheet: Bool
    @Binding var showingTransportationSheet: Bool
    @Binding var showingActivitySheet: Bool
    @Binding var showingEditTripSheet: Bool
    @Binding var showingCalendarView: Bool
    @Environment(ModernBiometricAuthManager.self) private var authManager
    let onLockTrip: () -> Void

    @State private var showingRemoveProtectionConfirmation: Bool = false
    @State private var showingTripSharingView: Bool = false

    init(trip: Trip, activities: [ActivityWrapper], viewMode: Binding<TripDetailView.ViewMode>, navigationPath: Binding<NavigationPath>, showingLodgingSheet: Binding<Bool>, showingTransportationSheet: Binding<Bool>, showingActivitySheet: Binding<Bool>, showingEditTripSheet: Binding<Bool>, showingCalendarView: Binding<Bool>, onLockTrip: @escaping () -> Void = {}) {
        self.trip = trip
        self.activities = activities
        self._viewMode = viewMode
        self._navigationPath = navigationPath
        self._showingLodgingSheet = showingLodgingSheet
        self._showingTransportationSheet = showingTransportationSheet
        self._showingActivitySheet = showingActivitySheet
        self._showingEditTripSheet = showingEditTripSheet
        self._showingCalendarView = showingCalendarView
        self.onLockTrip = onLockTrip
    }


    var body: some View {
        VStack(spacing: 0) {
            // View mode selector
            if !activities.isEmpty {
                VStack(spacing: 12) {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(TripDetailView.ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Trip summary
                    TripSummaryView(trip: trip, activities: activities)
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

                    // CloudKit sharing controls
                    Button {
                        showingTripSharingView = true
                    } label: {
                        Label("Share Trip", systemImage: "person.2.badge.plus")
                    }
                    .disabled(trip.isProtected) // Protected trips cannot be shared

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
                            if isProtected {
                                // Show confirmation dialog for removing protection
                                showingRemoveProtectionConfirmation = true
                            } else {
                                // No confirmation needed for adding protection
                                authManager.toggleProtection(for: trip)
                            }
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
        .sheet(isPresented: $showingTripSharingView) {
            TripSharingView(trip: trip)
        }
        .confirmationDialog(
            "Remove Protection",
            isPresented: $showingRemoveProtectionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Protection", role: .destructive) {
                authManager.toggleProtection(for: trip)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Removing protection means this trip will no longer require \(authManager.biometricType == .faceID ? "Face ID" : "Touch ID") authentication to access. Anyone with access to your device will be able to view trip details, activities, and attachments.")
        }
    }

    @ViewBuilder
    private var listView: some View {
        if activities.isEmpty {
            ContentUnavailableView(
                "No Activities Yet",
                systemImage: "calendar.badge.plus",
                description: Text("Add transportation, lodging, or activities to get started")
            )
        } else {
            List {
                ForEach(activities) { wrapper in
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
        CompactCalendarView(trip: trip, activities: activities) { activity in
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
