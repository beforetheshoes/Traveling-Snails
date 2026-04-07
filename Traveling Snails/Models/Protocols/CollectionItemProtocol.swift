//
//  CollectionItemProtocol.swift
//  Traveling Snails
//

import Foundation

protocol CollectionItemProtocol: Identifiable, Equatable {
    var id: UUID { get }
    var collectionID: Collection.ID { get set }
    var title: String { get set }
    var notes: String { get set }
    var rating: Int { get set }
    var coverImageURL: String { get }
    var coverImageData: Data? { get set }
    var externalID: String { get set }
    var sortOrder: Int { get set }
    var createdDate: Date { get }
    var addedByUserRecordName: String { get }
    var lastEditedByUserRecordName: String { get }

    static var collectionType: CollectionType { get }
    var displaySubtitle: String { get }
}
