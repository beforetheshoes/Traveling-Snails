//
//  AppNavigationFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("App Navigation Feature Tests")
@MainActor
struct AppNavigationFeatureTests {
    @Test("Selecting a trip sets tab and selected trip", .tags(.unit, .fast, .parallel, .navigation))
    func selectingTripSetsState() async {
        let tripID = UUID()
        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database)

        await store.send(.navigation(.selectTrip(tripID, source: .tripList))) {
            $0.navigation.selectedTab = .trips
            $0.navigation.selectedTripID = tripID
            $0.navigation.tripDetailPathByTripID[tripID] = []
        }
    }

    @Test("Reselecting selected trip resets detail path and bumps token", .tags(.unit, .fast, .parallel, .navigation))
    func reselectingTripResetsPathAndToken() async {
        let tripID = UUID()
        let activityID = UUID()
        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database) { state in
            state.navigation.selectedTab = .trips
            state.navigation.selectedTripID = tripID
            state.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]
        }

        await store.send(.navigation(.reselectTrip(tripID))) {
            $0.navigation.tripDetailPathByTripID[tripID] = []
            $0.navigation.tripReselectTokenByTripID[tripID] = 1
        }
    }

    @Test("Tab switch preserves selected trip and path for restoration", .tags(.unit, .fast, .parallel, .navigation))
    func tabSwitchPreservesTripNavigation() async {
        let tripID = UUID()
        let activityID = UUID()
        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database) { state in
            state.navigation.selectedTab = .trips
            state.navigation.selectedTripID = tripID
            state.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]
        }

        await store.send(.navigation(.selectTab(.organizations))) {
            $0.navigation.selectedTab = .organizations
        }

        await store.send(.navigation(.restoreTabNavigation(.trips))) {
            $0.navigation.selectedTab = .trips
        }

        #expect(store.state.navigation.selectedTripID == tripID)
        #expect(store.state.navigation.tripDetailPathByTripID[tripID]?.count == 1)
    }

    @Test("Reconciling available trips clears deleted selected trip", .tags(.unit, .fast, .parallel, .navigation, .regression))
    func deletedTripIsCleared() async {
        let existingTrip = UUID()
        let deletedTrip = UUID()

        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database) { state in
            state.navigation.selectedTripID = deletedTrip
            state.navigation.tripDetailPathByTripID[deletedTrip] = []
            state.navigation.tripDetailPathByTripID[existingTrip] = []
        }

        await store.send(.navigation(.reconcileAvailableTrips([existingTrip]))) {
            $0.navigation.selectedTripID = nil
            $0.navigation.tripDetailPathByTripID = [existingTrip: []]
            $0.navigation.tripReselectTokenByTripID = [:]
        }
    }

    @Test("Organization initiated trip open selects trip and tab", .tags(.unit, .fast, .parallel, .navigation))
    func organizationInitiatedTripOpen() async {
        let tripID = UUID()
        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database) { state in
            state.navigation.selectedTab = .organizations
        }

        await store.send(.navigation(.selectTrip(tripID, source: .organization))) {
            $0.navigation.selectedTab = .trips
            $0.navigation.selectedTripID = tripID
            $0.navigation.tripDetailPathByTripID[tripID] = []
        }
    }
}

private func makeStore(
    database: DatabaseQueue,
    configureState: (inout AppFeature.State) -> Void = { _ in }
) -> TestStore<AppFeature.State, AppFeature.Action> {
    let initialState = withDependencies {
        $0.defaultDatabase = database
    } operation: {
        var state = AppFeature.State()
        configureState(&state)
        return state
    }

    return TestStore(initialState: initialState) {
        AppFeature()
    } withDependencies: {
        $0.defaultDatabase = database
    }
}

private func makeNavigationTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    return database
}
