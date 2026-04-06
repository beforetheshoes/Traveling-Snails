//
//  MediaSearchFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct MediaSearchFeature {
    @ObservableState
    struct State: Equatable {
        var collectionID: Collection.ID
        var searchText: String = ""
        var results: [BookSearchResult] = []
        var isSearching = false
        var errorMessage: String?
        var hasSearched = false
    }

    enum Action: Equatable {
        case searchTextChanged(String)
        case searchSubmitted
        case searchResults([BookSearchResult])
        case searchFailed(String)
        case resultSelected(BookSearchResult)
        case itemSaved
        case dismissed
    }

    @Dependency(\.googleBooksClient) private var googleBooksClient
    @Dependency(\.defaultDatabase) private var database

    private enum CancelID { case search }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .searchTextChanged(let text):
                state.searchText = text
                return .none

            case .searchSubmitted:
                let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return .none }

                state.isSearching = true
                state.errorMessage = nil
                state.hasSearched = true

                return .run { send in
                    do {
                        if let cached = await MediaCacheService.shared.cachedSearchResults(for: query) {
                            Logger.shared.info("Book search: returning \(cached.count) cached results for '\(query)'", category: .network)
                            await send(.searchResults(cached))
                            return
                        }
                        Logger.shared.info("Book search: querying API for '\(query)'", category: .network)
                        let results = try await googleBooksClient.search(query)
                        Logger.shared.info("Book search: got \(results.count) results for '\(query)'", category: .network)
                        await MediaCacheService.shared.cacheSearchResults(results, for: query)
                        await send(.searchResults(results))
                    } catch {
                        Logger.shared.error("Book search failed for '\(query)': \(error)", category: .network)
                        await send(.searchFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .searchResults(let results):
                state.isSearching = false
                state.results = results
                return .none

            case .searchFailed(let message):
                state.isSearching = false
                state.errorMessage = message
                return .none

            case .resultSelected(let result):
                let collectionID = state.collectionID
                let bookItem = result.toBookItem(collectionID: collectionID)
                return .run { send in
                    try await database.write { db in
                        try BookItem.upsert { bookItem }.execute(db)
                    }
                    // Download and cache cover image
                    if !bookItem.coverImageURL.isEmpty {
                        if let imageData = await MediaCacheService.shared.downloadCoverImage(from: bookItem.coverImageURL) {
                            var withImage = bookItem
                            withImage.coverImageData = imageData
                            let toSave = withImage
                            try await database.write { db in
                                try BookItem.upsert { toSave }.execute(db)
                            }
                        }
                    }
                    await send(.itemSaved)
                }

            case .itemSaved:
                return .none

            case .dismissed:
                return .none
            }
        }
    }
}
