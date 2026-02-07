import ComposableArchitecture
import Foundation
import Testing

@testable import Traveling_Snails

@Suite("ShareInvitationFeature Tests")
@MainActor
struct ShareInvitationFeatureTests {
    @Test("accept success sets didAccept")
    func acceptSuccessSetsDidAccept() async {
        let acceptedTrip = Trip(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            name: "Accepted",
            createdDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let store = TestStore(
            initialState: ShareInvitationFeature.State(
                shareTitle: "Shared Trip",
                ownerName: "Owner",
                acceptShareOverride: { acceptedTrip }
            )
        ) {
            ShareInvitationFeature()
        }

        await store.send(.acceptTapped) {
            $0.isAcceptingShare = true
            $0.errorMessage = nil
        }
        await store.receive(.acceptResponse(.success(acceptedTrip))) {
            $0.isAcceptingShare = false
            $0.didAccept = true
        }
    }

    @Test("accept failure sets error")
    func acceptFailureSetsError() async {
        let store = TestStore(
            initialState: ShareInvitationFeature.State(
                shareTitle: "Shared Trip",
                ownerName: "Owner",
                acceptShareOverride: {
                    throw NSError(
                        domain: "Test",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "failed"]
                    )
                }
            )
        ) {
            ShareInvitationFeature()
        }

        await store.send(.acceptTapped) {
            $0.isAcceptingShare = true
            $0.errorMessage = nil
        }
        await store.receive(.acceptResponse(.failure(.init(message: "failed")))) {
            $0.isAcceptingShare = false
            $0.errorMessage = "Failed to accept invitation: failed"
        }
    }
}
