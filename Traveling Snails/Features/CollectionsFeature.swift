//
//  CollectionsFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct CollectionsFeature {
    @ObservableState
    struct State {
        @FetchAll(Collection.order { $0.createdDate.desc() })
        var collections: [Collection] = []
    }

    enum Action {
        case noop
        case deleteCollection(Collection)
        case createCollection(name: String, type: CollectionType)
        case renameCollection(Collection, newName: String)
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .noop:
                return .none

            case .deleteCollection(let collection):
                return .run { [database] _ in
                    try await database.write { db in
                        try Collection.find(collection.id).delete().execute(db)
                    }
                }

            case .createCollection(let name, let type):
                let collection = Collection(name: name, type: type)
                return .run { [database] _ in
                    try await database.write { db in
                        try Collection.upsert { collection }.execute(db)
                    }
                }

            case .renameCollection(var collection, let newName):
                collection.name = newName
                let toSave = collection
                return .run { [database] _ in
                    try await database.write { db in
                        try Collection.upsert { toSave }.execute(db)
                    }
                }
            }
        }
    }
}
