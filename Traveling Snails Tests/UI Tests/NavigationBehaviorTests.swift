//
//  NavigationBehaviorTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Navigation Behavior Tests")
struct NavigationBehaviorTests {
    @Test("Reselecting an active trip pops to root via state", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func reselectActiveTripPopsToRoot() async {
        let tripID = UUID()
        let activityID = UUID()
        var initial = AppFeature.State()
        initial.navigation.selectedTripID = tripID
        initial.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.navigation(.selectTrip(tripID, source: .tripList))) {
            $0.navigation.tripDetailPathByTripID[tripID] = []
            $0.navigation.tripReselectTokenByTripID[tripID] = 1
            $0.navigation.selectedTab = .trips
        }
    }
}
