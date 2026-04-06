//
//  Collection.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct Collection: Identifiable, Hashable {
    let id: UUID
    var name: String
    var notes: String
    var type: CollectionType
    var coverImageURL: String
    var coverImageData: Data?
    var sortOrder: Int
    var isProtected: Bool
    var createdDate: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        notes: String = "",
        type: CollectionType = .book,
        coverImageURL: String = "",
        coverImageData: Data? = nil,
        sortOrder: Int = 0,
        isProtected: Bool = false,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.type = type
        self.coverImageURL = coverImageURL
        self.coverImageData = coverImageData
        self.sortOrder = sortOrder
        self.isProtected = isProtected
        self.createdDate = createdDate
    }
}
