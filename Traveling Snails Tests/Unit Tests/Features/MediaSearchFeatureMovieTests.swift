//
//  MediaSearchFeatureMovieTests.swift
//  Traveling Snails Tests
//

import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("MediaSearchFeature Movie Tests")
@MainActor
struct MediaSearchFeatureMovieTests {

    private func makeResult(
        id: String = "test-456",
        title: String = "Test Movie",
        releaseDate: String = "2024-06-15"
    ) -> MovieSearchResult {
        MovieSearchResult(
            id: id,
            title: title,
            overview: "A test movie overview",
            releaseDate: releaseDate,
            posterURL: "https://image.tmdb.org/t/p/w500/test.jpg",
            backdropURL: "",
            voteAverage: 7.5,
            genreNames: ["Action", "Drama"],
            originalLanguage: "en"
        )
    }

    // MARK: - MediaSearchResultItem.movie

    @Test("Movie search result item has correct properties", .tags(.unit, .fast, .parallel))
    func movieResultItem() {
        let result = makeResult()
        let item = MediaSearchResultItem.movie(result)

        #expect(item.id == "movie-test-456")
        #expect(item.title == "Test Movie")
        #expect(item.subtitle == "2024")
        #expect(item.thumbnailURL == "https://image.tmdb.org/t/p/w500/test.jpg")
        #expect(item.detail == "Action, Drama")
    }

    // MARK: - Search dispatch

    @Test("Search dispatches to TMDB client for movie type", .tags(.unit, .fast, .parallel))
    func searchDispatchesForMovie() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let expectedResult = makeResult(id: "matrix-1", title: "The Matrix")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .movie,
                searchText: "matrix"
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.tmdbClient.searchMovies = { _ in [expectedResult] }
            $0.defaultDatabase = dbq
        }

        await store.send(.searchSubmitted) {
            $0.isSearching = true
            $0.hasSearched = true
        }

        await store.receive(.searchResults([.movie(expectedResult)])) {
            $0.isSearching = false
            $0.results = [.movie(expectedResult)]
        }
    }

    // MARK: - Save selected result

    @Test("Selecting a movie result saves to database", .tags(.unit, .fast, .parallel))
    func saveSelectedMovie() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .movie)
        try await dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let result = makeResult(id: "save-test", title: "Saved Movie")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .movie
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.defaultDatabase = dbq
        }
        store.exhaustivity = .off

        await store.send(.resultSelected(.movie(result)))
        await store.receive(.itemSaved)

        let items = try await dbq.read { db in
            try MovieItem.fetchAll(db)
        }
        #expect(items.count == 1)
        #expect(items.first?.title == "Saved Movie")
        #expect(items.first?.externalID == "save-test")
        #expect(items.first?.genres == "Action, Drama")
    }

    // MARK: - Dismiss after save

    @Test("itemSaved sets shouldDismiss to true", .tags(.unit, .fast, .parallel))
    func itemSavedSetsShouldDismiss() async throws {
        let dbq = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(dbq)

        let collectionID = UUID()
        let collection = Collection(id: collectionID, type: .movie)
        try await dbq.write { db in
            try Collection.insert { collection }.execute(db)
        }

        let result = makeResult(id: "dismiss-test", title: "Dismiss Movie")

        let store = TestStore(
            initialState: MediaSearchFeature.State(
                collectionID: collectionID,
                collectionType: .movie
            )
        ) {
            MediaSearchFeature()
        } withDependencies: {
            $0.defaultDatabase = dbq
        }
        store.exhaustivity = .off

        await store.send(.resultSelected(.movie(result)))
        await store.receive(\.itemSaved) {
            $0.shouldDismiss = true
        }
    }

    // MARK: - Search placeholder and sheet title

    @Test("Movie search has correct placeholder and title", .tags(.unit, .fast, .parallel))
    func searchPlaceholderAndTitle() {
        let state = MediaSearchFeature.State(
            collectionID: UUID(),
            collectionType: .movie
        )

        #expect(state.searchPlaceholder == "Search movies by title")
        #expect(state.sheetTitle == "Add Movie")
    }
}
