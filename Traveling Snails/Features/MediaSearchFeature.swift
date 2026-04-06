//
//  MediaSearchFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

// MARK: - Unified Search Result

enum MediaSearchResultItem: Equatable, Identifiable {
    case book(BookSearchResult)
    case movie(MovieSearchResult)
    case tvShow(TVShowSearchResult)

    var id: String {
        switch self {
        case .book(let r): return "book-\(r.id)"
        case .movie(let r): return "movie-\(r.id)"
        case .tvShow(let r): return "tvshow-\(r.id)"
        }
    }

    var title: String {
        switch self {
        case .book(let r): return r.title
        case .movie(let r): return r.title
        case .tvShow(let r): return r.title
        }
    }

    var subtitle: String {
        switch self {
        case .book(let r): return r.authorDisplay
        case .movie(let r): return r.releaseDate.isEmpty ? "" : String(r.releaseDate.prefix(4))
        case .tvShow(let r): return r.firstAirDate.isEmpty ? "" : String(r.firstAirDate.prefix(4))
        }
    }

    var thumbnailURL: String {
        switch self {
        case .book(let r): return r.thumbnailURL
        case .movie(let r): return r.posterURL
        case .tvShow(let r): return r.posterURL
        }
    }

    var detail: String {
        switch self {
        case .book(let r):
            return r.pageCount > 0 ? "\(r.pageCount) pages" : ""
        case .movie(let r):
            return r.genreNames.prefix(2).joined(separator: ", ")
        case .tvShow(let r):
            return r.genreNames.prefix(2).joined(separator: ", ")
        }
    }
}

// MARK: - Feature

@Reducer
struct MediaSearchFeature {
    @ObservableState
    struct State: Equatable {
        var collectionID: Collection.ID
        var collectionType: CollectionType
        var searchText: String = ""
        var results: [MediaSearchResultItem] = []
        var isSearching = false
        var errorMessage: String?
        var hasSearched = false

        var searchPlaceholder: String {
            switch collectionType {
            case .book: return "Search by title, author, or ISBN"
            case .movie: return "Search movies by title"
            case .tvShow: return "Search TV shows by title"
            default: return "Search"
            }
        }

        var sheetTitle: String {
            switch collectionType {
            case .book: return "Add Book"
            case .movie: return "Add Movie"
            case .tvShow: return "Add TV Show"
            default: return "Add Item"
            }
        }
    }

    enum Action: Equatable {
        case searchTextChanged(String)
        case searchSubmitted
        case searchResults([MediaSearchResultItem])
        case searchFailed(String)
        case resultSelected(MediaSearchResultItem)
        case itemSaved
        case dismissed
    }

    @Dependency(\.googleBooksClient) private var googleBooksClient
    @Dependency(\.tmdbClient) private var tmdbClient
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

                let collectionType = state.collectionType
                return .run { send in
                    do {
                        Logger.shared.info("Media search: querying for '\(query)' (type: \(collectionType.rawValue))", category: .network)
                        let results: [MediaSearchResultItem]
                        switch collectionType {
                        case .book:
                            if let cached = await MediaCacheService.shared.cachedSearchResults(for: query) {
                                Logger.shared.info("Book search: returning \(cached.count) cached results for '\(query)'", category: .network)
                                await send(.searchResults(cached.map { .book($0) }))
                                return
                            }
                            let bookResults = try await googleBooksClient.search(query)
                            await MediaCacheService.shared.cacheSearchResults(bookResults, for: query)
                            results = bookResults.map { .book($0) }
                        case .movie:
                            let movieResults = try await tmdbClient.searchMovies(query)
                            results = movieResults.map { .movie($0) }
                        case .tvShow:
                            let tvResults = try await tmdbClient.searchTVShows(query)
                            results = tvResults.map { .tvShow($0) }
                        default:
                            results = []
                        }
                        Logger.shared.info("Media search: got \(results.count) results for '\(query)'", category: .network)
                        await send(.searchResults(results))
                    } catch {
                        Logger.shared.error("Media search failed for '\(query)': \(error)", category: .network)
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
                switch result {
                case .book(let bookResult):
                    let bookItem = bookResult.toBookItem(collectionID: collectionID)
                    return .run { send in
                        try await database.write { db in
                            try BookItem.upsert { bookItem }.execute(db)
                        }
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

                case .movie(let movieResult):
                    let movieItem = movieResult.toMovieItem(collectionID: collectionID)
                    return .run { send in
                        try await database.write { db in
                            try MovieItem.upsert { movieItem }.execute(db)
                        }
                        if !movieItem.posterURL.isEmpty {
                            if let imageData = await MediaCacheService.shared.downloadCoverImage(from: movieItem.posterURL) {
                                var withImage = movieItem
                                withImage.coverImageData = imageData
                                let toSave = withImage
                                try await database.write { db in
                                    try MovieItem.upsert { toSave }.execute(db)
                                }
                            }
                        }
                        await send(.itemSaved)
                    }

                case .tvShow(let tvResult):
                    let tvItem = tvResult.toTVShowItem(collectionID: collectionID)
                    return .run { send in
                        try await database.write { db in
                            try TVShowItem.upsert { tvItem }.execute(db)
                        }
                        if !tvItem.posterURL.isEmpty {
                            if let imageData = await MediaCacheService.shared.downloadCoverImage(from: tvItem.posterURL) {
                                var withImage = tvItem
                                withImage.coverImageData = imageData
                                let toSave = withImage
                                try await database.write { db in
                                    try TVShowItem.upsert { toSave }.execute(db)
                                }
                            }
                        }
                        await send(.itemSaved)
                    }
                }

            case .itemSaved:
                return .none

            case .dismissed:
                return .none
            }
        }
    }
}
