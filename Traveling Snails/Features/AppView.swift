//
//  AppView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    @AppStorage("colorScheme") private var colorSchemeRawValue = ColorSchemePreference.system.rawValue
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let state = store.state
        rootContent(state: state)
            .preferredColorScheme(colorSchemePreference.colorScheme)
            .onAppear { store.send(.onAppear) }
            .onChange(of: scenePhase) { _, newPhase in
                store.send(.scenePhaseChanged(newPhase))
            }
            .onChange(of: state.trips.trips.map(\.id)) { _, ids in
                store.send(.navigation(.reconcileAvailableTrips(ids)))
            }
            .onChange(of: state.collections.collections.map(\.id)) { _, ids in
                store.send(.navigation(.reconcileAvailableCollections(ids)))
            }
            .onChange(of: state.organizations.organizations.map(\.id)) { _, ids in
                store.send(.navigation(.reconcileAvailableOrganizations(ids)))
            }


    }

    @ViewBuilder
    private func rootContent(state: AppFeature.State) -> some View {
        if !state.isInitialSyncComplete && state.trips.trips.isEmpty {
            CloudKitSyncIndicatorView(isVisible: .constant(true))
        } else {
            mainContent(state: state)
        }
    }

    @ViewBuilder
    private func mainContent(state: AppFeature.State) -> some View {
        #if os(macOS)
        MacAppView(store: store)
        #else
        let selectedTabBinding = Binding(
            get: { store.state.navigation.selectedTab },
            set: { store.send(.navigation(.selectTab($0))) }
        )
        let selectedTripIDBinding = Binding(
            get: { store.state.navigation.selectedTripID },
            set: { newID in
                if let newID {
                    store.send(.navigation(.selectTrip(newID, source: .tripList)))
                }
            }
        )
        let selectedCollectionIDBinding = Binding(
            get: { store.state.navigation.selectedCollectionID },
            set: { newID in
                if let newID {
                    store.send(.navigation(.selectCollection(newID)))
                }
            }
        )
        let selectedOrganizationIDBinding = Binding(
            get: { store.state.navigation.selectedOrganizationID },
            set: { newID in
                if let newID {
                    store.send(.navigation(.selectOrganization(newID)))
                }
            }
        )

        let selectedTripPathBinding = Binding(
            get: {
                guard let selectedTripID = store.state.navigation.selectedTripID else { return [] }
                return store.state.navigation.tripDetailPathByTripID[selectedTripID] ?? []
            },
            set: { (newPath: [TripRoute]) in
                guard let selectedTripID = store.state.navigation.selectedTripID else { return }
                store.send(.navigation(.setTripDetailPath(selectedTripID, newPath)))
            }
        )

        let tripResetToken: Int = {
            guard let selectedTripID = store.state.navigation.selectedTripID else { return 0 }
            return store.state.navigation.tripReselectTokenByTripID[selectedTripID, default: 0]
        }()

        TabView(selection: selectedTabBinding) {
            Tab("Trips", systemImage: "airplane", value: AppFeature.AppTab.trips) {
                TripsNavigationView(
                    store: store.scope(state: \.trips, action: \.trips),
                    selectedTripID: selectedTripIDBinding,
                    tripPath: selectedTripPathBinding,
                    tripResetToken: tripResetToken,
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
            }

            Tab("Collections", systemImage: "square.stack", value: AppFeature.AppTab.collections) {
                CollectionsNavigationView(
                    store: store.scope(state: \.collections, action: \.collections),
                    selectedCollectionID: selectedCollectionIDBinding,
                    onCollectionSelected: { collection in
                        store.send(.navigation(.selectCollection(collection.id)))
                    }
                )
            }

            Tab("Organizations", systemImage: "building.2", value: AppFeature.AppTab.organizations) {
                OrganizationsNavigationView(
                    store: store.scope(state: \.organizations, action: \.organizations),
                    selectedOrganizationID: selectedOrganizationIDBinding,
                    onOrganizationSelection: { organization in
                        store.send(.navigation(.selectOrganization(organization.id)))
                    },
                    onOpenTrip: { tripID in
                        store.send(.navigation(.selectTrip(tripID, source: .organization)))
                        store.send(.navigation(.selectTab(.trips)))
                    }
                )
            }

            Tab("Settings", systemImage: "gear", value: AppFeature.AppTab.settings) {
                SettingsRootView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
        #endif
    }

    private var colorSchemePreference: ColorSchemePreference {
        ColorSchemePreference(rawValue: colorSchemeRawValue) ?? .system
    }
}

