import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("TripDetailFeature Tests")
@MainActor
struct TripDetailFeatureTests {
    @Test("Add Activity sets active sheet")
    func addActivitySetsActiveSheet() async {
        let trip = Trip(name: "Test")
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addActivityTapped) {
            $0.activeSheet = .addActivity
        }
    }

    @Test("Add Lodging sets active sheet")
    func addLodgingSetsActiveSheet() async {
        let trip = Trip(name: "Test")
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addLodgingTapped) {
            $0.activeSheet = .addLodging
        }
    }

    @Test("Add Transportation sets active sheet")
    func addTransportationSetsActiveSheet() async {
        let trip = Trip(name: "Test")
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addTransportationTapped) {
            $0.activeSheet = .addTransportation
        }
    }

    @Test("Active sheet survives auth state refresh updates")
    func activeSheetSurvivesAuthStateUpdates() async {
        let trip = Trip(name: "Test")
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addActivityTapped) {
            $0.activeSheet = .addActivity
        }

        await store.send(
            .authStateLoaded(
                canUseBiometrics: true,
                biometricAuthEnabled: true,
                isTripProtected: false,
                isLocallyAuthenticated: true,
                isFaceID: true
            )
        ) {
            $0.canUseBiometrics = true
            $0.biometricAuthEnabled = true
            $0.isTripProtected = false
            $0.isLocallyAuthenticated = true
            $0.isFaceID = true
        }
    }

    @Test("Active sheet survives external path sync")
    func activeSheetSurvivesExternalPathSync() async {
        let trip = Trip(name: "Test")
        let route = TripRoute.activity(UUID())
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addLodgingTapped) {
            $0.activeSheet = .addLodging
        }

        await store.send(.externalPathChanged([route])) {
            $0.path = [route]
        }
    }

    @Test("Active sheet survives reset token path clear")
    func activeSheetSurvivesResetToken() async {
        let trip = Trip(name: "Test")
        let route = TripRoute.transportation(UUID())
        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [route],
                resetToken: 1
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.addTransportationTapped) {
            $0.activeSheet = .addTransportation
        }

        await store.send(.resetTokenChanged(2)) {
            $0.resetToken = 2
            $0.lastHandledResetToken = 2
            $0.path = []
        }
    }

    @Test("Selecting activity appends route")
    func activitySelectionAppendsPath() async {
        let trip = Trip(name: "Test")

        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        }

        let route = TripRoute.activity(UUID())

        await store.send(.activitySelected(route)) {
            $0.path = [route]
        }
    }

    @Test("New reset token clears existing path")
    func resetTokenClearsPath() async {
        let trip = Trip(name: "Test")
        let existingRoute = TripRoute.lodging(UUID())

        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [existingRoute],
                resetToken: 1
            )
        ) {
            TripDetailFeature()
        }

        await store.send(.resetTokenChanged(2)) {
            $0.resetToken = 2
            $0.lastHandledResetToken = 2
            $0.path = []
        }
    }

    @Test("Protect toggle when unprotected toggles protection and refreshes state")
    func protectToggleFlow() async {
        let trip = Trip(name: "Protected")
        let toggled = ToggleFlag()

        let store = TestStore(
            initialState: TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        ) {
            TripDetailFeature()
        } withDependencies: {
            $0.biometricAuthClient = .init(
                canUseBiometrics: { true },
                isEnabled: { true },
                biometricType: { .faceID },
                isProtected: { _ in await toggled.value },
                isAuthenticated: { _ in true },
                authenticateTrip: { _ in true },
                lockTrip: { _ in },
                toggleProtection: { _ in
                    await toggled.setValue(true)
                },
                resetSession: {}
            )
        }

        await store.send(.protectTapped)

        await store.receive(\.refreshAuthState)
        await store.receive(\.authStateLoaded) {
            $0.canUseBiometrics = true
            $0.biometricAuthEnabled = true
            $0.isTripProtected = true
            $0.isLocallyAuthenticated = true
            $0.isFaceID = true
        }
    }
}

private actor ToggleFlag {
    private(set) var value = false

    func setValue(_ newValue: Bool) {
        value = newValue
    }
}
