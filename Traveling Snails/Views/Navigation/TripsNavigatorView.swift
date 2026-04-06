import ComposableArchitecture
import SQLiteData
import SwiftUI

enum TripScreenRoute: Hashable {
    case trip(UUID)
    case activity(TripRoute)
}

struct TripsNavigatorView: View {
    private enum ActiveSheet: Identifiable {
        case addTrip

        var id: Int { 0 }
    }

    let trips: [Trip]
    @Binding var selectedTripID: Trip.ID?
    @Binding var tripPath: [TripRoute]
    let tripResetToken: Int
    let onClearTripSelection: () -> Void
    let onTripSelection: (Trip, Bool) -> Void

    @State private var searchText = ""
    @State private var activeSheet: ActiveSheet?
    @AppStorage(UserDefaultsConstants.hidePastTrips) private var hidePastTrips = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var visibleTrips: [Trip] {
        if hidePastTrips {
            return trips.filter { !$0.isPastTrip }
        }
        return trips
    }

    private var hiddenPastTripsCount: Int {
        trips.filter(\.isPastTrip).count
    }

    private var filteredTrips: [Trip] {
        guard !searchText.isEmpty else { return visibleTrips }
        return visibleTrips.filter { trip in
            trip.displayName.localizedStandardContains(searchText) ||
            (trip.displaySubtitle?.localizedStandardContains(searchText) ?? false)
        }
    }

    private var selectedTrip: Trip? {
        guard let selectedTripID else { return nil }
        return trips.first(where: { $0.id == selectedTripID })
    }

    private var compactPathBinding: Binding<[TripScreenRoute]> {
        Binding(
            get: {
                guard let selectedTripID else { return [] }
                return [.trip(selectedTripID)] + tripPath.map(TripScreenRoute.activity)
            },
            set: { newPath in
                guard !newPath.isEmpty else {
                    onClearTripSelection()
                    return
                }
                guard case let .trip(newSelectedTripID) = newPath[0] else {
                    onClearTripSelection()
                    return
                }
                let newTripPath = newPath.dropFirst().compactMap { route -> TripRoute? in
                    guard case let .activity(activityRoute) = route else { return nil }
                    return activityRoute
                }
                let tripIDChanged = selectedTripID != newSelectedTripID
                let tripPathChanged = tripPath != newTripPath
                guard tripIDChanged || tripPathChanged else { return }
                // Batch both mutations in a single transaction to avoid
                // multiple navigation updates per frame
                withTransaction(Transaction()) {
                    if tripIDChanged { selectedTripID = newSelectedTripID }
                    if tripPathChanged { tripPath = newTripPath }
                }
            }
        )
    }

    var body: some View {
        Group {
            if isCompact {
                NavigationStack(path: compactPathBinding) {
                    listContent
                        .navigationDestination(for: TripScreenRoute.self) { route in
                            switch route {
                            case .trip(let tripID):
                                if let trip = trips.first(where: { $0.id == tripID }) {
                                    compactTripDetail(for: trip)
                                } else {
                                    noSelectionView
                                }
                            case .activity(let route):
                                if let selectedTrip,
                                   let destination = TripRouteMapper.destination(from: route, in: selectedTrip) {
                                    tripDestinationView(destination)
                                } else {
                                    noSelectionView
                                }
                            }
                        }
                }
            } else {
                #if os(macOS)
                HStack(spacing: 0) {
                    listContent
                        .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)
                    Divider()
                    Group {
                        if let selectedTrip {
                            regularTripDetail(for: selectedTrip)
                        } else {
                            noSelectionView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                #else
                NavigationSplitView {
                    listContent
                } detail: {
                    if let selectedTrip {
                        regularTripDetail(for: selectedTrip)
                    } else {
                        noSelectionView
                    }
                }
                #endif
            }
        }
    }

    private var noSelectionView: some View {
        ContentUnavailableView(
            NSLocalizedString("navigation.detail.selectItem.title", value: "Select an Item", comment: "Title when no item is selected"),
            systemImage: "sidebar.left",
            description: Text(NSLocalizedString("navigation.detail.selectItem.description", value: "Choose an item from the list to view details", comment: "Description when no item is selected"))
        )
    }

    private var listContent: some View {
        VStack(spacing: 0) {
            SearchBarView.general(
                text: $searchText,
                placeholder: NSLocalizedString("navigation.trips.search", value: "Search trips...", comment: "Trips search placeholder")
            )
            .padding(.top, 8)
            .accessibilityIdentifier("SearchBar")
            .accessibilityLabel("Search trips")

            if filteredTrips.isEmpty {
                ContentUnavailableView(
                    NSLocalizedString("navigation.trips.empty.title", value: "No Trips", comment: "Empty trips title"),
                    systemImage: "airplane",
                    description: Text(NSLocalizedString("navigation.trips.empty.description", value: "Create your first trip to get started", comment: "Empty trips description"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredTrips) { trip in
                    let isSelected = selectedTripID == trip.id
                    Button {
                        let isReselect = isSelected
                        onTripSelection(trip, isReselect)
                    } label: {
                        EnhancedItemRowView(item: trip, isSelected: isSelected)
                            .modifier(ItemRowModifier(item: trip))
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .scrollContentBackground(.visible)
                .accessibilityIdentifier("TripsListView")
                .accessibilityLabel("Trips list")
            }
        }
        .navigationTitle(NSLocalizedString("navigation.trips.title", value: "Trips", comment: "Trips navigation title"))
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                HStack(spacing: 12) {
                    if hiddenPastTripsCount > 0 {
                        Button {
                            withAnimation { hidePastTrips.toggle() }
                        } label: {
                            Label(
                                hidePastTrips ? "\(hiddenPastTripsCount) past hidden" : "Showing all",
                                systemImage: hidePastTrips ? "eye.slash" : "eye"
                            )
                        }
                        .accessibilityIdentifier("TogglePastTrips")
                    }

                    Button {
                        activeSheet = .addTrip
                    } label: {
                        Label(NSLocalizedString("navigation.trips.add", value: "Add Trip", comment: "Add trip button"), systemImage: "plus")
                    }
                    .accessibilityIdentifier("AddButton_Trips")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addTrip:
                AddTrip(
                    store: StoreOf<AddTripFeature>.init(initialState: AddTripFeature.State()) {
                        AddTripFeature()
                    }
                )
            }
        }
    }

    private func compactTripDetail(for trip: Trip) -> some View {
        IsolatedTripDetailView(
            trip: trip,
            path: Binding(
                get: { tripPath },
                set: { newPath in
                    tripPath = newPath
                    if selectedTripID == nil {
                        selectedTripID = trip.id
                    }
                }
            ),
            resetToken: tripResetToken,
            store: Store(
                initialState: TripDetailFeature.State(
                    trip: trip,
                    initialPath: tripPath,
                    resetToken: tripResetToken
                )
            ) {
                TripDetailFeature()
            }
        )
    }

    private func regularTripDetail(for trip: Trip) -> some View {
        NavigationStack(path: $tripPath) {
            IsolatedTripDetailView(
                trip: trip,
                path: $tripPath,
                resetToken: tripResetToken,
                store: Store(
                    initialState: TripDetailFeature.State(
                        trip: trip,
                        initialPath: tripPath,
                        resetToken: tripResetToken
                    )
                ) {
                    TripDetailFeature()
                }
            )
            .navigationDestination(for: TripRoute.self) { route in
                if let destination = TripRouteMapper.destination(from: route, in: trip) {
                    tripDestinationView(destination)
                } else {
                    noSelectionView
                }
            }
        }
    }

    @ViewBuilder
    private func tripDestinationView(_ destination: DestinationType) -> some View {
        switch destination {
        case .lodging(let lodging):
            TripActivityDetailView<Lodging>(
                activity: lodging,
                store: Store(
                    initialState: TripActivityDetailFeature.State(
                        snapshot: TripActivityDetailFeature.ActivityTarget(activity: lodging)
                    )
                ) {
                    TripActivityDetailFeature()
                }
            )
        case .transportation(let transportation):
            TripActivityDetailView<Transportation>(
                activity: transportation,
                store: Store(
                    initialState: TripActivityDetailFeature.State(
                        snapshot: TripActivityDetailFeature.ActivityTarget(activity: transportation)
                    )
                ) {
                    TripActivityDetailFeature()
                }
            )
        case .activity(let activity):
            TripActivityDetailView<Activity>(
                activity: activity,
                store: Store(
                    initialState: TripActivityDetailFeature.State(
                        snapshot: TripActivityDetailFeature.ActivityTarget(activity: activity)
                    )
                ) {
                    TripActivityDetailFeature()
                }
            )
        }
    }
}
