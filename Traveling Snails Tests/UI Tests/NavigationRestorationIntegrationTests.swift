//
//  NavigationRestorationIntegrationTests.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Navigation Restoration Integration Tests")
struct NavigationRestorationIntegrationTests {
    @Test("Tab switch preserves in-session trip selection and path", .tags(.ui, .fast, .parallel, .navigation, .regression))
    func tabSwitchPreservesSessionState() async {
        let tripID = UUID()
        let activityID = UUID()
        var initial = AppFeature.State()
        initial.navigation.selectedTab = .trips
        initial.navigation.selectedTripID = tripID
        initial.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]

        let store = TestStore(initialState: initial) {
            AppFeature()
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
