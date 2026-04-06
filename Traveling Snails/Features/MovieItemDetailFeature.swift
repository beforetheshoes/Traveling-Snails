//
//  MovieItemDetailFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct MovieItemDetailFeature {
    @ObservableState
    struct State: Equatable {
        var movieItem: MovieItem
        var isEditing = false
        var editedNotes: String = ""
        var showingDeleteConfirmation = false
        var isDeleted = false
    }

    enum Action: Equatable {
        case onAppear
        case refreshMovieItem
        case movieItemLoaded(MovieItem?)

        case ratingChanged(Int)
        case statusChanged(MovieStatus)

        case editNotesTapped
        case editedNotesChanged(String)
        case saveNotesTapped
        case cancelEditNotes

        case watchedDateChanged(Date?)

        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleted

        case refreshFromAPI
        case apiRefreshCompleted(MovieItem)
        case downloadCoverImage
        case coverImageDownloaded(Data)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.tmdbClient) private var tmdbClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshMovieItem)

            case .refreshMovieItem:
                let id = state.movieItem.id
                return .run { send in
                    let item = try? await database.read { db in
                        try MovieItem.find(id).fetchOne(db)
                    }
                    await send(.movieItemLoaded(item))
                }

            case .movieItemLoaded(let item):
                guard let item else { return .none }
                state.movieItem = item
                return .none

            case .ratingChanged(let rating):
                state.movieItem.rating = rating
                let updated = state.movieItem
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.upsert { updated }.execute(db)
                    }
                }

            case .statusChanged(let status):
                state.movieItem.status = status
                if status == .watched && !state.movieItem.hasWatchedDate {
                    state.movieItem.setWatchedDate(Date())
                }
                let updated = state.movieItem
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.upsert { updated }.execute(db)
                    }
                }

            case .editNotesTapped:
                state.isEditing = true
                state.editedNotes = state.movieItem.notes
                return .none

            case .editedNotesChanged(let notes):
                state.editedNotes = notes
                return .none

            case .saveNotesTapped:
                state.isEditing = false
                state.movieItem.notes = state.editedNotes
                let updated = state.movieItem
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.upsert { updated }.execute(db)
                    }
                }

            case .cancelEditNotes:
                state.isEditing = false
                return .none

            case .watchedDateChanged(let date):
                if let date {
                    state.movieItem.setWatchedDate(date)
                } else {
                    state.movieItem.clearWatchedDate()
                }
                let updated = state.movieItem
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.upsert { updated }.execute(db)
                    }
                }

            case .deleteTapped:
                state.showingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.showingDeleteConfirmation = false
                let id = state.movieItem.id
                return .run { send in
                    try await database.write { db in
                        try MovieItem.find(id).delete().execute(db)
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
                let externalID = state.movieItem.externalID
                guard !externalID.isEmpty else { return .none }
                return .run { send in
                    let result = try await tmdbClient.fetchMovieDetail(externalID)
                    let refreshed = result.toMovieItem(collectionID: UUID())
                    await send(.apiRefreshCompleted(refreshed))
                }

            case .apiRefreshCompleted(let refreshed):
                state.movieItem.title = refreshed.title
                state.movieItem.overview = refreshed.overview
                state.movieItem.releaseDate = refreshed.releaseDate
                state.movieItem.genres = refreshed.genres
                state.movieItem.voteAverage = refreshed.voteAverage
                if !refreshed.posterURL.isEmpty {
                    state.movieItem.posterURL = refreshed.posterURL
                }
                if !refreshed.backdropURL.isEmpty {
                    state.movieItem.backdropURL = refreshed.backdropURL
                }
                let updated = state.movieItem
                return .merge(
                    .run { _ in
                        try await database.write { db in
                            try MovieItem.upsert { updated }.execute(db)
                        }
                    },
                    .send(.downloadCoverImage)
                )

            case .downloadCoverImage:
                let url = state.movieItem.posterURL
                guard !url.isEmpty, state.movieItem.coverImageData == nil else { return .none }
                return .run { send in
                    if let data = await MediaCacheService.shared.downloadCoverImage(from: url) {
                        await send(.coverImageDownloaded(data))
                    }
                }

            case .coverImageDownloaded(let data):
                state.movieItem.coverImageData = data
                let id = state.movieItem.id
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.find(id)
                            .update { $0.coverImageData = #bind(data) }
                            .execute(db)
                    }
                }
            }
        }
    }
}
