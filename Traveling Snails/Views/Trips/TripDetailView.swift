import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: Trip
    private let authManager = BiometricAuthManager.shared
    @State private var showingLodgingSheet: Bool = false
    @State private var showingTransportationSheet: Bool = false
    @State private var showingActivitySheet: Bool = false
    @State private var showingEditTripSheet: Bool = false
    @State private var showingCalendarView: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var viewMode: ViewMode = .list
    @State private var isAuthenticating: Bool = false
    @State private var isLocallyAuthenticated: Bool = false
    
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
    
    var allActivities: [ActivityWrapper] {
        let lodgingActivities = (trip.lodging).map { ActivityWrapper($0) }
        let transportationActivities = (trip.transportation).map { ActivityWrapper($0) }
        let activityActivities = (trip.activity).map { ActivityWrapper($0) }
        
        return (lodgingActivities + transportationActivities + activityActivities)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
    }
    
    // Check if we need to show lock screen
    private var needsLockScreen: Bool {
        return authManager.isProtected(trip) && !isLocallyAuthenticated
    }
    
    // Main content view with stable identity to prevent flickering
    @ViewBuilder
    private var contentView: some View {
        if needsLockScreen {
            BiometricLockView(trip: trip, isAuthenticating: $isAuthenticating) { 
                // Callback when authentication succeeds
                isLocallyAuthenticated = true
            }
        } else {
            TripContentView(trip: trip, 
                          viewMode: $viewMode,
                          navigationPath: $navigationPath,
                          showingLodgingSheet: $showingLodgingSheet,
                          showingTransportationSheet: $showingTransportationSheet,
                          showingActivitySheet: $showingActivitySheet,
                          showingEditTripSheet: $showingEditTripSheet,
                          showingCalendarView: $showingCalendarView) {
                // Callback when trip is locked
                isLocallyAuthenticated = false
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
            .onAppear {
                // Initialize local authentication state based on manager state
                isLocallyAuthenticated = authManager.isAuthenticated(for: trip)
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
    }
    
    
}

#Preview {
    NavigationStack {
        TripDetailView(trip: .init(name: "Test Trip"))
    }
}
