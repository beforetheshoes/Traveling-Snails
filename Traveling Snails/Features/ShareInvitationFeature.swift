import ComposableArchitecture
import Foundation
@preconcurrency import CloudKit

@Reducer
struct ShareInvitationFeature {
    struct Failure: Error, Equatable {
        let message: String
    }

    @ObservableState
    struct State {
        let shareMetadata: CKShare.Metadata?
        let shareTitle: String?
        let ownerName: String?
        let acceptShareOverride: (@Sendable () async throws -> Trip)?
        var isAcceptingShare = false
        var didAccept = false
        var errorMessage: String?

        init(shareMetadata: CKShare.Metadata) {
            self.shareMetadata = shareMetadata
            self.shareTitle = shareMetadata.share[CKShare.SystemFieldKey.title] as? String
            self.ownerName = shareMetadata.ownerIdentity.nameComponents?.formatted()
            self.acceptShareOverride = nil
        }

        init(
            shareTitle: String?,
            ownerName: String?,
            acceptShareOverride: (@Sendable () async throws -> Trip)? = nil
        ) {
            self.shareMetadata = nil
            self.shareTitle = shareTitle
            self.ownerName = ownerName
            self.acceptShareOverride = acceptShareOverride
        }
    }

    enum Action: Equatable {
        case acceptTapped
        case acceptResponse(Result<Trip, Failure>)
        case clearErrorTapped
    }

    @Dependency(\.tripSharingClient) private var tripSharingClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .acceptTapped:
                guard !state.isAcceptingShare else { return .none }
                state.isAcceptingShare = true
                state.errorMessage = nil
                return .run { [metadata = state.shareMetadata, acceptShareOverride = state.acceptShareOverride] send in
                    do {
                        let trip: Trip
                        if let acceptShareOverride {
                            trip = try await acceptShareOverride()
                        } else if let metadata {
                            trip = try await tripSharingClient.acceptShare(metadata)
                        } else {
                            throw Failure(message: "Missing share invitation metadata")
                        }
                        await send(.acceptResponse(.success(trip)))
                    } catch {
                        if let failure = error as? Failure {
                            await send(.acceptResponse(.failure(failure)))
                        } else {
                            await send(.acceptResponse(.failure(Failure(message: error.localizedDescription))))
                        }
                    }
                }

            case .acceptResponse(.success):
                state.isAcceptingShare = false
                state.didAccept = true
                return .none

            case .acceptResponse(.failure(let failure)):
                state.isAcceptingShare = false
                state.errorMessage = "Failed to accept invitation: \(failure.message)"
                return .none

            case .clearErrorTapped:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

extension ShareInvitationFeature.State: Equatable {
    static func == (lhs: ShareInvitationFeature.State, rhs: ShareInvitationFeature.State) -> Bool {
        lhs.shareTitle == rhs.shareTitle
            && lhs.ownerName == rhs.ownerName
            && lhs.isAcceptingShare == rhs.isAcceptingShare
            && lhs.didAccept == rhs.didAccept
            && lhs.errorMessage == rhs.errorMessage
    }
}
