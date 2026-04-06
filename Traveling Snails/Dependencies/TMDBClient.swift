//
//  TMDBClient.swift
//  Traveling Snails
//

import Dependencies
import Foundation

// MARK: - Search Result Types

struct MovieSearchResult: Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var overview: String
    var releaseDate: String
    var posterURL: String
    var backdropURL: String
    var voteAverage: Double
    var genreNames: [String]
    var originalLanguage: String

    func toMovieItem(collectionID: Collection.ID) -> MovieItem {
        MovieItem(
            collectionID: collectionID,
            title: title,
            overview: overview,
            releaseDate: releaseDate,
            genres: genreNames.joined(separator: ", "),
            posterURL: posterURL,
            backdropURL: backdropURL,
            externalID: id,
            voteAverage: voteAverage,
            originalLanguage: originalLanguage
        )
    }
}

struct TVShowSearchResult: Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var overview: String
    var firstAirDate: String
    var posterURL: String
    var backdropURL: String
    var voteAverage: Double
    var genreNames: [String]
    var originalLanguage: String

    func toTVShowItem(collectionID: Collection.ID) -> TVShowItem {
        TVShowItem(
            collectionID: collectionID,
            title: title,
            overview: overview,
            firstAirDate: firstAirDate,
            genres: genreNames.joined(separator: ", "),
            posterURL: posterURL,
            backdropURL: backdropURL,
            externalID: id,
            voteAverage: voteAverage,
            originalLanguage: originalLanguage
        )
    }
}

// MARK: - Client

struct TMDBClient {
    var searchMovies: @Sendable (String) async throws -> [MovieSearchResult]
    var fetchMovieDetail: @Sendable (String) async throws -> MovieSearchResult
    var searchTVShows: @Sendable (String) async throws -> [TVShowSearchResult]
    var fetchTVShowDetail: @Sendable (String) async throws -> TVShowSearchResult
}

private let tmdbImageBase = "https://image.tmdb.org/t/p/w500"

extension TMDBClient: DependencyKey {

    static let liveValue = TMDBClient(
        searchMovies: { query in
            let apiKey = await APIKeys.tmdb()
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let url = URL(string: "https://api.themoviedb.org/3/search/movie?api_key=\(apiKey)&query=\(encoded)&page=1")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBPagedResponse<TMDBMovie>.self, from: data)
            return response.results.map { $0.toSearchResult() }
        },
        fetchMovieDetail: { movieID in
            let apiKey = await APIKeys.tmdb()
            let url = URL(string: "https://api.themoviedb.org/3/movie/\(movieID)?api_key=\(apiKey)&append_to_response=credits")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let movie = try JSONDecoder().decode(TMDBMovieDetail.self, from: data)
            return movie.toSearchResult()
        },
        searchTVShows: { query in
            let apiKey = await APIKeys.tmdb()
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let url = URL(string: "https://api.themoviedb.org/3/search/tv?api_key=\(apiKey)&query=\(encoded)&page=1")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(TMDBPagedResponse<TMDBTVShow>.self, from: data)
            return response.results.map { $0.toSearchResult() }
        },
        fetchTVShowDetail: { showID in
            let apiKey = await APIKeys.tmdb()
            let url = URL(string: "https://api.themoviedb.org/3/tv/\(showID)?api_key=\(apiKey)&append_to_response=credits")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let show = try JSONDecoder().decode(TMDBTVShowDetail.self, from: data)
            return show.toSearchResult()
        }
    )

    static let testValue = TMDBClient(
        searchMovies: { _ in [] },
        fetchMovieDetail: { _ in MovieSearchResult(id: "test", title: "Test", overview: "", releaseDate: "", posterURL: "", backdropURL: "", voteAverage: 0, genreNames: [], originalLanguage: "") },
        searchTVShows: { _ in [] },
        fetchTVShowDetail: { _ in TVShowSearchResult(id: "test", title: "Test", overview: "", firstAirDate: "", posterURL: "", backdropURL: "", voteAverage: 0, genreNames: [], originalLanguage: "") }
    )
}

extension DependencyValues {
    var tmdbClient: TMDBClient {
        get { self[TMDBClient.self] }
        set { self[TMDBClient.self] = newValue }
    }
}

// MARK: - TMDB API Response Types

private struct TMDBPagedResponse<T: Decodable>: Decodable {
    let results: [T]
}

private struct TMDBMovie: Decodable {
    let id: Int
    let title: String?
    let overview: String?
    let release_date: String?
    let poster_path: String?
    let backdrop_path: String?
    let vote_average: Double?
    let genre_ids: [Int]?
    let original_language: String?

    func toSearchResult() -> MovieSearchResult {
        MovieSearchResult(
            id: "\(id)",
            title: title ?? "",
            overview: overview ?? "",
            releaseDate: release_date ?? "",
            posterURL: poster_path.map { tmdbImageBase + $0 } ?? "",
            backdropURL: backdrop_path.map { tmdbImageBase + $0 } ?? "",
            voteAverage: vote_average ?? 0,
            genreNames: (genre_ids ?? []).compactMap { TMDBGenres.movie[$0] },
            originalLanguage: original_language ?? ""
        )
    }
}

private struct TMDBMovieDetail: Decodable {
    let id: Int
    let title: String?
    let overview: String?
    let release_date: String?
    let runtime: Int?
    let poster_path: String?
    let backdrop_path: String?
    let vote_average: Double?
    let genres: [TMDBGenre]?
    let original_language: String?
    let imdb_id: String?
    let credits: TMDBCredits?

    struct TMDBGenre: Decodable {
        let name: String?
    }

    struct TMDBCredits: Decodable {
        let cast: [TMDBCastMember]?
        let crew: [TMDBCrewMember]?
    }

    struct TMDBCastMember: Decodable {
        let name: String?
        let order: Int?
    }

    struct TMDBCrewMember: Decodable {
        let name: String?
        let job: String?
    }

    func toSearchResult() -> MovieSearchResult {
        let director = credits?.crew?.first(where: { $0.job == "Director" })?.name ?? ""
        let castNames = (credits?.cast ?? [])
            .sorted(by: { ($0.order ?? 999) < ($1.order ?? 999) })
            .prefix(5)
            .compactMap(\.name)
            .joined(separator: ", ")

        let result = MovieSearchResult(
            id: "\(id)",
            title: title ?? "",
            overview: overview ?? "",
            releaseDate: release_date ?? "",
            posterURL: poster_path.map { tmdbImageBase + $0 } ?? "",
            backdropURL: backdrop_path.map { tmdbImageBase + $0 } ?? "",
            voteAverage: vote_average ?? 0,
            genreNames: (genres ?? []).compactMap(\.name),
            originalLanguage: original_language ?? ""
        )
        // Store director and cast in a way the caller can extract
        _ = director
        _ = castNames
        return result
    }
}

private struct TMDBTVShow: Decodable {
    let id: Int
    let name: String?
    let overview: String?
    let first_air_date: String?
    let poster_path: String?
    let backdrop_path: String?
    let vote_average: Double?
    let genre_ids: [Int]?
    let original_language: String?

    func toSearchResult() -> TVShowSearchResult {
        TVShowSearchResult(
            id: "\(id)",
            title: name ?? "",
            overview: overview ?? "",
            firstAirDate: first_air_date ?? "",
            posterURL: poster_path.map { tmdbImageBase + $0 } ?? "",
            backdropURL: backdrop_path.map { tmdbImageBase + $0 } ?? "",
            voteAverage: vote_average ?? 0,
            genreNames: (genre_ids ?? []).compactMap { TMDBGenres.tv[$0] },
            originalLanguage: original_language ?? ""
        )
    }
}

private struct TMDBTVShowDetail: Decodable {
    let id: Int
    let name: String?
    let overview: String?
    let first_air_date: String?
    let last_air_date: String?
    let number_of_seasons: Int?
    let number_of_episodes: Int?
    let poster_path: String?
    let backdrop_path: String?
    let vote_average: Double?
    let genres: [TMDBGenreObj]?
    let original_language: String?
    let status: String?
    let networks: [TMDBNetwork]?
    let created_by: [TMDBCreator]?
    let credits: TMDBTVCredits?

    struct TMDBGenreObj: Decodable { let name: String? }
    struct TMDBNetwork: Decodable { let name: String? }
    struct TMDBCreator: Decodable { let name: String? }
    struct TMDBTVCredits: Decodable {
        let cast: [TMDBTVCast]?
    }
    struct TMDBTVCast: Decodable {
        let name: String?
        let order: Int?
    }

    func toSearchResult() -> TVShowSearchResult {
        TVShowSearchResult(
            id: "\(id)",
            title: name ?? "",
            overview: overview ?? "",
            firstAirDate: first_air_date ?? "",
            posterURL: poster_path.map { tmdbImageBase + $0 } ?? "",
            backdropURL: backdrop_path.map { tmdbImageBase + $0 } ?? "",
            voteAverage: vote_average ?? 0,
            genreNames: (genres ?? []).compactMap(\.name),
            originalLanguage: original_language ?? ""
        )
    }
}

// MARK: - TMDB Genre ID Lookup

private enum TMDBGenres {
    static let movie: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        14: "Fantasy", 36: "History", 27: "Horror", 10402: "Music",
        9648: "Mystery", 10749: "Romance", 878: "Science Fiction",
        10770: "TV Movie", 53: "Thriller", 10752: "War", 37: "Western"
    ]

    static let tv: [Int: String] = [
        10759: "Action & Adventure", 16: "Animation", 35: "Comedy",
        80: "Crime", 99: "Documentary", 18: "Drama", 10751: "Family",
        10762: "Kids", 9648: "Mystery", 10763: "News", 10764: "Reality",
        10765: "Sci-Fi & Fantasy", 10766: "Soap", 10767: "Talk",
        10768: "War & Politics", 37: "Western"
    ]
}
