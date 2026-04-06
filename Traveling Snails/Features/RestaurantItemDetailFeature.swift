//
//  RestaurantItemDetailFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct RestaurantItemDetailFeature {
    @ObservableState
    struct State: Equatable {
        var restaurantItem: RestaurantItem
        var isEditing = false
        var editedNotes: String = ""
        var showingDeleteConfirmation = false
        var isDeleted = false
        var showingImageOptions = false
        var showingImageURLInput = false
        var imageURLText: String = ""
        var showingPhotoPicker = false
        var isDownloadingImage = false
    }

    enum Action: Equatable {
        case onAppear
        case refreshRestaurantItem
        case restaurantItemLoaded(RestaurantItem?)

        case ratingChanged(Int)
        case statusChanged(RestaurantStatus)

        case editNotesTapped
        case editedNotesChanged(String)
        case saveNotesTapped
        case cancelEditNotes

        case visitedDateChanged(Date?)

        case coverImageTapped
        case imageOptionsDismissed
        case pasteImageURLTapped
        case imageURLChanged(String)
        case imageURLSubmitted
        case imageURLDismissed
        case photoPickerTapped
        case photoPickerDismissed
        case photoSelected(Data)
        case resetCoverImageTapped
        case coverImageUpdated(Data, String)

        case deleteTapped
        case deleteConfirmed
        case deleteCancelled
        case deleted
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.mapKitSearchClient) private var mapKitSearchClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .send(.refreshRestaurantItem)

            case .refreshRestaurantItem:
                let id = state.restaurantItem.id
                return .run { send in
                    let item = try? await database.read { db in
                        try RestaurantItem.find(id).fetchOne(db)
                    }
                    await send(.restaurantItemLoaded(item))
                }

            case .restaurantItemLoaded(let item):
                guard let item else { return .none }
                state.restaurantItem = item
                return .none

            case .ratingChanged(let rating):
                state.restaurantItem.rating = rating
                let updated = state.restaurantItem
                return .run { _ in
                    try await database.write { db in
                        try RestaurantItem.upsert { updated }.execute(db)
                    }
                } catch: { error, _ in
                    Logger.shared.error("Failed to save rating: \(error)", category: .database)
                }

            case .statusChanged(let status):
                state.restaurantItem.status = status
                if status == .enjoyed && !state.restaurantItem.hasVisitedDate {
                    state.restaurantItem.setVisitedDate(Date())
                }
                let updated = state.restaurantItem
                return .run { _ in
                    try await database.write { db in
                        try RestaurantItem.upsert { updated }.execute(db)
                    }
                } catch: { error, _ in
                    Logger.shared.error("Failed to save status: \(error)", category: .database)
                }

            case .editNotesTapped:
                state.isEditing = true
                state.editedNotes = state.restaurantItem.notes
                return .none

            case .editedNotesChanged(let notes):
                state.editedNotes = notes
                return .none

            case .saveNotesTapped:
                state.isEditing = false
                state.restaurantItem.notes = state.editedNotes
                let updated = state.restaurantItem
                return .run { _ in
                    try await database.write { db in
                        try RestaurantItem.upsert { updated }.execute(db)
                    }
                } catch: { error, _ in
                    Logger.shared.error("Failed to save notes: \(error)", category: .database)
                }

            case .cancelEditNotes:
                state.isEditing = false
                return .none

            case .visitedDateChanged(let date):
                if let date {
                    state.restaurantItem.setVisitedDate(date)
                } else {
                    state.restaurantItem.clearVisitedDate()
                }
                let updated = state.restaurantItem
                return .run { _ in
                    try await database.write { db in
                        try RestaurantItem.upsert { updated }.execute(db)
                    }
                } catch: { error, _ in
                    Logger.shared.error("Failed to save visited date: \(error)", category: .database)
                }

            case .coverImageTapped:
                state.showingImageOptions = true
                return .none

            case .imageOptionsDismissed:
                state.showingImageOptions = false
                return .none

            case .pasteImageURLTapped:
                state.showingImageOptions = false
                state.showingImageURLInput = true
                state.imageURLText = ""
                return .none

            case .imageURLChanged(let text):
                state.imageURLText = text
                return .none

            case .imageURLSubmitted:
                let urlString = state.imageURLText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !urlString.isEmpty, let url = URL(string: urlString) else {
                    state.showingImageURLInput = false
                    return .none
                }
                state.showingImageURLInput = false
                state.isDownloadingImage = true
                return .run { send in
                    if let (data, response) = try? await URLSession.shared.data(from: url),
                       let http = response as? HTTPURLResponse,
                       http.statusCode == 200,
                       data.count > 100 {
                        await send(.coverImageUpdated(data, "custom"))
                    }
                }

            case .imageURLDismissed:
                state.showingImageURLInput = false
                return .none

            case .photoPickerTapped:
                state.showingImageOptions = false
                state.showingPhotoPicker = true
                return .none

            case .photoPickerDismissed:
                state.showingPhotoPicker = false
                return .none

            case .photoSelected(let data):
                state.showingPhotoPicker = false
                return .send(.coverImageUpdated(data, "custom"))

            case .resetCoverImageTapped:
                state.showingImageOptions = false
                let item = state.restaurantItem
                state.restaurantItem.coverImageData = nil
                state.restaurantItem.coverImageType = nil
                let id = item.id
                return .run { [mapKitSearchClient] send in
                    // Clear the existing image
                    let nilData: Data? = nil
                    try? await database.write { db in
                        try RestaurantItem.find(id)
                            .update {
                                $0.coverImageData = #bind(nilData)
                                $0.coverImageType = #bind("")
                            }
                            .execute(db)
                    }
                    // Re-fetch brand image or map snapshot
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
                        await send(.coverImageUpdated(imageData, imageType))
                    }
                }

            case .coverImageUpdated(let data, let type):
                state.restaurantItem.coverImageData = data
                state.restaurantItem.coverImageType = type
                state.isDownloadingImage = false
                let id = state.restaurantItem.id
                let imageType = type
                return .run { _ in
                    try? await database.write { db in
                        try RestaurantItem.find(id)
                            .update {
                                $0.coverImageData = #bind(data)
                                $0.coverImageType = #bind(imageType)
                            }
                            .execute(db)
                    }
                } catch: { error, _ in
                    Logger.shared.error("Failed to save cover image: \(error)", category: .database)
                }

            case .deleteTapped:
                state.showingDeleteConfirmation = true
                return .none

            case .deleteConfirmed:
                state.showingDeleteConfirmation = false
                let id = state.restaurantItem.id
                return .run { send in
                    try await database.write { db in
                        try RestaurantItem.find(id).delete().execute(db)
                    }
                    await send(.deleted)
                }

            case .deleteCancelled:
                state.showingDeleteConfirmation = false
                return .none

            case .deleted:
                state.isDeleted = true
                return .none
            }
        }
    }
}
