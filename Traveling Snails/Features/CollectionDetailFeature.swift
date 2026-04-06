//
//  CollectionDetailFeature.swift
//  Traveling Snails
//

import CloudKit
import ComposableArchitecture
import Foundation
import SQLiteData

enum CollectionRoute: Hashable {
    case bookItem(UUID)
}

@Reducer
struct CollectionDetailFeature {
    enum ViewMode: String, CaseIterable, Equatable {
        case grid = "Grid"
        case list = "List"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .list: return "list.bullet"
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var collection: Collection
        var path: [CollectionRoute] = []
        var viewMode: ViewMode = .grid
        var showingAddSheet = false
        var sharedRecord: SharedRecord?
        var isPreparingShare = false
        var shareError: String?
        var isEditingName = false
        var editedName: String = ""
    }

    enum Action: Equatable {
        case onAppear
        case refreshCollection
        case collectionLoaded(Collection?)
        case viewModeChanged(ViewMode)
        case addItemTapped
        case addSheetDismissed
        case itemSelected(CollectionRoute)

        case shareTapped
        case shareCreated(SharedRecord)
        case shareFailed(String)
        case shareDismissed

        case editNameTapped
        case editedNameChanged(String)
        case saveNameTapped
        case cancelEditName

        case deleteBookItem(BookItem)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.defaultSyncEngine) private var syncEngine

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshCollection)

            case .refreshCollection:
                let collectionID = state.collection.id
                return .run { send in
                    let collection = try? await database.read { db in
                        try Collection.find(collectionID).fetchOne(db)
                    }
                    await send(.collectionLoaded(collection))
                }

            case .collectionLoaded(let collection):
                guard let collection else { return .none }
                state.collection = collection
                return .none

            case .viewModeChanged(let mode):
                state.viewMode = mode
                return .none

            case .addItemTapped:
                state.showingAddSheet = true
                return .none

            case .addSheetDismissed:
                state.showingAddSheet = false
                return .none

            case .itemSelected(let route):
                state.path.append(route)
                return .none

            case .shareTapped:
                guard !state.isPreparingShare else { return .none }
                state.isPreparingShare = true
                state.shareError = nil
                let collection = state.collection
                return .run { [syncEngine] send in
                    do {
                        try await syncEngine.sendChanges()
                        let record = try await syncEngine.share(record: collection) { share in
                            share[CKShare.SystemFieldKey.title] = collection.name.isEmpty
                                ? collection.type.singularName
                                : collection.name
                        }
                        await send(.shareCreated(record))
                    } catch {
                        await send(.shareFailed(error.localizedDescription))
                    }
                }

            case .shareCreated(let record):
                state.isPreparingShare = false
                state.sharedRecord = record
                return .none

            case .shareFailed(let message):
                state.isPreparingShare = false
                state.shareError = message
                return .none

            case .shareDismissed:
                state.sharedRecord = nil
                state.shareError = nil
                return .none

            case .editNameTapped:
                state.isEditingName = true
                state.editedName = state.collection.name
                return .none

            case .editedNameChanged(let name):
                state.editedName = name
                return .none

            case .saveNameTapped:
                state.isEditingName = false
                state.collection.name = state.editedName
                let toSave = state.collection
                return .run { _ in
                    try await database.write { db in
                        try Collection.upsert { toSave }.execute(db)
                    }
                }

            case .cancelEditName:
                state.isEditingName = false
                return .none

            case .deleteBookItem(let bookItem):
                return .run { _ in
                    try await database.write { db in
                        try BookItem.find(bookItem.id).delete().execute(db)
                    }
                }
            }
        }
    }
}
