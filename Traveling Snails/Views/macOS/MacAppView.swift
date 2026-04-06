//
//  MacAppView.swift
//  Traveling Snails
//
//  Native macOS layout using NavigationSplitView with sidebar.
//

#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct MacAppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        let state = store.state

        NavigationSplitView(columnVisibility: .constant(.all)) {
            MacSidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 130, ideal: 160, max: 260)
        } detail: {
            switch state.navigation.selectedTab {
            case .trips:
                TripsNavigationView(
                    store: store.scope(state: \.trips, action: \.trips),
                    selectedTripID: Binding(
                        get: { store.state.navigation.selectedTripID },
                        set: { newID in
                            if let newID {
                                store.send(.navigation(.selectTrip(newID, source: .tripList)))
                            }
                        }
                    ),
                    tripPath: Binding(
                        get: {
                            guard let selectedTripID = store.state.navigation.selectedTripID else { return [] }
                            return store.state.navigation.tripDetailPathByTripID[selectedTripID] ?? []
                        },
                        set: { newPath in
                            guard let selectedTripID = store.state.navigation.selectedTripID else { return }
                            store.send(.navigation(.setTripDetailPath(selectedTripID, newPath)))
                        }
                    ),
                    tripResetToken: {
                        guard let selectedTripID = store.state.navigation.selectedTripID else { return 0 }
                        return store.state.navigation.tripReselectTokenByTripID[selectedTripID, default: 0]
                    }(),
                    onClearTripSelection: {
                        store.send(.navigation(.clearTripSelection(reason: .explicit)))
                    },
                    onTripSelection: { trip, isReselect in
                        if isReselect {
                            store.send(.navigation(.reselectTrip(trip.id)))
                        } else {
                            store.send(.navigation(.selectTrip(trip.id, source: .tripList)))
                        }
                    }
                )

            case .collections:
                CollectionsNavigationView(
                    store: store.scope(state: \.collections, action: \.collections),
                    selectedCollectionID: Binding(
                        get: { store.state.navigation.selectedCollectionID },
                        set: { newID in
                            if let newID {
                                store.send(.navigation(.selectCollection(newID)))
                            }
                        }
                    ),
                    onCollectionSelected: { collection in
                        store.send(.navigation(.selectCollection(collection.id)))
                    }
                )

            case .organizations:
                OrganizationsNavigationView(
                    store: store.scope(state: \.organizations, action: \.organizations),
                    selectedOrganizationID: Binding(
                        get: { store.state.navigation.selectedOrganizationID },
                        set: { newID in
                            if let newID {
                                store.send(.navigation(.selectOrganization(newID)))
                            }
                        }
                    ),
                    onOrganizationSelection: { organization in
                        store.send(.navigation(.selectOrganization(organization.id)))
                    },
                    onOpenTrip: { tripID in
                        store.send(.navigation(.selectTrip(tripID, source: .organization)))
                        store.send(.navigation(.selectTab(.trips)))
                    }
                )

            case .settings:
                SettingsRootView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, idealWidth: 1100, minHeight: 600, idealHeight: 750)
    }
}
#endif
