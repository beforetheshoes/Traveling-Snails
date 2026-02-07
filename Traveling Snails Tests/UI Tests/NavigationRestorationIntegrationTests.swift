//
//  NavigationRestorationIntegrationTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("Navigation Restoration Integration Tests")
@MainActor
struct NavigationRestorationIntegrationTests {
    @Test("Tab switch preserves in-session trip selection and path", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func tabSwitchPreservesSessionState() async {
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
