import SwiftUI
import SwiftData

// A completely isolated trip detail view that doesn't depend on @Observable state
struct IsolatedTripDetailView: View {
    // Store trip data as immutable values to prevent rebuilds from Trip mutations
    private let tripID: UUID
    private let tripName: String
    let trip: Trip // Use let instead of @State!
    @Environment(\.modelContext) private var modelContext
    
    // Local authentication state that doesn't observe the auth manager
    @State private var isLocallyAuthenticated: Bool
    @State private var isAuthenticating: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var viewMode: ViewMode = .list
    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    @State private var showingActivitySheet: Bool = false
    @State private var showingEditTripSheet: Bool = false
    @State private var showingCalendarView: Bool = false
    
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
            print("📱 IsolatedTripDetailView.onAppear - START for \(trip.name)")
            updateViewState()
            print("📱 IsolatedTripDetailView.onAppear - COMPLETED for \(trip.name)")
        }
        .onChange(of: trip.id) { _, newTripID in
            print("📱 IsolatedTripDetailView.onChange(of: trip.id) - Trip changed to \(trip.name)")
            updateViewState()
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
        // TEMPORARILY COMMENTED OUT TO TEST IF SHEETS CAUSE INFINITE RECREATION
        // .sheet(isPresented: $showingActivitySheet) {
        //     NavigationStack {
        //         UniversalAddTripActivityRootView.forActivity(trip: trip)
        //     }
        // }
        // .sheet(isPresented: $showingLodgingSheet) {
        //     NavigationStack {
        //         UniversalAddTripActivityRootView.forLodging(trip: trip)
        //     }
        // }
        // .sheet(isPresented: $showingTransportationSheet) {
        //     NavigationStack {
        //         UniversalAddTripActivityRootView.forTransportation(trip: trip)
        //     }
        // }
        // .sheet(isPresented: $showingEditTripSheet) {
        //     NavigationStack {
        //         EditTripView(trip: trip)
        //     }
        // }
        // .fullScreenCover(isPresented: $showingCalendarView) {
        //     TripCalendarRootView(trip: trip)
        // }
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
                            let authManager = BiometricAuthManager.shared
                            authManager.toggleProtection(for: trip)
                            // Update local state based on new protection status
                            isTripProtected = authManager.isProtected(trip)
                            isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
                            needsAuthentication = isTripProtected && !isLocallyAuthenticated
                            #if DEBUG
                            print("🔧 Protection toggled - isLocallyAuthenticated: \(isLocallyAuthenticated)")
                            #endif
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
        print("🔓 Authentication result: \(success)")
        #endif
        
        isAuthenticating = false
        
        if success {
            isLocallyAuthenticated = true
            needsAuthentication = false
            #if DEBUG
            print("🔓 Authentication successful - setting isLocallyAuthenticated = true, needsAuthentication = false")
            #endif
        }
        
        #if DEBUG
        print("🔓 IsolatedTripDetailView.authenticateUser() - END")
        #endif
    }
    
    // fetchTrip method removed since we now receive trip directly
    
    private func updateViewState() {
        print("📱 Getting BiometricAuthManager.shared...")
        let authManager = BiometricAuthManager.shared
        
        print("📱 Calling authManager.isAuthenticated(for: trip)...")
        isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
        
        print("📱 Calling authManager.isProtected(trip)...")
        isTripProtected = authManager.isProtected(trip)
        
        needsAuthentication = isTripProtected && !isLocallyAuthenticated
        
        print("📱 Calling authManager.canUseBiometrics()...")
        canUseBiometrics = authManager.canUseBiometrics()
        
        print("📱 Accessing authManager.isEnabled...")
        biometricAuthEnabled = authManager.isEnabled
        
        print("📱 Accessing authManager.biometricType...")
        isFaceID = authManager.biometricType == .faceID
        
        print("📱 About to call updateCachedActivities...")
        // Update cached activities for the current trip
        updateCachedActivities(for: trip)
    }
    
    private func updateCachedActivities(for trip: Trip) {
        let lodgingActivities = trip.lodging.map { ActivityWrapper($0) }
        let transportationActivities = trip.transportation.map { ActivityWrapper($0) }
        let activityActivities = trip.activity.map { ActivityWrapper($0) }
        
        cachedActivities = (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
        
        print("📱 Updated cachedActivities for \(trip.name): \(cachedActivities.count) activities")
    }
}
