import Foundation
import SQLiteData
import SwiftUI


// A completely isolated trip detail view that doesn't depend on @Observable state
struct IsolatedTripDetailView: View {
    @Environment(ModernBiometricAuthManager.self) private var authManager

    // Store trip data as immutable values to prevent rebuilds from Trip mutations
    let trip: Trip
    @Binding private var path: [TripRoute]
    private let resetToken: Int
    private let tripName: String

    // Local authentication state that doesn't observe the auth manager
    @State private var isLocallyAuthenticated: Bool
    @State private var isAuthenticating: Bool = false
    @State private var lastHandledResetToken: Int
    @State private var viewMode: ViewMode = .list

    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    @State private var showingActivitySheet: Bool = false
    @State private var showingEditTripSheet: Bool = false
    @State private var showingCalendarView: Bool = false
    @State private var showingRemoveProtectionConfirmation: Bool = false
    @State private var showingTripSharingView: Bool = false

    enum ViewMode: String, CaseIterable {
        case list = "List"
        case calendar = "Calendar"

        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .calendar: return "calendar"
            }
        }
    }

    init(
        trip: Trip,
        path: Binding<[TripRoute]>,
        resetToken: Int
    ) {
        self.trip = trip
        self._path = path
        self.resetToken = resetToken
        self.tripName = trip.name

        // Initialize with false - will be updated in onAppear to avoid init-time dependencies
        self._isLocallyAuthenticated = State(initialValue: false)
        self._lastHandledResetToken = State(initialValue: resetToken)
    }

    // Removed computed property that was causing SwiftData relationship access

    // Local state to track if this trip needs authentication
    @State private var needsAuthentication: Bool = false
    @State private var canUseBiometrics: Bool = false
    @State private var biometricAuthEnabled: Bool = false
    @State private var isTripProtected: Bool = false
    @State private var isFaceID: Bool = false

    // Cached activities to prevent repeated SwiftData access
    @State private var cachedActivities: [ActivityWrapper] = []

    var body: some View {
        Group {
            if needsAuthentication {
                lockScreenView
            } else {
                tripContentView
            }
        }
        .task(id: trip.id) {
            updateViewState()
        }
        .onChange(of: trip.id) { _, _ in
            path = []
            updateViewState()
        }
        .onChange(of: resetToken) { _, newToken in
            guard newToken != lastHandledResetToken else { return }
            lastHandledResetToken = newToken
            if !path.isEmpty {
                path = []
            }
        }
    }

    @ViewBuilder
    private var lockScreenView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isFaceID ? "faceid" : "touchid")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("This trip is protected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Authenticate to view trip details")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await authenticateUser()
                }
            } label: {
                HStack {
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: isFaceID ? "faceid" : "touchid")
                    }

                    Text("Authenticate with \(isFaceID ? "Face ID" : "Touch ID")")
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isAuthenticating)
            .padding(.horizontal)

            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle(tripName)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var tripContentView: some View {
        VStack(spacing: 0) {
            // View mode selector
            if !cachedActivities.isEmpty {
                VStack(spacing: 12) {
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

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
        .navigationTitle(tripName)
        .navigationBarTitleDisplayMode(.inline)
         .sheet(isPresented: $showingActivitySheet, onDismiss: {
             // Refresh cached activities when activity sheet is dismissed
             updateCachedActivities(for: trip)
             Logger.shared.debug("Activity sheet dismissed - refreshed cached activities", category: .ui)
         }) {
             NavigationStack {
                 UniversalAddTripActivityRootView.forActivity(trip: trip)
             }
         }
         .sheet(isPresented: $showingLodgingSheet, onDismiss: {
             // Refresh cached activities when lodging sheet is dismissed
             updateCachedActivities(for: trip)
             Logger.shared.debug("Lodging sheet dismissed - refreshed cached activities", category: .ui)
         }) {
             NavigationStack {
                 UniversalAddTripActivityRootView.forLodging(trip: trip)
             }
         }
         .sheet(isPresented: $showingTransportationSheet, onDismiss: {
             // Refresh cached activities when transportation sheet is dismissed
             updateCachedActivities(for: trip)
             Logger.shared.debug("Transportation sheet dismissed - refreshed cached activities", category: .ui)
         }) {
             NavigationStack {
                 UniversalAddTripActivityRootView.forTransportation(trip: trip)
             }
         }
         .sheet(isPresented: $showingEditTripSheet) {
             NavigationStack {
                 EditTripView(trip: trip)
             }
         }
         .sheet(isPresented: $showingTripSharingView) {
             TripSharingView(trip: trip)
         }
         .fullScreenCover(isPresented: $showingCalendarView) {
             TripCalendarRootView(trip: trip)
         }
         .confirmationDialog(
             "Remove Protection",
             isPresented: $showingRemoveProtectionConfirmation,
             titleVisibility: .visible
         ) {
             Button("Remove Protection", role: .destructive) {
                 authManager.toggleProtection(for: trip)
                 // Update local state based on new protection status
                 isTripProtected = authManager.isProtected(trip)
                 isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
                 needsAuthentication = isTripProtected && !isLocallyAuthenticated
                 #if DEBUG
                 Logger.shared.debug("Protection removed - isLocallyAuthenticated: \(isLocallyAuthenticated)", category: .ui)
                 #endif
             }
             Button("Cancel", role: .cancel) { }
         } message: {
             Text("Removing protection means this trip will no longer require \(isFaceID ? "Face ID" : "Touch ID") authentication to access. Anyone with access to your device will be able to view trip details, activities, and attachments.")
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

                    // CloudKit sharing controls
                    Button {
                        showingTripSharingView = true
                    } label: {
                        Label("Share Trip", systemImage: "person.2.badge.plus")
                    }
                    .disabled(isTripProtected) // Protected trips cannot be shared

                    Divider()

                    // Biometric protection controls
                    if canUseBiometrics && biometricAuthEnabled {
                        if isTripProtected && isLocallyAuthenticated {
                            Button {
                                authManager.lockTrip(trip)
                                isLocallyAuthenticated = false
                                needsAuthentication = true
                                #if DEBUG
                                Logger.shared.debug("Manual lock - setting isLocallyAuthenticated = false")
                                #endif
                            } label: {
                                Label("Lock Trip Now", systemImage: "lock.fill")
                            }
                        }

                        Button {
                            if isTripProtected {
                                // Show confirmation dialog for removing protection
                                showingRemoveProtectionConfirmation = true
                            } else {
                                // No confirmation needed for adding protection
                                authManager.toggleProtection(for: trip)
                                // Update local state based on new protection status
                                isTripProtected = authManager.isProtected(trip)
                                isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
                                needsAuthentication = isTripProtected && !isLocallyAuthenticated
                                #if DEBUG
                                Logger.shared.debug("Protection toggled - isLocallyAuthenticated: \(isLocallyAuthenticated)", category: .ui)
                                #endif
                            }
                        } label: {
                            if isTripProtected {
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
                        guard let route = TripRouteMapper.route(from: wrapper.tripActivity) else {
                            return
                        }
                        path.append(route)
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
            guard let route = TripRouteMapper.route(from: activity) else {
                return
            }
            path.append(route)
        }
    }

    @MainActor
    private func authenticateUser() async {
        guard !isAuthenticating else { return }

        #if DEBUG
        Logger.shared.debug("IsolatedTripDetailView.authenticateUser() - START")
        #endif
        isAuthenticating = true

        let success = await authManager.authenticateTrip(trip)
        #if DEBUG
        Logger.shared.debug("Authentication process completed", category: .ui)
        #endif

        isAuthenticating = false

        if success {
            isLocallyAuthenticated = true
            needsAuthentication = false
            #if DEBUG
            Logger.shared.debug("Authentication state updated", category: .ui)
            #endif
        }

        #if DEBUG
        Logger.shared.debug("IsolatedTripDetailView.authenticateUser() completed", category: .ui)
        #endif
    }

    // fetchTrip method removed since we now receive trip directly

    @MainActor
    private func updateViewState() {
        #if DEBUG
        Logger.shared.debug("Updating view state for trip ID: \(trip.id)", category: .ui)
        #endif

        isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
        isTripProtected = authManager.isProtected(trip)
        needsAuthentication = isTripProtected && !isLocallyAuthenticated
        canUseBiometrics = authManager.canUseBiometrics()
        biometricAuthEnabled = authManager.isEnabled
        isFaceID = authManager.biometricType == .faceID

        #if DEBUG
        Logger.shared.debug("View state updated, updating cached activities", category: .ui)
        #endif
        // Update cached activities for the current trip
        updateCachedActivities(for: trip)
    }

    private func updateCachedActivities(for trip: Trip) {
        let lodgingActivities = trip.lodging.map { ActivityWrapper($0) }
        let transportationActivities = trip.transportation.map { ActivityWrapper($0) }
        let activityActivities = trip.activity.map { ActivityWrapper($0) }

        cachedActivities = (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }

        #if DEBUG
        Logger.shared.debug("Updated cachedActivities for trip ID \(trip.id): \(cachedActivities.count) activities", category: .ui)
        #endif
    }

}
