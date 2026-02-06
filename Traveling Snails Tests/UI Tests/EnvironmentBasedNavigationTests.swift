//
//  EnvironmentBasedNavigationTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Environment Based Navigation Tests")
struct EnvironmentBasedNavigationTests {
    @Test("Trip selection does not require router clear signal", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func tripSelectionWithoutRouterSignal() async {
        let tripID = UUID()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.navigation(.selectTrip(tripID, source: .tripList))) {
            $0.navigation.selectedTripID = tripID
            $0.navigation.selectedTab = .trips
            $0.navigation.tripDetailPathByTripID[tripID] = []
        }
    }
}
