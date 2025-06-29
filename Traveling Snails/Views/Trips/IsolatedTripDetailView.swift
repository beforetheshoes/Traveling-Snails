import Foundation
import SwiftData
import SwiftUI


// A completely isolated trip detail view that doesn't depend on @Observable state
struct IsolatedTripDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.navigationContext) private var navigationContext

    // Store trip data as immutable values to prevent rebuilds from Trip mutations
    let trip: Trip // Use let instead of @State!
    private let tripID: UUID
    private let tripName: String

    // Local authentication state that doesn't observe the auth manager
    @State private var isLocallyAuthenticated: Bool
    @State private var isAuthenticating: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var viewMode: ViewMode = .list

    // Navigation restoration support
    @State private var hasAppearedOnce = false
    @State private var lastDisappearTime: Date?
    @State private var pendingActivityNavigation: DestinationType?
    @State private var lastAppearTime: Date?
    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    @State private var showingActivitySheet: Bool = false
    @State private var showingEditTripSheet: Bool = false
    @State private var showingCalendarView: Bool = false
    @State private var showingRemoveProtectionConfirmation: Bool = false

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

    init(trip: Trip) {
        self.trip = trip
        self.tripID = trip.id
        self.tripName = trip.name

        // Initialize with false - will be updated in onAppear to avoid init-time dependencies
        self._isLocallyAuthenticated = State(initialValue: false)
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
        NavigationStack(path: $navigationPath) {
            Group {
                if needsAuthentication {
                    lockScreenView
                } else {
                    tripContentView
                }
            }
            .navigationDestination(for: DestinationType.self) { destination in
                switch destination {
                case .lodging(let lodging):
                    UnifiedTripActivityDetailView<Lodging>(activity: lodging)
                case .transportation(let transportation):
                    UnifiedTripActivityDetailView<Transportation>(activity: transportation)
                case .activity(let activity):
                    UnifiedTripActivityDetailView<Activity>(activity: activity)
                }
            }
        }
        .onAppear {
            #if DEBUG
            Logger.shared.debug("IsolatedTripDetailView.onAppear - START for trip ID \(trip.id)", category: .ui)
            #endif
            let currentTime = Date()
            lastAppearTime = currentTime

            Task {
                await updateViewState()

                // Small delay for iPad to ensure NavigationContext is updated
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second

                // Check if this is a tab restoration using NavigationContext
                let shouldRestore = navigationContext.shouldRestoreNavigation
                let isRecentSwitch = navigationContext.isRecentTabSwitch(within: 3.0)
                let isTabRestoration = shouldRestore && isRecentSwitch

                #if DEBUG
                Logger.shared.debug("Navigation Context Debug - instance: \(ObjectIdentifier(navigationContext)), shouldRestore: \(shouldRestore), isRecentSwitch: \(isRecentSwitch), isTabRestoration: \(isTabRestoration), hasAppearedOnce: \(hasAppearedOnce)", category: .ui)
                #endif

                if isTabRestoration {
                    await handleNavigationRestoration()
                    navigationContext.markNavigationRestored()
                    #if DEBUG
                    Logger.shared.debug("Tab restoration detected - handled navigation restoration", category: .ui)
                    #endif
                } else {
                    hasAppearedOnce = true
                    #if DEBUG
                    Logger.shared.debug("Fresh selection or first appearance - skipping navigation restoration", category: .ui)
                    #endif
                }
                
                #if DEBUG
                Logger.shared.debug("IsolatedTripDetailView.onAppear - COMPLETED for trip ID \(trip.id)", category: .ui)
                #endif
            }
        }
        .onChange(of: trip.id) { _, newTripID in
            #if DEBUG
            Logger.shared.debug("IsolatedTripDetailView.onChange(of: trip.id) - Trip changed to ID \(trip.id)", category: .ui)
            #endif
            // Reset state when trip changes - this is a fresh selection
            hasAppearedOnce = false
            lastDisappearTime = nil
            Task {
                await updateViewState()
                // Don't restore navigation when trip changes - this is a fresh selection
                #if DEBUG
                Logger.shared.debug("Trip changed - skipping navigation restoration", category: .ui)
                #endif
            }
        }
        .onDisappear {
            // Track when view disappears for tab restoration detection
            lastDisappearTime = Date()
            #if DEBUG
            Logger.shared.debug("IsolatedTripDetailView disappeared for trip ID \(trip.id)", category: .ui)
            #endif
        }
        .onChange(of: navigationPath) { oldPath, newPath in
            // Clear old navigation states when user actively navigates back to root
            if newPath.isEmpty && !oldPath.isEmpty {
                clearNavigationStates()
                #if DEBUG
                Logger.shared.debug("User navigated back to root - clearing navigation states", category: .ui)
                #endif
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripSelectedFromList)) { notification in
            // Handle trip selection from list while in deep navigation
            if let selectedTripId = notification.object as? UUID, selectedTripId == trip.id {
                // Clear navigation path to return to trip root
                let previousCount = navigationPath.count
                if previousCount > 0 {
                    navigationPath = NavigationPath()
                    #if DEBUG
                    Logger.shared.debug("Trip selected from list - cleared navigation path (was \(previousCount) deep)", category: .ui)
                    #endif
                }
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
         .fullScreenCover(isPresented: $showingCalendarView) {
             TripCalendarRootView(trip: trip)
         }
         .confirmationDialog(
             "Remove Protection",
             isPresented: $showingRemoveProtectionConfirmation,
             titleVisibility: .visible
         ) {
             Button("Remove Protection", role: .destructive) {
                 let authManager = BiometricAuthManager.shared
                 authManager.toggleProtection(for: trip)
                 // Update local state based on new protection status
                 isTripProtected = authManager.isProtected(trip)
                 isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
                 needsAuthentication = isTripProtected && !isLocallyAuthenticated
                 #if DEBUG
                 print("🔧 Protection removed - isLocallyAuthenticated: \(isLocallyAuthenticated)")
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

                    // Biometric protection controls
                    if canUseBiometrics && biometricAuthEnabled {
                        if isTripProtected && isLocallyAuthenticated {
                            Button {
                                let authManager = BiometricAuthManager.shared
                                authManager.lockTrip(trip)
                                isLocallyAuthenticated = false
                                needsAuthentication = true
                                #if DEBUG
                                print("🔒 Manual lock - setting isLocallyAuthenticated = false")
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
                                let authManager = BiometricAuthManager.shared
                                authManager.toggleProtection(for: trip)
                                // Update local state based on new protection status
                                isTripProtected = authManager.isProtected(trip)
                                isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
                                needsAuthentication = isTripProtected && !isLocallyAuthenticated
                                #if DEBUG
                                print("🔧 Protection toggled - isLocallyAuthenticated: \(isLocallyAuthenticated)")
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
                        let destinationType: DestinationType
                        switch wrapper.tripActivity {
                        case let lodging as Lodging:
                            destinationType = DestinationType.lodging(lodging)
                        case let transportation as Transportation:
                            destinationType = DestinationType.transportation(transportation)
                        case let activity as Activity:
                            destinationType = DestinationType.activity(activity)
                        default:
                            return
                        }

                        navigationPath.append(destinationType)
                        saveActivityNavigationState(destinationType)
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
            let destinationType: DestinationType
            switch activity {
            case let lodging as Lodging:
                destinationType = DestinationType.lodging(lodging)
            case let transportation as Transportation:
                destinationType = DestinationType.transportation(transportation)
            case let activityItem as Activity:
                destinationType = DestinationType.activity(activityItem)
            default:
                return
            }

            navigationPath.append(destinationType)
            saveActivityNavigationState(destinationType)
        }
    }

    @MainActor
    private func authenticateUser() async {
        guard !isAuthenticating else { return }

        #if DEBUG
        print("🔓 IsolatedTripDetailView.authenticateUser() - START")
        #endif
        isAuthenticating = true

        let authManager = BiometricAuthManager.shared
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
    private func updateViewState() async {
        #if DEBUG
        Logger.shared.debug("Updating view state for trip ID: \(trip.id)", category: .ui)
        #endif
        
        let authManager = BiometricAuthManager.shared
        
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

    // MARK: - Navigation State Management

    private func saveActivityNavigationState(_ destination: DestinationType) {
        // Save the specific activity navigation for restoration
        let activityData = ActivityNavigationReference(from: destination, tripId: trip.id)
        if let encoded = try? JSONEncoder().encode(activityData) {
            UserDefaults.standard.set(encoded, forKey: "activityNavigation_\(trip.id)")
        }
        
        #if DEBUG
        Logger.shared.debug("Saved activity navigation state", category: .navigation)
        #endif
    }

    @MainActor
    private func handleNavigationRestoration() async {
        // Check for activity-specific navigation state
        guard let data = UserDefaults.standard.data(forKey: "activityNavigation_\(trip.id)"),
              let activityNav = try? JSONDecoder().decode(ActivityNavigationReference.self, from: data) else {
            #if DEBUG
            Logger.shared.debug("No navigation state found for trip ID \(trip.id)", category: .navigation)
            #endif
            return
        }

        // Create destination from the saved reference
        guard let destination = activityNav.createDestination(from: trip) else {
            #if DEBUG
            Logger.shared.debug("Could not create destination from saved reference - activity may have been deleted", category: .navigation)
            #endif
            // Clear the invalid state
            clearNavigationStates()
            return
        }

        // Use NavigationPath to restore - this is the proper SwiftUI way
        navigationPath = NavigationPath([destination])
        #if DEBUG
        Logger.shared.debug("Restored navigation to activity", category: .navigation)
        #endif
    }

    private func clearNavigationStates() {
        UserDefaults.standard.removeObject(forKey: "activityNavigation_\(trip.id)")
        #if DEBUG
        Logger.shared.debug("Cleared navigation states for trip ID \(trip.id)", category: .navigation)
        #endif
    }
}
