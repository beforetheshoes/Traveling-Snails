//
//  AppNavigationFeatureTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("App Navigation Feature Tests")
struct AppNavigationFeatureTests {
    @Test("Selecting a trip sets tab and selected trip", .tags(.unit, .fast, .parallel, .navigation))
    func selectingTripSetsState() async {
        let tripID = UUID()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

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
        var initialState = AppFeature.State()
        initialState.navigation.selectedTab = .trips
        initialState.navigation.selectedTripID = tripID
        initialState.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]

        let store = TestStore(initialState: initialState) {
            AppFeature()
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
        var initialState = AppFeature.State()
        initialState.navigation.selectedTab = .trips
        initialState.navigation.selectedTripID = tripID
        initialState.navigation.tripDetailPathByTripID[tripID] = [.activity(activityID)]

        let store = TestStore(initialState: initialState) {
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

    @Test("Reconciling available trips clears deleted selected trip", .tags(.unit, .fast, .parallel, .navigation, .regression))
    func deletedTripIsCleared() async {
        let existingTrip = UUID()
        let deletedTrip = UUID()

        var initialState = AppFeature.State()
        initialState.navigation.selectedTripID = deletedTrip
        initialState.navigation.tripDetailPathByTripID[deletedTrip] = []
        initialState.navigation.tripDetailPathByTripID[existingTrip] = []

        let store = TestStore(initialState: initialState) {
            AppFeature()
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
        var initialState = AppFeature.State()
        initialState.navigation.selectedTab = .organizations

        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.navigation(.selectTrip(tripID, source: .organization))) {
            $0.navigation.selectedTab = .trips
            $0.navigation.selectedTripID = tripID
            $0.navigation.tripDetailPathByTripID[tripID] = []
        }
    }
}
