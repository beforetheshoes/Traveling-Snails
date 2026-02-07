import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("TripSharingFeature Tests")
@MainActor
struct TripSharingFeatureTests {
    @Test("onAppear loads sharing snapshot")
    func onAppearLoadsSharingInfo() async {
        let expected = TripSharingSnapshot(
            isShared: true,
            shareURL: URL(string: "https://example.com/share")!,
            participants: []
        )

        let store = TestStore(
            initialState: TripSharingFeature.State(trip: Trip(name: "Paris"))
        ) {
            TripSharingFeature()
        } withDependencies: {
            $0.tripSharingClient.sharingInfo = { _ in expected }
        }

        await store.send(.onAppear) {
            $0.isLoadingSharingInfo = true
        }
        await store.receive(.sharingInfoResponse(expected)) {
            $0.isLoadingSharingInfo = false
            $0.sharingInfo = expected
        }
    }

    @Test("create share success updates snapshot and opens sheet")
    func createShareSuccess() async {
        let created = TripSharingSnapshot(
            isShared: true,
            shareURL: URL(string: "https://example.com/share")!,
            participants: []
        )

        let store = TestStore(
            initialState: TripSharingFeature.State(trip: Trip(name: "Rome"))
        ) {
            TripSharingFeature()
        } withDependencies: {
            $0.tripSharingClient.createShare = { _ in created }
        }
        store.exhaustivity = .off

        await store.send(.createShareTapped) {
            $0.isCreatingShare = true
            $0.errorMessage = nil
        }
        await store.receive(.createShareResponse(.success(created))) {
            $0.isCreatingShare = false
            $0.sharingInfo = created
            #expect($0.activeShareSheet != nil)
        }
    }

    @Test("remove share failure surfaces error")
    func removeShareFailure() async {
        let store = TestStore(
            initialState: TripSharingFeature.State(trip: Trip(name: "Berlin"))
        ) {
            TripSharingFeature()
        } withDependencies: {
            $0.tripSharingClient.removeShare = { _ in
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
            }
        }

        await store.send(.removeShareTapped) {
            $0.isRemovingShare = true
            $0.errorMessage = nil
        }
        await store.receive(.removeShareResponse(.failure(.init(message: "boom")))) {
            $0.isRemovingShare = false
            $0.errorMessage = "Failed to remove share: boom"
        }
    }
}
