//
//  AppFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData
import SwiftUI

enum TripRoute: Hashable {
    case lodging(UUID)
    case transportation(UUID)
    case activity(UUID)
}

@Reducer
struct AppFeature {
    enum AppTab: Int, CaseIterable, Hashable {
        case trips
        case collections
        case organizations
        case settings
    }

    enum NavigationSource: Equatable {
        case tripList
        case organization
        case deepLink
        case external
    }

    enum ClearTripSelectionReason: Equatable {
        case explicit
        case tripDeleted
        case switchedContext
    }

    @ObservableState
    struct NavigationState {
        var selectedTab: AppTab = .trips
        var selectedTripID: Trip.ID?
        var selectedOrganizationID: Organization.ID?
        var selectedCollectionID: Collection.ID?
        var tripDetailPathByTripID: [Trip.ID: [TripRoute]] = [:]
        var tripReselectTokenByTripID: [Trip.ID: Int] = [:]
    }

    enum NavigationAction: Equatable {
        case selectTab(AppTab)
        case selectTrip(Trip.ID, source: NavigationSource)
        case selectOrganization(Organization.ID)
        case selectCollection(Collection.ID)
        case reselectTrip(Trip.ID)
        case clearTripSelection(reason: ClearTripSelectionReason)
        case restoreTabNavigation(AppTab)
        case setTripDetailPath(Trip.ID, [TripRoute])
        case reconcileAvailableTrips([Trip.ID])
        case reconcileAvailableOrganizations([Organization.ID])
        case reconcileAvailableCollections([Collection.ID])
    }

    @ObservableState
    struct State {
        var isInitialSyncComplete = false
        var showingSyncIndicator = false
        var navigation = NavigationState()
        var trips = TripsFeature.State()
        var collections = CollectionsFeature.State()
        var organizations = OrganizationsFeature.State()
        var settings = SettingsFeature.State()
    }

    enum Action {
        case onAppear
        case syncIndicatorFinished
        case scenePhaseChanged(ScenePhase)
        case periodicSyncTick
        case navigation(NavigationAction)
        case trips(TripsFeature.Action)
        case collections(CollectionsFeature.Action)
        case organizations(OrganizationsFeature.Action)
        case settings(SettingsFeature.Action)
    }

    @Dependency(\.continuousClock) var clock
    @Dependency(\.defaultSyncEngine) var syncEngine
    @Dependency(\.biometricAuthClient) var biometricAuthClient

    private enum CancelID {
        case syncIndicator
        case periodicSync
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.trips, action: \.trips) {
            TripsFeature()
        }
        Scope(state: \.collections, action: \.collections) {
            CollectionsFeature()
        }
        Scope(state: \.organizations, action: \.organizations) {
            OrganizationsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Reduce { state, action in
            switch action {
            case .onAppear:
                if !state.isInitialSyncComplete && state.trips.trips.isEmpty {
                    state.showingSyncIndicator = true
                    return .run { send in
                        try await clock.sleep(for: .seconds(2))
                        await send(.syncIndicatorFinished)
                    }
                    .cancellable(id: CancelID.syncIndicator, cancelInFlight: true)
                }
                return .merge(
                    .run { _ in
                        do {
                            try await syncEngine.start()
                        } catch {
                            Logger.shared.error("SyncEngine start failed: \(error.localizedDescription)", category: .database)
                        }
                    },
                    startPeriodicSync()
                )

            case .syncIndicatorFinished:
                state.isInitialSyncComplete = true
                state.showingSyncIndicator = false
                return .none

            case .scenePhaseChanged(let phase):
                if phase == .background {
                    return .run { _ in
                        await biometricAuthClient.resetSession()
                    }
                }
                if phase == .active {
                    return .run { _ in
                        try await syncEngine.sendChanges()
                    }
                }
                return .none

            case .periodicSyncTick:
                return .run { _ in
                    try await syncEngine.sendChanges()
                }

            case .navigation(let navAction):
                reduceNavigation(into: &state, action: navAction)
                return .none

            case .trips, .collections, .organizations, .settings:
                return .none
            }
        }
    }

    private func reduceNavigation(into state: inout State, action: NavigationAction) {
        switch action {
        case .selectTab(let tab):
            #if DEBUG
            Logger.shared.debug("AppNavigation selectTab: \(String(describing: tab))", category: .navigation)
            #endif
            state.navigation.selectedTab = tab

        case .selectTrip(let tripID, _):
            #if DEBUG
            Logger.shared.debug("AppNavigation selectTrip: \(tripID)", category: .navigation)
            #endif
            if state.navigation.selectedTripID == tripID {
                state.navigation.tripDetailPathByTripID[tripID] = []
                state.navigation.tripReselectTokenByTripID[tripID, default: 0] += 1
            } else {
                state.navigation.selectedTripID = tripID
                state.navigation.tripDetailPathByTripID[tripID] = []
            }
            state.navigation.selectedTab = .trips

        case .selectOrganization(let organizationID):
            #if DEBUG
            Logger.shared.debug("AppNavigation selectOrganization: \(organizationID)", category: .navigation)
            #endif
            state.navigation.selectedOrganizationID = organizationID
            state.navigation.selectedTab = .organizations

        case .selectCollection(let collectionID):
            #if DEBUG
            Logger.shared.debug("AppNavigation selectCollection: \(collectionID)", category: .navigation)
            #endif
            state.navigation.selectedCollectionID = collectionID
            state.navigation.selectedTab = .collections

        case .reselectTrip(let tripID):
            #if DEBUG
            Logger.shared.debug("AppNavigation reselectTrip: \(tripID)", category: .navigation)
            #endif
            if state.navigation.selectedTripID == tripID {
                state.navigation.tripDetailPathByTripID[tripID] = []
                state.navigation.tripReselectTokenByTripID[tripID, default: 0] += 1
            } else {
                state.navigation.selectedTripID = tripID
                state.navigation.tripDetailPathByTripID[tripID] = []
                state.navigation.selectedTab = .trips
            }

        case .clearTripSelection:
            #if DEBUG
            Logger.shared.debug("AppNavigation clearTripSelection", category: .navigation)
            #endif
            state.navigation.selectedTripID = nil

        case .restoreTabNavigation(let tab):
            #if DEBUG
            Logger.shared.debug("AppNavigation restoreTabNavigation: \(String(describing: tab))", category: .navigation)
            #endif
            state.navigation.selectedTab = tab

        case .setTripDetailPath(let tripID, let path):
            #if DEBUG
            Logger.shared.debug("AppNavigation setTripDetailPath: \(tripID), count: \(path.count)", category: .navigation)
            #endif
            state.navigation.tripDetailPathByTripID[tripID] = path

        case .reconcileAvailableTrips(let availableTrips):
            let validIDs = Set(availableTrips)
            // SQLite-backed query snapshots can momentarily emit an empty list during updates.
            // Ignore empty snapshots so iOS compact navigation does not bounce back spuriously.
            guard !validIDs.isEmpty else {
                #if DEBUG
                Logger.shared.debug("AppNavigation reconcileAvailableTrips ignored empty snapshot", category: .navigation)
                #endif
                return
            }
            if let selected = state.navigation.selectedTripID,
               !validIDs.contains(selected) {
                #if DEBUG
                Logger.shared.debug("AppNavigation reconcileAvailableTrips clearing stale selection: \(selected)", category: .navigation)
                #endif
                state.navigation.selectedTripID = nil
            }
            state.navigation.tripDetailPathByTripID = state.navigation.tripDetailPathByTripID.filter { validIDs.contains($0.key) }
            state.navigation.tripReselectTokenByTripID = state.navigation.tripReselectTokenByTripID.filter { validIDs.contains($0.key) }

        case .reconcileAvailableOrganizations(let availableOrganizations):
            let validIDs = Set(availableOrganizations)
            if let selected = state.navigation.selectedOrganizationID,
               !validIDs.contains(selected) {
                state.navigation.selectedOrganizationID = nil
            }

        case .reconcileAvailableCollections(let availableCollections):
            let validIDs = Set(availableCollections)
            guard !validIDs.isEmpty else { return }
            if let selected = state.navigation.selectedCollectionID,
               !validIDs.contains(selected) {
                state.navigation.selectedCollectionID = nil
            }
        }
    }

    private func startPeriodicSync() -> Effect<Action> {
        .run { send in
            for await _ in clock.timer(interval: .seconds(30)) {
                await send(.periodicSyncTick)
            }
        }
        .cancellable(id: CancelID.periodicSync, cancelInFlight: true)
    }
}

extension AppFeature.NavigationState: Equatable {}

extension AppFeature.State: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        let coreEqual =
            lhs.isInitialSyncComplete == rhs.isInitialSyncComplete &&
            lhs.showingSyncIndicator == rhs.showingSyncIndicator &&
            lhs.navigation == rhs.navigation
        let childrenEqual =
            lhs.trips.trips.map(\.id) == rhs.trips.trips.map(\.id) &&
            lhs.collections.collections.map(\.id) == rhs.collections.collections.map(\.id) &&
            lhs.organizations.organizations.map(\.id) == rhs.organizations.organizations.map(\.id)
        let settingsEqual1 =
            lhs.settings.activeSheet == rhs.settings.activeSheet &&
            lhs.settings.showingImportPicker == rhs.settings.showingImportPicker &&
            lhs.settings.importError == rhs.settings.importError &&
            lhs.settings.showingImportError == rhs.settings.showingImportError &&
            lhs.settings.showingOrganizationCleanupAlert == rhs.settings.showingOrganizationCleanupAlert &&
            lhs.settings.organizationCleanupMessage == rhs.settings.organizationCleanupMessage
        let settingsEqual2 =
            lhs.settings.allTripsLocked == rhs.settings.allTripsLocked &&
            lhs.settings.canUseBiometrics == rhs.settings.canUseBiometrics &&
            lhs.settings.isFaceID == rhs.settings.isFaceID &&
            lhs.settings.colorSchemePreference == rhs.settings.colorSchemePreference &&
            lhs.settings.biometricTimeoutMinutes == rhs.settings.biometricTimeoutMinutes
        return coreEqual && childrenEqual && settingsEqual1 && settingsEqual2
    }
}
