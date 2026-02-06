//
//  UniversalActivityFormFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct UniversalActivityFormFeature {
    @ObservableState
    struct State: Equatable {
        let trip: Trip
        let activityType: ActivityType
        var existingActivity: (any TripActivityProtocol)?
        var isEditMode: Bool

        var editData: TripActivityEditData
        var attachments: [EmbeddedFileAttachment]
        var isSaving = false
        var showingOrganizationPicker = false
        var saveError: Error?
        var shouldDismiss = false

        init(trip: Trip, activityType: ActivityType) {
            self.trip = trip
            self.activityType = activityType
            self.existingActivity = nil
            self.isEditMode = false

            let saver = ActivitySaverFactory.createSaver(for: activityType)
            let template = saver.createTemplate(in: trip)
            self.editData = TripActivityEditData(from: template)
            self.attachments = []
        }

        init<T: TripActivityProtocol>(existingActivity: T) {
            self.trip = existingActivity.trip ?? Trip(name: "")
            self.activityType = ActivityType(rawValue: existingActivity.activityType.rawValue) ?? .activity
            self.existingActivity = existingActivity
            self.isEditMode = true
            self.editData = TripActivityEditData(from: existingActivity)
            self.attachments = existingActivity.fileAttachments
        }

        var activitySaver: ActivitySaver {
            ActivitySaverFactory.createSaver(for: activityType)
        }

        var isFormValid: Bool {
            editData.organization != nil && !editData.name.isEmpty
        }

        var icon: String { activitySaver.icon }
        var color: String { activitySaver.color }
        var startLabel: String { activitySaver.startLabel }
        var endLabel: String { activitySaver.endLabel }
        var confirmationLabel: String { activitySaver.confirmationLabel }
        var supportsCustomLocation: Bool { activitySaver.supportsCustomLocation }
        var hasTypeSelector: Bool { activitySaver.hasTypeSelector }

        var currentIcon: String {
            if case .transportation = activityType,
               let transportationType = editData.transportationType {
                return transportationType.systemImage
            }
            return icon
        }

        var locationAddress: Address? {
            editData.customAddress ?? editData.organization?.address
        }

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.trip.id == rhs.trip.id
                && lhs.activityType == rhs.activityType
                && lhs.existingActivity?.id == rhs.existingActivity?.id
                && lhs.isEditMode == rhs.isEditMode
                && lhs.editData == rhs.editData
                && lhs.attachments == rhs.attachments
                && lhs.isSaving == rhs.isSaving
                && lhs.showingOrganizationPicker == rhs.showingOrganizationPicker
                && lhs.shouldDismiss == rhs.shouldDismiss
                && lhs.saveError?.localizedDescription == rhs.saveError?.localizedDescription
        }
    }

    enum Action: BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case setOrganization(Organization)
        case addAttachment(EmbeddedFileAttachment)
        case removeAttachment(EmbeddedFileAttachment)
        case attachmentError(String)
        case saveTapped
        case saveFinished(Result<Void, Error>)
        case dismissHandled
        case resetForm
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isEditMode else { return .none }
                if let organization = state.editData.organization, organization.name == "None" {
                    return .none
                }
                return .run { send in
                    let noneOrg = await ensureNoneOrganization(in: database)
                    await send(.setOrganization(noneOrg))
                }
            case .binding:
                return .none
            case .setOrganization(let organization):
                state.editData.organization = organization
                return .none
            case .addAttachment(let attachment):
                state.attachments.append(attachment)
                return .none
            case .removeAttachment(let attachment):
                state.attachments.removeAll { $0.id == attachment.id }
                return .run { _ in
                    do {
                        try await database.write { db in
                            try EmbeddedFileAttachment.find(attachment.id).delete().execute(db)
                        }
                    } catch {
                        Logger.shared.error("Failed to remove attachment: \(error.localizedDescription)", category: .fileAttachment)
                    }
                }
            case .attachmentError(let message):
                state.saveError = NSError(domain: "AttachmentError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
                Logger.shared.error("Attachment error: \(message)", category: .fileAttachment)
                return .none
            case .saveTapped:
                guard !state.isSaving, state.isFormValid else { return .none }
                state.isSaving = true
                state.saveError = nil

                let editData = state.editData
                let attachments = state.attachments
                let trip = state.trip
                let activityType = state.activityType
                let existingActivity = state.existingActivity
                let isEditMode = state.isEditMode

                return .run { send in
                    do {
                        if isEditMode {
                            try await updateExistingActivity(
                                existingActivity: existingActivity,
                                editData: editData,
                                attachments: attachments,
                                database: database
                            )
                        } else {
                            let saver = ActivitySaverFactory.createSaver(for: activityType)
                            try saver.save(
                                editData: editData,
                                attachments: attachments,
                                trip: trip,
                                in: database
                            )
                        }
                        await send(.saveFinished(.success(())))
                    } catch {
                        await send(.saveFinished(.failure(error)))
                    }
                }
            case .saveFinished(let result):
                state.isSaving = false
                switch result {
                case .success:
                    state.shouldDismiss = true
                case .failure(let error):
                    state.saveError = error
                }
                return .none
            case .dismissHandled:
                state.shouldDismiss = false
                return .none
            case .resetForm:
                let template = state.activitySaver.createTemplate(in: state.trip)
                state.editData = TripActivityEditData(from: template)
                state.attachments.removeAll()
                state.saveError = nil
                return .run { send in
                    let noneOrg = await ensureNoneOrganization(in: database)
                    await send(.setOrganization(noneOrg))
                }
            }
        }
    }
}

// MARK: - Helpers

private func ensureNoneOrganization(in database: DatabaseWriter) async -> Organization {
    do {
        if let existing = try await database.read({ db in
            try Organization.where { $0.name.eq("None") }.fetchOne(db)
        }) {
            return existing
        }

        let noneOrg = Organization(name: "None")
        try await database.write { db in
            try Organization.insert { noneOrg }.execute(db)
        }
        return noneOrg
    } catch {
        Logger.shared.error("Failed to ensure None organization: \(error.localizedDescription)", category: .database)
        return Organization(name: "None")
    }
}

private func updateExistingActivity(
    existingActivity: (any TripActivityProtocol)?,
    editData: TripActivityEditData,
    attachments: [EmbeddedFileAttachment],
    database: DatabaseWriter
) async throws {
    guard let existingActivity else {
        throw ActivitySaveError.saveFailed(NSError(domain: "UniversalActivityFormFeature", code: 1, userInfo: [NSLocalizedDescriptionKey: "No existing activity to update"]))
    }

    if let customAddress = editData.customAddress {
        try await database.write { db in
            try Address.upsert { customAddress }.execute(db)
        }
    }

    switch existingActivity.activityType {
    case .activity:
        guard var activity = existingActivity as? Activity else { return }
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
        let activityToSave = activity
        let attachmentsToSave = attachments
        try await database.write { db in
            try Activity.upsert { activityToSave }.execute(db)
            try EmbeddedFileAttachment.where { $0.activityID.eq(activityToSave.id) }.delete().execute(db)
            try EmbeddedFileAttachment.insert {
                for attachment in attachmentsToSave {
                    EmbeddedFileAttachment.Draft(
                        id: attachment.id,
                        fileName: attachment.fileName,
                        originalFileName: attachment.originalFileName,
                        fileSize: attachment.fileSize,
                        mimeType: attachment.mimeType,
                        fileExtension: attachment.fileExtension,
                        createdDate: attachment.createdDate,
                        fileDescription: attachment.fileDescription,
                        fileData: attachment.fileData,
                        activityID: activityToSave.id,
                        lodgingID: nil,
                        transportationID: nil
                    )
                }
            }.execute(db)
        }
    case .lodging:
        guard var lodging = existingActivity as? Lodging else { return }
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
        let lodgingToSave = lodging
        let attachmentsToSave = attachments
        try await database.write { db in
            try Lodging.upsert { lodgingToSave }.execute(db)
            try EmbeddedFileAttachment.where { $0.lodgingID.eq(lodgingToSave.id) }.delete().execute(db)
            try EmbeddedFileAttachment.insert {
                for attachment in attachmentsToSave {
                    EmbeddedFileAttachment.Draft(
                        id: attachment.id,
                        fileName: attachment.fileName,
                        originalFileName: attachment.originalFileName,
                        fileSize: attachment.fileSize,
                        mimeType: attachment.mimeType,
                        fileExtension: attachment.fileExtension,
                        createdDate: attachment.createdDate,
                        fileDescription: attachment.fileDescription,
                        fileData: attachment.fileData,
                        activityID: nil,
                        lodgingID: lodgingToSave.id,
                        transportationID: nil
                    )
                }
            }.execute(db)
        }
    case .transportation:
        guard var transportation = existingActivity as? Transportation else { return }
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
        let transportationToSave = transportation
        let attachmentsToSave = attachments
        try await database.write { db in
            try Transportation.upsert { transportationToSave }.execute(db)
            try EmbeddedFileAttachment.where { $0.transportationID.eq(transportationToSave.id) }.delete().execute(db)
            try EmbeddedFileAttachment.insert {
                for attachment in attachmentsToSave {
                    EmbeddedFileAttachment.Draft(
                        id: attachment.id,
                        fileName: attachment.fileName,
                        originalFileName: attachment.originalFileName,
                        fileSize: attachment.fileSize,
                        mimeType: attachment.mimeType,
                        fileExtension: attachment.fileExtension,
                        createdDate: attachment.createdDate,
                        fileDescription: attachment.fileDescription,
                        fileData: attachment.fileData,
                        activityID: nil,
                        lodgingID: nil,
                        transportationID: transportationToSave.id
                    )
                }
            }.execute(db)
        }
    }
}
