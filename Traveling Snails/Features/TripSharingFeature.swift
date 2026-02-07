import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TripSharingFeature {
    struct Failure: Error, Equatable {
        let message: String
    }

    struct ShareSheetPayload: Equatable, Identifiable {
        let id = UUID()
        let activityItems: [String]
        let url: URL?
    }

    @ObservableState
    struct State: Equatable {
        let trip: Trip

        var sharingInfo: TripSharingSnapshot?
        var isLoadingSharingInfo = false
        var isCreatingShare = false
        var isRemovingShare = false
        var errorMessage: String?
        var activeShareSheet: ShareSheetPayload?
    }

    enum Action: Equatable {
        case onAppear
        case sharingInfoResponse(TripSharingSnapshot)
        case createShareTapped
        case createShareResponse(Result<TripSharingSnapshot, Failure>)
        case removeShareTapped
        case removeShareResponse(Result<TripSharingSnapshot, Failure>)
        case refreshTapped
        case shareURLTapped(URL)
        case shareTextTapped
        case shareSheetDismissed
        case clearErrorTapped
    }

    @Dependency(\.tripSharingClient) private var tripSharingClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoadingSharingInfo = true
                return .run { [trip = state.trip] send in
                    let info = await tripSharingClient.sharingInfo(trip)
                    await send(.sharingInfoResponse(info))
                }

            case .sharingInfoResponse(let info):
                state.sharingInfo = info
                state.isLoadingSharingInfo = false
                return .none

            case .createShareTapped:
                guard !state.isCreatingShare else { return .none }
                state.isCreatingShare = true
                state.errorMessage = nil
                return .run { [trip = state.trip] send in
                    do {
                        let info = try await tripSharingClient.createShare(trip)
                        await send(.createShareResponse(.success(info)))
                    } catch {
                        await send(.createShareResponse(.failure(Failure(message: error.localizedDescription))))
                    }
                }

            case .createShareResponse(.success(let info)):
                state.isCreatingShare = false
                state.sharingInfo = info
                if let shareURL = info.shareURL {
                    state.activeShareSheet = ShareSheetPayload(
                        activityItems: [shareURL.absoluteString],
                        url: shareURL
                    )
                }
                return .none

            case .createShareResponse(.failure(let failure)):
                state.isCreatingShare = false
                state.errorMessage = "Failed to create share: \(failure.message)"
                return .none

            case .removeShareTapped:
                guard !state.isRemovingShare else { return .none }
                state.isRemovingShare = true
                state.errorMessage = nil
                return .run { [trip = state.trip] send in
                    do {
                        try await tripSharingClient.removeShare(trip)
                        await send(
                            .removeShareResponse(
                                .success(TripSharingSnapshot(isShared: false, shareURL: nil, participants: []))
                            )
                        )
                    } catch {
                        await send(.removeShareResponse(.failure(Failure(message: error.localizedDescription))))
                    }
                }

            case .removeShareResponse(.success(let info)):
                state.isRemovingShare = false
                state.sharingInfo = info
                return .none

            case .removeShareResponse(.failure(let failure)):
                state.isRemovingShare = false
                state.errorMessage = "Failed to remove share: \(failure.message)"
                return .none

            case .refreshTapped:
                state.isLoadingSharingInfo = true
                return .run { [trip = state.trip] send in
                    let info = await tripSharingClient.sharingInfo(trip)
                    await send(.sharingInfoResponse(info))
                }

            case .shareURLTapped(let shareURL):
                state.activeShareSheet = ShareSheetPayload(
                    activityItems: [shareURL.absoluteString],
                    url: shareURL
                )
                return .none

            case .shareTextTapped:
                let shareText = "Check out my trip: \(state.trip.name)"
                state.activeShareSheet = ShareSheetPayload(
                    activityItems: [shareText],
                    url: nil
                )
                return .none

            case .shareSheetDismissed:
                state.activeShareSheet = nil
                return .none

            case .clearErrorTapped:
                state.errorMessage = nil
                return .none
            }
        }
    }
}
