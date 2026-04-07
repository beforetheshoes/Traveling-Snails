//
//  BookItem.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct BookItem: Hashable, Identifiable {
    let id: UUID
    var collectionID: Collection.ID
    var title: String
    var author: String
    var isbn: String
    var publisher: String
    var publishedDate: String
    var pageCount: Int
    var description: String
    var coverImageURL: String
    var coverImageData: Data?
    var externalID: String
    var rating: Int
    var status: BookStatus
    var startedDate: Date
    var finishedDate: Date
    var hasStartedDate: Bool
    var hasFinishedDate: Bool
    var notes: String
    var sortOrder: Int
    var createdDate: Date
    var addedByUserRecordName: String
    var lastEditedByUserRecordName: String

    init(
        id: UUID = UUID(),
        collectionID: Collection.ID,
        title: String = "",
        author: String = "",
        isbn: String = "",
        publisher: String = "",
        publishedDate: String = "",
        pageCount: Int = 0,
        description: String = "",
        coverImageURL: String = "",
        coverImageData: Data? = nil,
        externalID: String = "",
        rating: Int = 0,
        status: BookStatus = .wantToRead,
        startedDate: Date = .distantPast,
        finishedDate: Date = .distantPast,
        hasStartedDate: Bool = false,
        hasFinishedDate: Bool = false,
        notes: String = "",
        sortOrder: Int = 0,
        createdDate: Date = Date(),
        addedByUserRecordName: String = "",
        lastEditedByUserRecordName: String = ""
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.author = author
        self.isbn = isbn
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.pageCount = pageCount
        self.description = description
        self.coverImageURL = coverImageURL
        self.coverImageData = coverImageData
        self.externalID = externalID
        self.rating = rating
        self.status = status
        self.startedDate = startedDate
        self.finishedDate = finishedDate
        self.hasStartedDate = hasStartedDate
        self.hasFinishedDate = hasFinishedDate
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdDate = createdDate
        self.addedByUserRecordName = addedByUserRecordName
        self.lastEditedByUserRecordName = lastEditedByUserRecordName
    }

    var effectiveStartedDate: Date? {
        hasStartedDate ? startedDate : nil
    }

    var effectiveFinishedDate: Date? {
        hasFinishedDate ? finishedDate : nil
    }

    mutating func setStartedDate(_ date: Date) {
        startedDate = date
        hasStartedDate = true
    }

    mutating func setFinishedDate(_ date: Date) {
        finishedDate = date
        hasFinishedDate = true
    }

    mutating func clearStartedDate() {
        startedDate = .distantPast
        hasStartedDate = false
    }

    mutating func clearFinishedDate() {
        finishedDate = .distantPast
        hasFinishedDate = false
    }
}

extension BookItem: CollectionItemProtocol {
    static var collectionType: CollectionType { .book }

    var displaySubtitle: String {
        author.isEmpty ? publisher : author
    }
}
