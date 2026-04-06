//
//  NavigationBehaviorTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("Navigation Behavior Tests")
@MainActor
struct NavigationBehaviorTests {
    @Test("Reselecting an active trip pops to root via state", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func reselectActiveTripPopsToRoot() async {
        let tripID = UUID()
        let activityID = UUID()
        let database = try! makeNavigationTestDatabase()
        let store = makeStore(database: database) { state in
            state.navigation.selectedTripID = tripID
            state.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]
        }

        await store.send(.navigation(.selectTrip(tripID, source: .tripList))) {
            $0.navigation.tripDetailPathByTripID[tripID] = []
            $0.navigation.tripReselectTokenByTripID[tripID] = 1
            $0.navigation.selectedTab = .trips
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
