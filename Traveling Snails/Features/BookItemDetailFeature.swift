//
//  BookItemDetailFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct BookItemDetailFeature {
    @ObservableState
    struct State: Equatable {
        var bookItem: BookItem
        var isEditing = false
        var editedNotes: String = ""
        var showingDeleteConfirmation = false
    }

    enum Action: Equatable {
        case onAppear
        case refreshBookItem
        case bookItemLoaded(BookItem?)

        case ratingChanged(Int)
        case statusChanged(BookStatus)

        case editNotesTapped
        case editedNotesChanged(String)
        case saveNotesTapped
        case cancelEditNotes

        case startedDateChanged(Date?)
        case finishedDateChanged(Date?)

        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleted

        case refreshFromAPI
        case apiRefreshCompleted(BookSearchResult)
        case downloadCoverImage
        case coverImageDownloaded(Data)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.googleBooksClient) private var googleBooksClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshBookItem)

            case .refreshBookItem:
                let id = state.bookItem.id
                return .run { send in
                    let item = try? await database.read { db in
                        try BookItem.find(id).fetchOne(db)
                    }
                    await send(.bookItemLoaded(item))
                }

            case .bookItemLoaded(let item):
                guard let item else { return .none }
                state.bookItem = item
                return .none

            case .ratingChanged(let rating):
                state.bookItem.rating = rating
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }

            case .statusChanged(let status):
                state.bookItem.status = status
                if status == .reading && !state.bookItem.hasStartedDate {
                    state.bookItem.setStartedDate(Date())
                } else if status == .read && !state.bookItem.hasFinishedDate {
                    state.bookItem.setFinishedDate(Date())
                }
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }

            case .editNotesTapped:
                state.isEditing = true
                state.editedNotes = state.bookItem.notes
                return .none

            case .editedNotesChanged(let notes):
                state.editedNotes = notes
                return .none

            case .saveNotesTapped:
                state.isEditing = false
                state.bookItem.notes = state.editedNotes
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }

            case .cancelEditNotes:
                state.isEditing = false
                return .none

            case .startedDateChanged(let date):
                if let date {
                    state.bookItem.setStartedDate(date)
                } else {
                    state.bookItem.clearStartedDate()
                }
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }

            case .finishedDateChanged(let date):
                if let date {
                    state.bookItem.setFinishedDate(date)
                } else {
                    state.bookItem.clearFinishedDate()
                }
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }

            case .deleteTapped:
                state.showingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.showingDeleteConfirmation = false
                let id = state.bookItem.id
                return .run { send in
                    try await database.write { db in
                        try BookItem.find(id).delete().execute(db)
                    }
                    await send(.deleted)
                }

            case .deleteCancelled:
                state.showingDeleteConfirmation = false
                return .none

            case .deleted:
                return .none

            case .refreshFromAPI:
                let externalID = state.bookItem.externalID
                guard !externalID.isEmpty else { return .none }
                return .run { send in
                    let result = try await googleBooksClient.fetchDetail(externalID)
                    await send(.apiRefreshCompleted(result))
                }

            case .apiRefreshCompleted(let result):
                state.bookItem.title = result.title
                state.bookItem.author = result.authorDisplay
                state.bookItem.isbn = result.isbn
                state.bookItem.publisher = result.publisher
                state.bookItem.publishedDate = result.publishedDate
                state.bookItem.pageCount = result.pageCount
                state.bookItem.description = result.description
                if !result.thumbnailURL.isEmpty {
                    state.bookItem.coverImageURL = result.thumbnailURL.replacingOccurrences(of: "http://", with: "https://")
                }
                let updated = state.bookItem
                return .merge(
                    .run { _ in
                        try await database.write { db in
                            try BookItem.upsert { updated }.execute(db)
                        }
                    },
                    .send(.downloadCoverImage)
                )

            case .downloadCoverImage:
                let url = state.bookItem.coverImageURL
                guard !url.isEmpty, state.bookItem.coverImageData == nil else { return .none }
                return .run { send in
                    if let data = await MediaCacheService.shared.downloadCoverImage(from: url) {
                        await send(.coverImageDownloaded(data))
                    }
                }

            case .coverImageDownloaded(let data):
                state.bookItem.coverImageData = data
                let updated = state.bookItem
                return .run { _ in
                    try await database.write { db in
                        try BookItem.upsert { updated }.execute(db)
                    }
                }
            }
        }
    }
}
