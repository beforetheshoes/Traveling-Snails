import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("Trip Detail Add-Sheet Presentation Regression Tests")
@MainActor
struct TripDetailAddSheetPresentationRegressionTests {
    @Test("Add Activity sheet state persists through auth refresh")
    func addActivitySheetPersistsThroughAuthRefresh() {
        let trip = Trip(name: "Regression Trip")
        let database = try! makeTripDetailTestDatabase()
        let initialState = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        }
        let store = Store(initialState: initialState) {
            TripDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        store.send(.addActivityTapped)
        #expect(store.state.activeSheet == .addActivity)

        store.send(
            .authStateLoaded(
                canUseBiometrics: true,
                biometricAuthEnabled: true,
                isTripProtected: false,
                isLocallyAuthenticated: true,
                isFaceID: false
            )
        )

        #expect(store.state.activeSheet == .addActivity)
    }

    @Test("Add Lodging sheet state persists through path sync")
    func addLodgingSheetPersistsThroughPathSync() {
        let trip = Trip(name: "Regression Trip")
        let database = try! makeTripDetailTestDatabase()
        let initialState = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            TripDetailFeature.State(
                trip: trip,
                initialPath: [],
                resetToken: 0
            )
        }
        let store = Store(initialState: initialState) {
            TripDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        let route = TripRoute.activity(UUID())

        store.send(.addLodgingTapped)
        #expect(store.state.activeSheet == .addLodging)

        store.send(.externalPathChanged([route]))

        #expect(store.state.activeSheet == .addLodging)
    }

    @Test("Add Transportation sheet state persists through reset token change")
    func addTransportationSheetPersistsThroughResetTokenChange() {
        let trip = Trip(name: "Regression Trip")
        let route = TripRoute.transportation(UUID())
        let database = try! makeTripDetailTestDatabase()
        let initialState = withDependencies {
            $0.defaultDatabase = database
        } operation: {
            TripDetailFeature.State(
                trip: trip,
                initialPath: [route],
                resetToken: 0
            )
        }
        let store = Store(initialState: initialState) {
            TripDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        store.send(.addTransportationTapped)
        #expect(store.state.activeSheet == .addTransportation)

        store.send(.resetTokenChanged(1))

        #expect(store.state.activeSheet == .addTransportation)
    }
}

private func makeTripDetailTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    return database
}
