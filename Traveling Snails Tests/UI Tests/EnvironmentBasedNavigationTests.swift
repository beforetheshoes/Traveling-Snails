//
//  EnvironmentBasedNavigationTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("Environment Based Navigation Tests")
@MainActor
struct EnvironmentBasedNavigationTests {
    @Test("Trip selection does not require router clear signal", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func tripSelectionWithoutRouterSignal() async {
        let tripID = UUID()
        let database = try! makeNavigationTestDatabase()
        let initialState = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            AppFeature.State()
        }
        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.navigation(.selectTrip(tripID, source: .tripList))) {
            $0.navigation.selectedTripID = tripID
            $0.navigation.selectedTab = .trips
            $0.navigation.tripDetailPathByTripID[tripID] = []
        }
    }
}

private func makeNavigationTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    return database
}
