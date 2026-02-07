import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TripActivityDetailFeature {
    enum ActiveSheet: String, Identifiable, Equatable {
        case organizationPicker
        case map

        var id: String { rawValue }
    }

    enum ActivityTarget: Equatable {
        case activity(Activity)
        case lodging(Lodging)
        case transportation(Transportation)

        var activityType: ActivityWrapper.ActivityType {
            switch self {
            case .activity:
                return .activity
            case .lodging:
                return .lodging
            case .transportation:
                return .transportation
            }
        }

        var id: UUID {
            switch self {
            case .activity(let activity):
                return activity.id
            case .lodging(let lodging):
                return lodging.id
            case .transportation(let transportation):
                return transportation.id
            }
        }

        var fileAttachments: [EmbeddedFileAttachment] {
            switch self {
            case .activity(let activity):
                return activity.fileAttachments
            case .lodging(let lodging):
                return lodging.fileAttachments
            case .transportation(let transportation):
                return transportation.fileAttachments
            }
        }

        func editData() -> TripActivityEditData {
            switch self {
            case .activity(let activity):
                return TripActivityEditData(from: activity)
            case .lodging(let lodging):
                return TripActivityEditData(from: lodging)
            case .transportation(let transportation):
                return TripActivityEditData(from: transportation)
            }
        }

        func replacingAttachments(_ attachments: [EmbeddedFileAttachment]) -> Self {
            switch self {
            case .activity(var activity):
                activity.fileAttachments = attachments
                return .activity(activity)
            case .lodging(var lodging):
                lodging.fileAttachments = attachments
                return .lodging(lodging)
            case .transportation(var transportation):
                transportation.fileAttachments = attachments
                return .transportation(transportation)
            }
        }
    }

    @ObservableState
    struct State: Equatable {
        var snapshot: ActivityTarget
        var editData: TripActivityEditData
        var attachments: [EmbeddedFileAttachment]

        var isEditing = false
        var activeSheet: ActiveSheet?
        var showDeleteConfirmation = false
        var shouldDismiss = false
        var errorMessage: String?

        init(snapshot: ActivityTarget) {
            self.snapshot = snapshot
            self.editData = snapshot.editData()
            self.attachments = snapshot.fileAttachments
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case onAppear
        case startEditing
        case cancelEditing
        case saveTapped
        case saveSucceeded(ActivityTarget)
        case saveFailed(String)
        case deleteTapped
        case deleteDialogChanged(Bool)
        case deleteConfirmed
        case deleteSucceeded
        case deleteFailed(String)
        case sheetChanged(ActiveSheet?)
        case attachmentAdded(EmbeddedFileAttachment)
        case attachmentPersisted(EmbeddedFileAttachment)
        case attachmentPersistFailed(String)
        case attachmentRemoved(EmbeddedFileAttachment)
        case fetchedAttachmentsChanged([EmbeddedFileAttachment])
        case dismissHandled
        case dismissError
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                state.editData = state.snapshot.editData()
                state.attachments = state.snapshot.fileAttachments
                return .none

            case .startEditing:
                state.editData = state.snapshot.editData()
                state.attachments = state.snapshot.fileAttachments
                state.isEditing = true
                return .none

            case .cancelEditing:
                state.editData = state.snapshot.editData()
                state.attachments = state.snapshot.fileAttachments
                state.isEditing = false
                return .none

            case .saveTapped:
                let snapshot = state.snapshot
                let editData = state.editData
                let attachments = state.attachments
                return .run { send in
                    do {
                        let savedTarget = try await database.write { db in
                            try Self.persist(
                                snapshot: snapshot,
                                editData: editData,
                                attachments: attachments,
                                in: db
                            )
                        }
                        await send(.saveSucceeded(savedTarget))
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .saveSucceeded(let savedTarget):
                state.snapshot = savedTarget
                state.attachments = savedTarget.fileAttachments
                state.isEditing = false
                return .none

            case .saveFailed(let message):
                state.errorMessage = message
                Logger.shared.error("Failed to save activity details: \(message)", category: .database)
                return .none

            case .deleteTapped:
                state.showDeleteConfirmation = true
                return .none

            case .deleteDialogChanged(let isPresented):
                state.showDeleteConfirmation = isPresented
                return .none

            case .deleteConfirmed:
                state.showDeleteConfirmation = false
                let snapshot = state.snapshot
                return .run { send in
                    do {
                        try await database.write { db in
                            switch snapshot {
                            case .activity(let activity):
                                try Activity.find(activity.id).delete().execute(db)
                            case .lodging(let lodging):
                                try Lodging.find(lodging.id).delete().execute(db)
                            case .transportation(let transportation):
                                try Transportation.find(transportation.id).delete().execute(db)
                            }
                        }
                        await send(.deleteSucceeded)
                    } catch {
                        await send(.deleteFailed(error.localizedDescription))
                    }
                }

            case .deleteSucceeded:
                state.shouldDismiss = true
                return .none

            case .deleteFailed(let message):
                state.errorMessage = message
                return .none

            case .sheetChanged(let sheet):
                state.activeSheet = sheet
                return .none

            case .attachmentAdded(let attachment):
                let snapshot = state.snapshot
                return .run { send in
                    do {
                        let updatedAttachment = try await database.write { db in
                            try Self.persistAttachment(attachment, for: snapshot, in: db)
                        }
                        await send(.attachmentPersisted(updatedAttachment))
                    } catch {
                        await send(.attachmentPersistFailed(error.localizedDescription))
                    }
                }

            case .attachmentPersisted(let attachment):
                if let index = state.attachments.firstIndex(where: { $0.id == attachment.id }) {
                    state.attachments[index] = attachment
                } else {
                    state.attachments.append(attachment)
                }
                state.snapshot = state.snapshot.replacingAttachments(state.attachments)
                return .none

            case .attachmentPersistFailed(let message):
                state.errorMessage = message
                return .none

            case .attachmentRemoved(let attachment):
                state.attachments.removeAll { $0.id == attachment.id }
                state.snapshot = state.snapshot.replacingAttachments(state.attachments)
                return .none

            case .fetchedAttachmentsChanged(let attachments):
                guard !state.isEditing else { return .none }
                state.attachments = attachments
                state.snapshot = state.snapshot.replacingAttachments(attachments)
                return .none

            case .dismissHandled:
                state.shouldDismiss = false
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none
            }
        }
    }

    private static func persist<DB: Database>(
        snapshot: ActivityTarget,
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        in db: DB
    ) throws -> ActivityTarget {
        switch snapshot {
        case .activity(var activity):
            activity.name = editData.name
            activity.start = editData.start
            activity.end = editData.end
            activity.startTZId = editData.startTZId
            activity.endTZId = editData.endTZId
            activity.cost = editData.cost
            activity.paid = editData.paid
            activity.reservation = editData.confirmationField
            activity.notes = editData.notes
            activity.organizationID = editData.organization?.id
            activity.customLocationName = editData.customLocationName
            activity.addressID = editData.customAddress?.id
            activity.hideLocation = editData.hideLocation

            try Activity.upsert { activity }.execute(db)
            try EmbeddedFileAttachment.where { $0.activityID.eq(activity.id) }.delete().execute(db)
            let drafts = attachments.map {
                EmbeddedFileAttachment.Draft(
                    id: $0.id,
                    fileName: $0.fileName,
                    originalFileName: $0.originalFileName,
                    fileSize: $0.fileSize,
                    mimeType: $0.mimeType,
                    fileExtension: $0.fileExtension,
                    createdDate: $0.createdDate,
                    fileDescription: $0.fileDescription,
                    fileData: $0.fileData,
                    activityID: activity.id,
                    lodgingID: nil,
                    transportationID: nil
                )
            }
            if !drafts.isEmpty {
                try EmbeddedFileAttachment.insert {
                    for draft in drafts {
                        draft
                    }
                }.execute(db)
            }
            return .activity(activity)

        case .lodging(var lodging):
            lodging.name = editData.name
            lodging.start = editData.start
            lodging.end = editData.end
            lodging.checkInTZId = editData.startTZId
            lodging.checkOutTZId = editData.endTZId
            lodging.cost = editData.cost
            lodging.paid = editData.paid
            lodging.reservation = editData.confirmationField
            lodging.notes = editData.notes
            lodging.organizationID = editData.organization?.id
            lodging.customLocationName = editData.customLocationName
            lodging.addressID = editData.customAddress?.id
            lodging.hideLocation = editData.hideLocation

            try Lodging.upsert { lodging }.execute(db)
            try EmbeddedFileAttachment.where { $0.lodgingID.eq(lodging.id) }.delete().execute(db)
            let drafts = attachments.map {
                EmbeddedFileAttachment.Draft(
                    id: $0.id,
                    fileName: $0.fileName,
                    originalFileName: $0.originalFileName,
                    fileSize: $0.fileSize,
                    mimeType: $0.mimeType,
                    fileExtension: $0.fileExtension,
                    createdDate: $0.createdDate,
                    fileDescription: $0.fileDescription,
                    fileData: $0.fileData,
                    activityID: nil,
                    lodgingID: lodging.id,
                    transportationID: nil
                )
            }
            if !drafts.isEmpty {
                try EmbeddedFileAttachment.insert {
                    for draft in drafts {
                        draft
                    }
                }.execute(db)
            }
            return .lodging(lodging)

        case .transportation(var transportation):
            transportation.name = editData.name
            transportation.start = editData.start
            transportation.end = editData.end
            transportation.startTZId = editData.startTZId
            transportation.endTZId = editData.endTZId
            transportation.cost = editData.cost
            transportation.paid = editData.paid
            transportation.confirmation = editData.confirmationField
            transportation.notes = editData.notes
            transportation.organizationID = editData.organization?.id
            transportation.type = editData.transportationType ?? .plane

            try Transportation.upsert { transportation }.execute(db)
            try EmbeddedFileAttachment.where { $0.transportationID.eq(transportation.id) }.delete().execute(db)
            let drafts = attachments.map {
                EmbeddedFileAttachment.Draft(
                    id: $0.id,
                    fileName: $0.fileName,
                    originalFileName: $0.originalFileName,
                    fileSize: $0.fileSize,
                    mimeType: $0.mimeType,
                    fileExtension: $0.fileExtension,
                    createdDate: $0.createdDate,
                    fileDescription: $0.fileDescription,
                    fileData: $0.fileData,
                    activityID: nil,
                    lodgingID: nil,
                    transportationID: transportation.id
                )
            }
            if !drafts.isEmpty {
                try EmbeddedFileAttachment.insert {
                    for draft in drafts {
                        draft
                    }
                }.execute(db)
            }
            return .transportation(transportation)
        }
    }

    private static func persistAttachment<DB: Database>(
        _ attachment: EmbeddedFileAttachment,
        for target: ActivityTarget,
        in db: DB
    ) throws -> EmbeddedFileAttachment {
        var updated = attachment

        switch target {
        case .activity(let activity):
            updated.activityID = activity.id
            updated.lodgingID = nil
            updated.transportationID = nil
        case .lodging(let lodging):
            updated.activityID = nil
            updated.lodgingID = lodging.id
            updated.transportationID = nil
        case .transportation(let transportation):
            updated.activityID = nil
            updated.lodgingID = nil
            updated.transportationID = transportation.id
        }

        try EmbeddedFileAttachment.upsert { updated }.execute(db)
        return updated
    }
}

extension TripActivityDetailFeature.ActivityTarget {
    init<T: TripActivityProtocol>(activity: T) {
        switch activity.activityType {
        case .activity:
            self = .activity(activity as? Activity ?? Activity(id: activity.id))
        case .lodging:
            self = .lodging(activity as? Lodging ?? Lodging(id: activity.id))
        case .transportation:
            self = .transportation(activity as? Transportation ?? Transportation(id: activity.id))
        }
    }
}
