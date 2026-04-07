//
//  TVShowItemDetailFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TVShowItemDetailFeature {
    @ObservableState
    struct State: Equatable {
        var tvShowItem: TVShowItem
        var isEditing = false
        var editedNotes: String = ""
        var showingDeleteConfirmation = false
        var isDeleted = false
    }

    enum Action: Equatable {
        case onAppear
        case refreshTVShowItem
        case tvShowItemLoaded(TVShowItem?)

        case ratingChanged(Int)
        case statusChanged(TVShowStatus)

        case editNotesTapped
        case editedNotesChanged(String)
        case saveNotesTapped
        case cancelEditNotes

        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleted

        case refreshFromAPI
        case apiRefreshCompleted(TVShowItem)
        case downloadCoverImage
        case coverImageDownloaded(Data)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.tmdbClient) private var tmdbClient
    @Dependency(\.userIdentityClient) private var userIdentityClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshTVShowItem)

            case .refreshTVShowItem:
                let id = state.tvShowItem.id
                return .run { send in
                    let item = try? await database.read { db in
                        try TVShowItem.find(id).fetchOne(db)
                    }
                    await send(.tvShowItemLoaded(item))
                }

            case .tvShowItemLoaded(let item):
                guard let item else { return .none }
                state.tvShowItem = item
                return .none

            case .ratingChanged(let rating):
                state.tvShowItem.rating = rating
                let updated = state.tvShowItem
                return .run { [userIdentityClient] _ in
                    let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                    try await database.write { db in
                        try TVShowItem.upsert { updated }.execute(db)
                        try TVShowItem.find(updated.id)
                            .update { $0.lastEditedByUserRecordName = #bind(recordName) }
                            .execute(db)
                    }
                }

            case .statusChanged(let status):
                state.tvShowItem.status = status
                let updated = state.tvShowItem
                return .run { [userIdentityClient] _ in
                    let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                    try await database.write { db in
                        try TVShowItem.upsert { updated }.execute(db)
                        try TVShowItem.find(updated.id)
                            .update { $0.lastEditedByUserRecordName = #bind(recordName) }
                            .execute(db)
                    }
                }

            case .editNotesTapped:
                state.isEditing = true
                state.editedNotes = state.tvShowItem.notes
                return .none

            case .editedNotesChanged(let notes):
                state.editedNotes = notes
                return .none

            case .saveNotesTapped:
                state.isEditing = false
                state.tvShowItem.notes = state.editedNotes
                let updated = state.tvShowItem
                return .run { [userIdentityClient] _ in
                    let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                    try await database.write { db in
                        try TVShowItem.upsert { updated }.execute(db)
                        try TVShowItem.find(updated.id)
                            .update { $0.lastEditedByUserRecordName = #bind(recordName) }
                            .execute(db)
                    }
                }

            case .cancelEditNotes:
                state.isEditing = false
                return .none

            case .deleteTapped:
                state.showingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.showingDeleteConfirmation = false
                let id = state.tvShowItem.id
                return .run { send in
                    try await database.write { db in
                        try TVShowItem.find(id).delete().execute(db)
                    }
                    await send(.deleted)
                }

            case .deleteCancelled:
                state.showingDeleteConfirmation = false
                return .none

            case .deleted:
                state.isDeleted = true
                return .none

            case .refreshFromAPI:
                let externalID = state.tvShowItem.externalID
                guard !externalID.isEmpty else { return .none }
                return .run { send in
                    let result = try await tmdbClient.fetchTVShowDetail(externalID)
                    let refreshed = result.toTVShowItem(collectionID: UUID())
                    await send(.apiRefreshCompleted(refreshed))
                }

            case .apiRefreshCompleted(let refreshed):
                state.tvShowItem.title = refreshed.title
                state.tvShowItem.overview = refreshed.overview
                state.tvShowItem.firstAirDate = refreshed.firstAirDate
                state.tvShowItem.genres = refreshed.genres
                state.tvShowItem.voteAverage = refreshed.voteAverage
                if !refreshed.posterURL.isEmpty {
                    state.tvShowItem.posterURL = refreshed.posterURL
                }
                if !refreshed.backdropURL.isEmpty {
                    state.tvShowItem.backdropURL = refreshed.backdropURL
                }
                let updated = state.tvShowItem
                return .merge(
                    .run { _ in
                        try await database.write { db in
                            try TVShowItem.upsert { updated }.execute(db)
                        }
                    },
                    .send(.downloadCoverImage)
                )

            case .downloadCoverImage:
                let url = state.tvShowItem.posterURL
                guard !url.isEmpty, state.tvShowItem.coverImageData == nil else { return .none }
                return .run { send in
                    if let data = await MediaCacheService.shared.downloadCoverImage(from: url) {
                        await send(.coverImageDownloaded(data))
                    }
                }

            case .coverImageDownloaded(let data):
                state.tvShowItem.coverImageData = data
                let id = state.tvShowItem.id
                return .run { _ in
                    try await database.write { db in
                        try TVShowItem.find(id)
                            .update { $0.coverImageData = #bind(data) }
                            .execute(db)
                    }
                }
            }
        }
    }
}
