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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private var filteredTrips: [Trip] {
        guard !searchText.isEmpty else { return trips }
        return trips.filter { trip in
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
                if selectedTripID != newSelectedTripID {
                    selectedTripID = newSelectedTripID
                }
                let newTripPath = newPath.dropFirst().compactMap { route -> TripRoute? in
                    guard case let .activity(activityRoute) = route else { return nil }
                    return activityRoute
                }
                if tripPath != newTripPath {
                    tripPath = newTripPath
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
                NavigationSplitView {
                    listContent
                } detail: {
                    if let selectedTrip {
                        regularTripDetail(for: selectedTrip)
                    } else {
                        noSelectionView
                    }
                }
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
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    activeSheet = .addTrip
                } label: {
                    Label(NSLocalizedString("navigation.trips.add", value: "Add Trip", comment: "Add trip button"), systemImage: "plus")
                }
                .accessibilityIdentifier("AddButton_Trips")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addTrip:
                AddTrip()
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
            resetToken: tripResetToken
        )
    }

    private func regularTripDetail(for trip: Trip) -> some View {
        NavigationStack(path: $tripPath) {
            IsolatedTripDetailView(
                trip: trip,
                path: $tripPath,
                resetToken: tripResetToken
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
            TripActivityDetailView<Lodging>(activity: lodging)
        case .transportation(let transportation):
            TripActivityDetailView<Transportation>(activity: transportation)
        case .activity(let activity):
            TripActivityDetailView<Activity>(activity: activity)
        }
    }
}
