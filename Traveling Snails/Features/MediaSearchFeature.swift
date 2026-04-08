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
    case restaurant(RestaurantSearchResult)

    var id: String {
        switch self {
        case .book(let r): return "book-\(r.id)"
        case .movie(let r): return "movie-\(r.id)"
        case .tvShow(let r): return "tvshow-\(r.id)"
        case .restaurant(let r): return "restaurant-\(r.id)"
        }
    }

    var title: String {
        switch self {
        case .book(let r): return r.title
        case .movie(let r): return r.title
        case .tvShow(let r): return r.title
        case .restaurant(let r): return r.name
        }
    }

    var subtitle: String {
        switch self {
        case .book(let r): return r.authorDisplay
        case .movie(let r): return r.releaseDate.isEmpty ? "" : String(r.releaseDate.prefix(4))
        case .tvShow(let r): return r.firstAirDate.isEmpty ? "" : String(r.firstAirDate.prefix(4))
        case .restaurant(let r): return r.address
        }
    }

    var thumbnailURL: String {
        switch self {
        case .book(let r): return r.thumbnailURL
        case .movie(let r): return r.posterURL
        case .tvShow(let r): return r.posterURL
        case .restaurant: return ""
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
        case .restaurant(let r):
            return r.category
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
            case .restaurant: return "Search restaurants by name or cuisine"
            default: return "Search"
            }
        }

        var sheetTitle: String {
            switch collectionType {
            case .book: return "Add Book"
            case .movie: return "Add Movie"
            case .tvShow: return "Add TV Show"
            case .restaurant: return "Add Restaurant"
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
        case generateSnapshot(RestaurantItem)
        case dismissed
    }

    @Dependency(\.googleBooksClient) private var googleBooksClient
    @Dependency(\.tmdbClient) private var tmdbClient
    @Dependency(\.mapKitSearchClient) private var mapKitSearchClient
    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.userIdentityClient) private var userIdentityClient

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
                        case .restaurant:
                            let restaurantResults = try await mapKitSearchClient.search(query)
                            results = restaurantResults.map { .restaurant($0) }
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
                    return .run { [userIdentityClient] send in
                        let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                        try await database.write { db in
                            try BookItem.upsert { bookItem }.execute(db)
                            try BookItem.find(bookItem.id)
                                .update { $0.addedByUserRecordName = #bind(recordName) }
                                .execute(db)
                        }
                        await RecentItemGuard.shared.guardBook(bookItem)
                        if !bookItem.coverImageURL.isEmpty {
                            if let imageData = await MediaCacheService.shared.downloadCoverImage(from: bookItem.coverImageURL) {
                                try await database.write { db in
                                    try BookItem.find(bookItem.id)
                                        .update { $0.coverImageData = #bind(imageData) }
                                        .execute(db)
                                }
                            }
                        }
                        await send(.itemSaved)
                    }

                case .movie(let movieResult):
                    let movieItem = movieResult.toMovieItem(collectionID: collectionID)
                    return .run { [userIdentityClient] send in
                        let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                        try await database.write { db in
                            try MovieItem.upsert { movieItem }.execute(db)
                            try MovieItem.find(movieItem.id)
                                .update { $0.addedByUserRecordName = #bind(recordName) }
                                .execute(db)
                        }
                        await RecentItemGuard.shared.guardMovie(movieItem)
                        if !movieItem.posterURL.isEmpty {
                            if let imageData = await MediaCacheService.shared.downloadCoverImage(from: movieItem.posterURL) {
                                try await database.write { db in
                                    try MovieItem.find(movieItem.id)
                                        .update { $0.coverImageData = #bind(imageData) }
                                        .execute(db)
                                }
                            }
                        }
                        await send(.itemSaved)
                    }

                case .tvShow(let tvResult):
                    let tvItem = tvResult.toTVShowItem(collectionID: collectionID)
                    return .run { [userIdentityClient] send in
                        let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                        try await database.write { db in
                            try TVShowItem.upsert { tvItem }.execute(db)
                            try TVShowItem.find(tvItem.id)
                                .update { $0.addedByUserRecordName = #bind(recordName) }
                                .execute(db)
                        }
                        await RecentItemGuard.shared.guardTVShow(tvItem)
                        if !tvItem.posterURL.isEmpty {
                            if let imageData = await MediaCacheService.shared.downloadCoverImage(from: tvItem.posterURL) {
                                try await database.write { db in
                                    try TVShowItem.find(tvItem.id)
                                        .update { $0.coverImageData = #bind(imageData) }
                                        .execute(db)
                                }
                            }
                        }
                        await send(.itemSaved)
                    }

                case .restaurant(let restaurantResult):
                    let restaurantItem = restaurantResult.toRestaurantItem(collectionID: collectionID)
                    return .run { [userIdentityClient] send in
                        let recordName = (try? await userIdentityClient.currentUserRecordName()) ?? ""
                        try await database.write { db in
                            try RestaurantItem.upsert { restaurantItem }.execute(db)
                            try RestaurantItem.find(restaurantItem.id)
                                .update { $0.addedByUserRecordName = #bind(recordName) }
                                .execute(db)
                        }
                        await RecentItemGuard.shared.guardRestaurant(restaurantItem)
                        await send(.itemSaved)
                        if restaurantItem.hasCoordinate || !restaurantItem.websiteURL.isEmpty {
                            await send(.generateSnapshot(restaurantItem))
                        }
                    }
                }

            case .itemSaved:
                return .none

            case .generateSnapshot(let restaurantItem):
                return .run { [mapKitSearchClient] _ in
                    var imageData: Data?

                    var imageType = ""

                    // Try to fetch a brand image with a 10-second overall time limit
                    if !restaurantItem.websiteURL.isEmpty {
                        Logger.shared.info("Restaurant cover: trying brand image from \(restaurantItem.websiteURL)", category: .network)
                        imageData = await withTimeLimit(seconds: 10) {
                            await mapKitSearchClient.fetchBrandImage(restaurantItem.websiteURL)
                        }
                        if imageData != nil {
                            imageType = "brand"
                            Logger.shared.info("Restaurant cover: got brand image for '\(restaurantItem.title)' (\(imageData!.count) bytes)", category: .network)
                        } else {
                            Logger.shared.info("Restaurant cover: no brand image for '\(restaurantItem.title)', falling back to map", category: .network)
                        }
                    }

                    // Fall back to a map snapshot if no brand image was found
                    if imageData == nil && restaurantItem.hasCoordinate {
                        imageData = await mapKitSearchClient.generateSnapshot(
                            restaurantItem.latitude,
                            restaurantItem.longitude,
                            restaurantItem.title
                        )
                        if imageData != nil {
                            imageType = "map"
                            Logger.shared.info("Restaurant cover: got map snapshot for '\(restaurantItem.title)' (\(imageData!.count) bytes)", category: .network)
                        } else {
                            Logger.shared.error("Restaurant cover: map snapshot ALSO failed for '\(restaurantItem.title)'", category: .network)
                        }
                    }

                    if let imageData {
                        let itemID = restaurantItem.id
                        let type = imageType
                        try? await database.write { db in
                            try RestaurantItem.find(itemID)
                                .update {
                                    $0.coverImageData = #bind(imageData)
                                    $0.coverImageType = #bind(type)
                                }
                                .execute(db)
                        }
                    }
                }

            case .dismissed:
                return .none
            }
        }
    }
}

// MARK: - Time-limited async helper

private func withTimeLimit<T: Sendable>(seconds: Int, operation: @escaping @Sendable () async -> T?) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return nil
        }

        // Return whichever finishes first
        for await result in group {
            if let result {
                group.cancelAll()
                return result
            }
        }
        group.cancelAll()
        return nil
    }
}
