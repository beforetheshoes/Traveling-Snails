import SwiftData
import SwiftUI

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

    // FIXED: Use @Query instead of relationship access to ensure UI updates immediately
    @Query private var lodgingActivities: [Lodging]
    @Query private var transportationActivities: [Transportation]
    @Query private var activityActivities: [Activity]

    init(trip: Trip) {
        self.trip = trip

        // Filter queries by trip ID for proper isolation
        let tripId = trip.id
        self._lodgingActivities = Query(
            filter: #Predicate<Lodging> { $0.trip?.id == tripId },
            sort: \Lodging.start
        )
        self._transportationActivities = Query(
            filter: #Predicate<Transportation> { $0.trip?.id == tripId },
            sort: \Transportation.start
        )
        self._activityActivities = Query(
            filter: #Predicate<Activity> { $0.trip?.id == tripId },
            sort: \Activity.start
        )
    }

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
        let lodgingWrappers = lodgingActivities.map { ActivityWrapper($0) }
        let transportationWrappers = transportationActivities.map { ActivityWrapper($0) }
        let activityWrappers = activityActivities.map { ActivityWrapper($0) }

        return (lodgingWrappers + transportationWrappers + activityWrappers)
            .sorted { $0.tripActivity.start < $1.tripActivity.start }
    }

    // Check if we need to show lock screen
    private var needsLockScreen: Bool {
        authManager.isProtected(trip) && !isLocallyAuthenticated
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
                          activities: allActivities,
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
    .modelContainer(for: [Trip.self, Activity.self, Lodging.self, Transportation.self], inMemory: true)
}
