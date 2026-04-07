//
//  MovieItem.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct MovieItem: Hashable, Identifiable {
    let id: UUID
    var collectionID: Collection.ID
    var title: String
    var overview: String
    var releaseDate: String
    var runtime: Int
    var director: String
    var cast: String
    var genres: String
    var posterURL: String
    var backdropURL: String
    var coverImageData: Data?
    var externalID: String
    var imdbID: String
    var rating: Int
    var status: MovieStatus
    var watchedDate: Date
    var hasWatchedDate: Bool
    var notes: String
    var sortOrder: Int
    var createdDate: Date
    var voteAverage: Double
    var originalLanguage: String
    var addedByUserRecordName: String
    var lastEditedByUserRecordName: String

    init(
        id: UUID = UUID(),
        collectionID: Collection.ID,
        title: String = "",
        overview: String = "",
        releaseDate: String = "",
        runtime: Int = 0,
        director: String = "",
        cast: String = "",
        genres: String = "",
        posterURL: String = "",
        backdropURL: String = "",
        coverImageData: Data? = nil,
        externalID: String = "",
        imdbID: String = "",
        rating: Int = 0,
        status: MovieStatus = .wantToWatch,
        watchedDate: Date = .distantPast,
        hasWatchedDate: Bool = false,
        notes: String = "",
        sortOrder: Int = 0,
        createdDate: Date = Date(),
        voteAverage: Double = 0,
        originalLanguage: String = "",
        addedByUserRecordName: String = "",
        lastEditedByUserRecordName: String = ""
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.overview = overview
        self.releaseDate = releaseDate
        self.runtime = runtime
        self.director = director
        self.cast = cast
        self.genres = genres
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.coverImageData = coverImageData
        self.externalID = externalID
        self.imdbID = imdbID
        self.rating = rating
        self.status = status
        self.watchedDate = watchedDate
        self.hasWatchedDate = hasWatchedDate
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.voteAverage = voteAverage
        self.originalLanguage = originalLanguage
        self.addedByUserRecordName = addedByUserRecordName
        self.lastEditedByUserRecordName = lastEditedByUserRecordName
    }

    var effectiveWatchedDate: Date? {
        hasWatchedDate ? watchedDate : nil
    }

    mutating func setWatchedDate(_ date: Date) {
        watchedDate = date
        hasWatchedDate = true
    }

    mutating func clearWatchedDate() {
        watchedDate = .distantPast
        hasWatchedDate = false
    }

    var runtimeFormatted: String {
        guard runtime > 0 else { return "" }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var coverImageURL: String { posterURL }
    var displaySubtitle: String {
        if !director.isEmpty { return director }
        if !releaseDate.isEmpty { return String(releaseDate.prefix(4)) }
        return ""
    }
}

extension MovieItem: CollectionItemProtocol {
    static var collectionType: CollectionType { .movie }
}
