import SwiftUI
import SwiftData

@Observable @MainActor
class TripDetailViewModel {
    let trip: Trip
    var isUnlocked: Bool
    var isAuthenticating = false
    
    init(trip: Trip) {
        self.trip = trip
        self.isUnlocked = BiometricAuthManager.shared.isAuthenticated(for: trip)
    }
    
    func authenticate() async {
        guard !isAuthenticating else { return }
        
        #if DEBUG
        print("🔓 TripDetailViewModel.authenticate() - START")
        #endif
        
        isAuthenticating = true
        let success = await BiometricAuthManager.shared.authenticateTrip(trip)
        isAuthenticating = false
        
        if success {
            isUnlocked = true
            #if DEBUG
            print("🔓 Authentication successful - setting isUnlocked = true")
            #endif
        }
        
        #if DEBUG
        print("🔓 TripDetailViewModel.authenticate() - END")
        #endif
    }
    
    var needsAuthentication: Bool {
        BiometricAuthManager.shared.isProtected(trip) && !isUnlocked
    }
    
    func lockTrip() {
        BiometricAuthManager.shared.lockTrip(trip)
        isUnlocked = false
        #if DEBUG
        print("🔒 Manual lock - setting isUnlocked = false")
        #endif
    }
    
    func toggleProtection() {
        BiometricAuthManager.shared.toggleProtection(for: trip)
        // Update local state based on new protection status
        isUnlocked = BiometricAuthManager.shared.isAuthenticated(for: trip)
        #if DEBUG
        print("🔧 Protection toggled - isUnlocked: \(isUnlocked)")
        #endif
    }
}

struct StableTripDetailView: View {
    let tripID: UUID
    @State private var viewModel: TripDetailViewModel?
    @Environment(\.modelContext) private var modelContext
    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    @State private var showingActivitySheet: Bool = false
    @State private var showingEditTripSheet: Bool = false
    @State private var showingCalendarView: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var viewMode: ViewMode = .list
    
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
    
    // Track which trips have been initialized to reduce noise
    private static var initializedTrips: Set<UUID> = []
    
    init(tripID: UUID) {
        self.tripID = tripID
        
        // Only log the first initialization per trip to reduce noise
        if !Self.initializedTrips.contains(tripID) {
            Self.initializedTrips.insert(tripID)
        }
    }
    
    var allActivities: [ActivityWrapper] {
        guard let viewModel = viewModel else { return [] }
        let lodgingActivities = (viewModel.trip.lodging).map { ActivityWrapper($0) }
        let transportationActivities = (viewModel.trip.transportation).map { ActivityWrapper($0) }
        let activityActivities = (viewModel.trip.activity).map { ActivityWrapper($0) }
        
        return (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let viewModel = viewModel {
                    if viewModel.needsAuthentication {
                        lockScreenView
                    } else {
                        tripContentView
                    }
                } else {
                    ProgressView("Loading...")
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
            // Fetch the trip and initialize viewModel if needed
            if viewModel == nil {
                fetchTrip()
            }
        }
    }
    
    @ViewBuilder
    private var lockScreenView: some View {
        if let viewModel = viewModel {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: BiometricAuthManager.shared.biometricType == .faceID ? "faceid" : "touchid")
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
                        await viewModel.authenticate()
                    }
                } label: {
                    HStack {
                        if viewModel.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: BiometricAuthManager.shared.biometricType == .faceID ? "faceid" : "touchid")
                        }
                        
                        Text("Authenticate with \(BiometricAuthManager.shared.biometricType == .faceID ? "Face ID" : "Touch ID")")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isAuthenticating)
                .padding(.horizontal)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationTitle(viewModel.trip.name)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    @ViewBuilder
    private var tripContentView: some View {
        if let viewModel = viewModel {
            VStack(spacing: 0) {
                // View mode selector
                if !allActivities.isEmpty {
                    VStack(spacing: 12) {
                        Picker("View Mode", selection: $viewMode) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        TripSummaryView(trip: viewModel.trip, activities: allActivities)
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
            .navigationTitle(viewModel.trip.name)
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
                        
                        // Biometric protection controls
                        if BiometricAuthManager.shared.canUseBiometrics() && BiometricAuthManager.shared.isEnabled {
                            let isProtected = BiometricAuthManager.shared.isProtected(viewModel.trip)
                            
                            if isProtected && viewModel.isUnlocked {
                                Button {
                                    viewModel.lockTrip()
                                } label: {
                                    Label("Lock Trip Now", systemImage: "lock.fill")
                                }
                            }
                            
                            Button {
                                viewModel.toggleProtection()
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
                    UniversalAddTripActivityRootView.forActivity(trip: viewModel.trip)
                }
            }
            .sheet(isPresented: $showingLodgingSheet) {
                NavigationStack {
                    UniversalAddTripActivityRootView.forLodging(trip: viewModel.trip)
                }
            }
            .sheet(isPresented: $showingTransportationSheet) {
                NavigationStack {
                    UniversalAddTripActivityRootView.forTransportation(trip: viewModel.trip)
                }
            }
            .sheet(isPresented: $showingEditTripSheet) {
                NavigationStack {
                    EditTripView(trip: viewModel.trip)
                }
            }
            .fullScreenCover(isPresented: $showingCalendarView) {
                TripCalendarRootView(trip: viewModel.trip)
            }
        }
    }
    
    @ViewBuilder
    private var listView: some View {
        if allActivities.isEmpty {
            ContentUnavailableView(
                "No Activities Yet",
                systemImage: "calendar.badge.plus",
                description: Text("Add transportation, lodging, or activities to get started")
            )
        } else {
            List {
                ForEach(allActivities) { wrapper in
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
        if let viewModel = viewModel {
            CompactCalendarView(trip: viewModel.trip, activities: allActivities) { activity in
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
    
    private func fetchTrip() {
        let descriptor = FetchDescriptor<Trip>(predicate: #Predicate<Trip> { trip in
            trip.id == tripID
        })
        
        do {
            let trips = try modelContext.fetch(descriptor)
            if let trip = trips.first {
                viewModel = TripDetailViewModel(trip: trip)
                print("📱 StableTripDetailView.fetchTrip - found trip: \(trip.name)")
            } else {
                print("❌ StableTripDetailView.fetchTrip - trip not found for ID: \(tripID)")
            }
        } catch {
            print("❌ StableTripDetailView.fetchTrip - error: \(error)")
        }
    }
}