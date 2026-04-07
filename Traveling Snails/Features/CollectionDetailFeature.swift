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
    case movieItem(UUID)
    case tvShowItem(UUID)
    case restaurantItem(UUID)
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

    enum GroupBy: String, CaseIterable, Equatable {
        case none = "None"
        case city = "City"
        case state = "State"
        case country = "Country"

        var displayName: String { rawValue }
    }

    @ObservableState
    struct State: Equatable {
        var collection: Collection
        var path: [CollectionRoute] = []
        var viewMode: ViewMode = .grid
        var groupBy: GroupBy = .none
        var showingAddSheet = false
        var sharedRecord: SharedRecord?
        var isPreparingShare = false
        var shareError: String?
        var isEditingName = false
        var editedName: String = ""
        var participants: [ShareParticipant] = []
        var isLoadingParticipants = false
        var showingParticipants = false
        var isShared = false
        var canWrite = true
    }

    enum Action: Equatable {
        case onAppear
        case refreshCollection
        case collectionLoaded(Collection?)
        case viewModeChanged(ViewMode)
        case groupByChanged(GroupBy)
        case addItemTapped
        case addSheetDismissed
        case itemSelected(CollectionRoute)
        case pathChanged([CollectionRoute])

        case shareTapped
        case shareCreated(SharedRecord)
        case shareFailed(String)
        case shareDismissed
        case manageShareTapped
        case toggleParticipantSheet

        case loadShareStatus
        case shareStatusLoaded(isShared: Bool, canWrite: Bool, participants: [ShareParticipant])

        case editNameTapped
        case editedNameChanged(String)
        case saveNameTapped
        case cancelEditName

        case deleteBookItem(BookItem)
        case deleteMovieItem(MovieItem)
        case deleteTVShowItem(TVShowItem)
        case deleteRestaurantItem(RestaurantItem)

        case regenerateMissingCovers([RestaurantItem])
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.defaultSyncEngine) private var syncEngine
    @Dependency(\.mapKitSearchClient) private var mapKitSearchClient
    @Dependency(\.userIdentityClient) private var userIdentityClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .send(.refreshCollection),
                    .send(.loadShareStatus)
                )

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

            case .groupByChanged(let groupBy):
                state.groupBy = groupBy
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

            case .pathChanged(let newPath):
                state.path = newPath
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
                return .send(.loadShareStatus)

            case .manageShareTapped:
                guard !state.isPreparingShare else { return .none }
                state.isPreparingShare = true
                let collection = state.collection
                return .run { [syncEngine] send in
                    do {
                        let record = try await syncEngine.share(record: collection) { _ in }
                        await send(.shareCreated(record))
                    } catch {
                        await send(.shareFailed(error.localizedDescription))
                    }
                }

            case .toggleParticipantSheet:
                state.showingParticipants.toggle()
                return .none

            case .loadShareStatus:
                state.isLoadingParticipants = true
                let metadataID = state.collection.syncMetadataID
                return .run { [database, userIdentityClient] send in
                    let share = try? await database.read { db in
                        try SyncMetadata
                            .find(metadataID)
                            .select(\.share)
                            .fetchOne(db)
                            ?? nil
                    }
                    let isShared = share != nil
                    var participants: [ShareParticipant] = []
                    var canWrite = true
                    if let share {
                        await userIdentityClient.cacheParticipantNames(share.participants)
                        participants = ShareParticipant.from(share: share)
                        let currentUser = share.currentUserParticipant
                        canWrite = currentUser?.permission == .readWrite
                            || share.owner == currentUser
                    }
                    await send(.shareStatusLoaded(
                        isShared: isShared,
                        canWrite: canWrite,
                        participants: participants
                    ))
                }

            case .shareStatusLoaded(let isShared, let canWrite, let participants):
                state.isLoadingParticipants = false
                state.isShared = isShared
                state.canWrite = canWrite
                state.participants = participants
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

            case .deleteMovieItem(let movieItem):
                return .run { _ in
                    try await database.write { db in
                        try MovieItem.find(movieItem.id).delete().execute(db)
                    }
                }

            case .deleteTVShowItem(let tvShowItem):
                return .run { _ in
                    try await database.write { db in
                        try TVShowItem.find(tvShowItem.id).delete().execute(db)
                    }
                }

            case .deleteRestaurantItem(let restaurantItem):
                return .run { _ in
                    try await database.write { db in
                        try RestaurantItem.find(restaurantItem.id).delete().execute(db)
                    }
                }

            case .regenerateMissingCovers(let items):
                // Only regenerate for items without covers that aren't custom-set
                let needsCovers = items.filter {
                    $0.coverImageData == nil
                    && $0.coverImageType != "custom"
                    && ($0.hasCoordinate || !$0.websiteURL.isEmpty)
                }
                guard !needsCovers.isEmpty else { return .none }
                return .merge(needsCovers.map { item in
                    .run { [mapKitSearchClient, database] _ in
                        var imageData: Data?
                        var imageType = ""

                        if !item.websiteURL.isEmpty {
                            imageData = await mapKitSearchClient.fetchBrandImage(item.websiteURL)
                            if imageData != nil { imageType = "brand" }
                        }

                        if imageData == nil && item.hasCoordinate {
                            imageData = await mapKitSearchClient.generateSnapshot(
                                item.latitude, item.longitude, item.title
                            )
                            if imageData != nil { imageType = "map" }
                        }

                        if let imageData {
                            let type = imageType
                            try? await database.write { db in
                                try RestaurantItem.find(item.id)
                                    .update {
                                        $0.coverImageData = #bind(imageData)
                                        $0.coverImageType = #bind(type)
                                    }
                                    .execute(db)
                            }
                        }
                    }
                })
            }
        }
    }
}
