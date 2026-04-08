//
//  MediaSearchFeatureTVShowTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("MediaSearchFeature TV Show Tests")
@MainActor
struct MediaSearchFeatureTVShowTests {

    private func makeResult(
        id: String = "test-789",
        title: String = "Test Show",
        firstAirDate: String = "2023-01-10"
    ) -> TVShowSearchResult {
        TVShowSearchResult(
            id: id,
            title: title,
            overview: "A test TV show overview",
            firstAirDate: firstAirDate,
            posterURL: "https://image.tmdb.org/t/p/w500/show.jpg",
            backdropURL: "",
            voteAverage: 8.2,
            genreNames: ["Sci-Fi & Fantasy", "Drama"],
            originalLanguage: "en"
        )
    }

    // MARK: - MediaSearchResultItem.tvShow

    @Test("TV show search result item has correct properties", .tags(.unit, .fast, .parallel))
    func tvShowResultItem() {
        let result = makeResult()
        let item = MediaSearchResultItem.tvShow(result)

        #expect(item.id == "tvshow-test-789")
        #expect(item.title == "Test Show")
        #expect(item.subtitle == "2023")
        #expect(item.thumbnailURL == "https://image.tmdb.org/t/p/w500/show.jpg")
        #expect(item.detail == "Sci-Fi & Fantasy, Drama")
    }

    // MARK: - Search dispatch

    @Test("Search dispatches to TMDB client for TV show type", .tags(.unit, .fast, .parallel))
    func searchDispatchesForTVShow() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let expectedResult = makeResult(id: "stranger-1", title: "Stranger Things")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .tvShow,
                searchText: "stranger"
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.tmdbClient.searchTVShows = { _ in [expectedResult] }
            $0.defaultDatabase = dbq
        }

        await store.send(.searchSubmitted) {
            $0.isSearching = true
            $0.hasSearched = true
        }

        await store.receive(.searchResults([.tvShow(expectedResult)])) {
            $0.isSearching = false
            $0.results = [.tvShow(expectedResult)]
        }
    }

    // MARK: - Save selected result

    @Test("Selecting a TV show result saves to database", .tags(.unit, .fast, .parallel))
    func saveSelectedTVShow() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .tvShow)
        try await dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let result = makeResult(id: "save-test", title: "Saved Show")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .tvShow
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.defaultDatabase = dbq
        }
        store.exhaustivity = .off

        await store.send(.resultSelected(.tvShow(result)))
        await store.receive(.itemSaved)

        let items = try await dbq.read { db in
            try TVShowItem.fetchAll(db)
        }
        #expect(items.count == 1)
        #expect(items.first?.title == "Saved Show")
        #expect(items.first?.externalID == "save-test")
        #expect(items.first?.genres == "Sci-Fi & Fantasy, Drama")
    }

    // MARK: - Search placeholder and sheet title

    @Test("TV show search has correct placeholder and title", .tags(.unit, .fast, .parallel))
    func searchPlaceholderAndTitle() {
        let state = MediaSearchFeature.State(
            collectionID: UUID(),
            collectionType: .tvShow
        )

        #expect(state.searchPlaceholder == "Search TV shows by title")
        #expect(state.sheetTitle == "Add TV Show")
    }
}
