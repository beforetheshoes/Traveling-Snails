//
//  TVShowItem.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct TVShowItem: Hashable, Identifiable {
    let id: UUID
    var collectionID: Collection.ID
    var title: String
    var overview: String
    var firstAirDate: String
    var lastAirDate: String
    var numberOfSeasons: Int
    var numberOfEpisodes: Int
    var creators: String
    var cast: String
    var genres: String
    var posterURL: String
    var backdropURL: String
    var coverImageData: Data?
    var externalID: String
    var imdbID: String
    var rating: Int
    var status: TVShowStatus
    var showStatus: String
    var notes: String
    var sortOrder: Int
    var createdDate: Date
    var voteAverage: Double
    var originalLanguage: String
    var network: String
    var addedByUserRecordName: String
    var lastEditedByUserRecordName: String

    init(
        id: UUID = UUID(),
        collectionID: Collection.ID,
        title: String = "",
        overview: String = "",
        firstAirDate: String = "",
        lastAirDate: String = "",
        numberOfSeasons: Int = 0,
        numberOfEpisodes: Int = 0,
        creators: String = "",
        cast: String = "",
        genres: String = "",
        posterURL: String = "",
        backdropURL: String = "",
        coverImageData: Data? = nil,
        externalID: String = "",
        imdbID: String = "",
        rating: Int = 0,
        status: TVShowStatus = .wantToWatch,
        showStatus: String = "",
        notes: String = "",
        sortOrder: Int = 0,
        createdDate: Date = Date(),
        voteAverage: Double = 0,
        originalLanguage: String = "",
        network: String = "",
        addedByUserRecordName: String = "",
        lastEditedByUserRecordName: String = ""
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.overview = overview
        self.firstAirDate = firstAirDate
        self.lastAirDate = lastAirDate
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
        self.creators = creators
        self.cast = cast
        self.genres = genres
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.coverImageData = coverImageData
        self.externalID = externalID
        self.imdbID = imdbID
        self.rating = rating
        self.status = status
        self.showStatus = showStatus
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.voteAverage = voteAverage
        self.originalLanguage = originalLanguage
        self.network = network
        self.addedByUserRecordName = addedByUserRecordName
        self.lastEditedByUserRecordName = lastEditedByUserRecordName
    }

    var coverImageURL: String { posterURL }
    var displaySubtitle: String {
        if !network.isEmpty { return network }
        if !firstAirDate.isEmpty { return String(firstAirDate.prefix(4)) }
        return ""
    }
}

extension TVShowItem: CollectionItemProtocol {
    static var collectionType: CollectionType { .tvShow }
}
