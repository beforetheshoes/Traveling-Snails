//
//  AppView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    @Environment(ModernAppSettings.self) private var appSettings
    @Environment(ModernSyncManager.self) private var syncManager
    @Environment(ModernBiometricAuthManager.self) private var biometricAuthManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let state = store.state
        Group {
            if !state.isInitialSyncComplete && state.trips.trips.isEmpty {
                CloudKitSyncIndicatorView(isVisible: .constant(true))
            } else {
                mainContent(state: state)
            }
        }
        .preferredColorScheme(appSettings.colorScheme.colorScheme)
        .onAppear { store.send(.onAppear) }
        .onChange(of: scenePhase) { _, newPhase in
            store.send(.scenePhaseChanged(newPhase))
        }
        .onChange(of: state.trips.trips.map(\.id)) { _, ids in
            store.send(.navigation(.reconcileAvailableTrips(ids)))
        }
        .onChange(of: state.organizations.organizations.map(\.id)) { _, ids in
            store.send(.navigation(.reconcileAvailableOrganizations(ids)))
        }
    }

    @ViewBuilder
    private func mainContent(state: AppFeature.State) -> some View {
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

        #if os(iOS)
        TabView(selection: selectedTabBinding) {
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
            .tabItem { Label("Trips", systemImage: "airplane") }
            .tag(AppFeature.AppTab.trips)

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
            .tabItem { Label("Organizations", systemImage: "building.2") }
            .tag(AppFeature.AppTab.organizations)

            SettingsRootView(
                store: store.scope(state: \.settings, action: \.settings)
            )
            .tabItem { Label("Settings", systemImage: "gear") }
            .tag(AppFeature.AppTab.settings)
        }
        #else
        NavigationSplitView {
            List {
                Button("Trips") { store.send(.navigation(.selectTab(.trips))) }
                    .listRowBackground(state.navigation.selectedTab == .trips ? Color.blue.opacity(0.2) : Color.clear)
                Button("Organizations") { store.send(.navigation(.selectTab(.organizations))) }
                    .listRowBackground(state.navigation.selectedTab == .organizations ? Color.blue.opacity(0.2) : Color.clear)
                Button("Settings") { store.send(.navigation(.selectTab(.settings))) }
                    .listRowBackground(state.navigation.selectedTab == .settings ? Color.blue.opacity(0.2) : Color.clear)
            }
            .navigationTitle("Traveling Snails")
        } detail: {
            switch state.navigation.selectedTab {
            case .trips:
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
            case .organizations:
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
            case .settings:
                SettingsRootView(
                    store: store.scope(state: \.settings, action: \.settings)
                )
            }
        }
        #endif
    }
}
