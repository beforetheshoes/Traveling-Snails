//
//  TripActivityFormFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct TripActivityFormFeature {
    @ObservableState
    struct State: Equatable {
        let trip: Trip
        let activityType: ActivityType
        var existingActivity: (any TripActivityProtocol)?
        var isEditMode: Bool

        var editData: TripActivityEditData
        var attachments: [EmbeddedFileAttachment]
        var isSaving = false
        @Presents var organizationPicker: OrganizationPickerFeature.State?
        var saveError: Error?
        var shouldDismiss = false

        // Transportation legs (multi-leg itinerary)
        var transportationID: Transportation.ID?
        var transportationLegs: [TransportationLeg] = []
        var legsValidationError: String?
        var showingLegsEditor = false

        init(trip: Trip, activityType: ActivityType) {
            self.trip = trip
            self.activityType = activityType
            self.existingActivity = nil
            self.isEditMode = false

            let saver = ActivitySaverFactory.createSaver(for: activityType)
            let template = saver.createTemplate(in: trip)
            self.editData = TripActivityEditData(from: template)
            self.attachments = []

            if activityType == .transportation {
                let id = Transportation.ID()
                self.transportationID = id
                self.transportationLegs = [
                    TransportationLeg(
                        transportationID: id,
                        sortIndex: 0,
                        type: self.editData.transportationType ?? .plane,
                        departure: self.editData.start,
                        departureTZId: self.editData.startTZId,
                        arrival: self.editData.end,
                        arrivalTZId: self.editData.endTZId
                    )
                ]
                self.legsValidationError = nil
                applyDerivedTransportationFields()
            }
        }

        init<T: TripActivityProtocol>(existingActivity: T) {
            self.trip = existingActivity.trip ?? Trip(name: "")
            self.activityType = ActivityType(rawValue: existingActivity.activityType.rawValue) ?? .activity
            self.existingActivity = existingActivity
            self.isEditMode = true
            self.editData = TripActivityEditData(from: existingActivity)
            self.attachments = existingActivity.fileAttachments

            if let transportation = existingActivity as? Transportation {
                self.transportationID = transportation.id
            } else {
                self.transportationID = nil
            }
        }

        var activitySaver: ActivitySaver {
            ActivitySaverFactory.createSaver(for: activityType)
        }

        var isFormValid: Bool {
            guard editData.organization != nil, !editData.name.isEmpty else { return false }
            if activityType == .transportation {
                return !transportationLegs.isEmpty && legsValidationError == nil
            }
            return true
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
            if lhs.trip.id != rhs.trip.id { return false }
            if lhs.activityType != rhs.activityType { return false }
            if lhs.existingActivity?.id != rhs.existingActivity?.id { return false }
            if lhs.isEditMode != rhs.isEditMode { return false }
            if lhs.editData != rhs.editData { return false }
            if lhs.attachments != rhs.attachments { return false }
            if lhs.isSaving != rhs.isSaving { return false }
            if lhs.organizationPicker != rhs.organizationPicker { return false }
            if lhs.shouldDismiss != rhs.shouldDismiss { return false }
            if lhs.transportationID != rhs.transportationID { return false }
            if lhs.transportationLegs != rhs.transportationLegs { return false }
            if lhs.legsValidationError != rhs.legsValidationError { return false }
            if lhs.showingLegsEditor != rhs.showingLegsEditor { return false }
            if lhs.saveError?.localizedDescription != rhs.saveError?.localizedDescription { return false }
            return true
        }

        mutating func applyDerivedTransportationFields() {
            guard activityType == .transportation else { return }
            guard let first = transportationLegs.sorted(by: { $0.sortIndex < $1.sortIndex }).first,
                  let last = transportationLegs.sorted(by: { $0.sortIndex < $1.sortIndex }).last
            else { return }

            editData.start = first.departure
            editData.startTZId = first.departureTZId
            editData.end = last.arrival
            editData.endTZId = last.arrivalTZId
            editData.transportationType = first.type
        }
    }

    enum Action: BindableAction {
        case onAppear
        case binding(BindingAction<State>)
        case setOrganization(Organization)
        case showOrganizationPicker
        case organizationPicker(PresentationAction<OrganizationPickerFeature.Action>)
        case addAttachment(EmbeddedFileAttachment)
        case removeAttachment(EmbeddedFileAttachment)
        case attachmentError(String)
        case loadTransportationLegs
        case transportationLegsLoaded([TransportationLeg])
        case addLegTapped
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
                if state.activityType == .transportation, state.isEditMode {
                    return .send(.loadTransportationLegs)
                }

                guard !state.isEditMode else { return .none }
                if let organization = state.editData.organization, organization.name == "None" {
                    return .none
                }
                return .run { send in
                    let noneOrg = await ensureNoneOrganization(in: database)
                    await send(.setOrganization(noneOrg))
                }
            case .binding:
                state.applyDerivedTransportationFields()
                state.legsValidationError = validateTransportationLegs(state.transportationLegs)
                return .none
            case .showOrganizationPicker:
                state.organizationPicker = OrganizationPickerFeature.State(
                    selectedOrganizationID: state.editData.organization?.id
                )
                return .none
            case .organizationPicker(.presented(.organizationTapped)):
                // Parent dismisses picker; selected org is communicated via binding
                return .none
            case .organizationPicker(.dismiss):
                state.organizationPicker = nil
                return .none
            case .organizationPicker:
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

            case .loadTransportationLegs:
                guard state.activityType == .transportation,
                      let transportationID = state.transportationID
                else { return .none }
                // Only load from DB in edit mode. New items initialize legs in init.
                guard state.isEditMode else {
                    state.legsValidationError = validateTransportationLegs(state.transportationLegs)
                    state.applyDerivedTransportationFields()
                    return .none
                }
                return .run { send in
                    do {
                        let legs = try await database.read { db in
                            try TransportationLeg.where { $0.transportationID.eq(transportationID) }
                                .order { $0.sortIndex.asc() }
                                .fetchAll(db)
                        }
                        await send(.transportationLegsLoaded(legs))
                    } catch {
                        Logger.shared.error("Failed to load transportation legs: \(error.localizedDescription)", category: .database)
                        await send(.transportationLegsLoaded([]))
                    }
                }

            case .transportationLegsLoaded(let legs):
                guard state.activityType == .transportation else { return .none }
                if legs.isEmpty, let transportationID = state.transportationID {
                    // Older DB entry (or corrupted) without legs: synthesize 1 leg from top-level times.
                    state.transportationLegs = [
                        TransportationLeg(
                            transportationID: transportationID,
                            sortIndex: 0,
                            type: state.editData.transportationType ?? .plane,
                            departure: state.editData.start,
                            departureTZId: state.editData.startTZId,
                            arrival: state.editData.end,
                            arrivalTZId: state.editData.endTZId
                        )
                    ]
                } else {
                    state.transportationLegs = normalizeLegs(legs)
                }
                state.legsValidationError = validateTransportationLegs(state.transportationLegs)
                state.applyDerivedTransportationFields()
                return .none

            case .addLegTapped:
                guard state.activityType == .transportation,
                      let transportationID = state.transportationID
                else { return .none }
                let last = state.transportationLegs.sorted(by: { $0.sortIndex < $1.sortIndex }).last
                let departure = last?.arrival ?? state.editData.end
                let tzId = last?.arrivalTZId ?? state.editData.endTZId
                let newLeg = TransportationLeg(
                    transportationID: transportationID,
                    sortIndex: state.transportationLegs.count,
                    type: last?.type ?? (state.editData.transportationType ?? .plane),
                    departure: departure,
                    departureTZId: tzId,
                    arrival: departure.addingTimeInterval(2 * 3600),
                    arrivalTZId: tzId
                )
                state.transportationLegs.append(newLeg)
                state.transportationLegs = normalizeLegs(state.transportationLegs)
                state.legsValidationError = validateTransportationLegs(state.transportationLegs)
                state.applyDerivedTransportationFields()
                return .none

            case .saveTapped:
                guard !state.isSaving, state.isFormValid else { return .none }
                state.isSaving = true
                state.saveError = nil

                let editData = state.editData
                let attachments = state.attachments
                let trip = state.trip
                let activityType = state.activityType
                let existingActivity = ExistingActivityData(state.existingActivity)
                let isEditMode = state.isEditMode
                let legs = state.transportationLegs
                let transportationID = state.transportationID

                return .run { send in
                    do {
                        if isEditMode {
                            try await updateExistingActivity(
                                existingActivity: existingActivity,
                                editData: editData,
                                attachments: attachments,
                                transportationLegs: legs,
                                database: database
                            )
                        } else {
                            if activityType == .transportation, let transportationID {
                                try await createTransportationWithLegs(
                                    transportationID: transportationID,
                                    editData: editData,
                                    legs: legs,
                                    attachments: attachments,
                                    trip: trip,
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
                if state.activityType == .transportation {
                    let id = Transportation.ID()
                    state.transportationID = id
                    state.transportationLegs = [
                        TransportationLeg(
                            transportationID: id,
                            sortIndex: 0,
                            type: state.editData.transportationType ?? .plane,
                            departure: state.editData.start,
                            departureTZId: state.editData.startTZId,
                            arrival: state.editData.end,
                            arrivalTZId: state.editData.endTZId
                        )
                    ]
                    state.legsValidationError = validateTransportationLegs(state.transportationLegs)
                    state.applyDerivedTransportationFields()
                }
                return .run { send in
                    let noneOrg = await ensureNoneOrganization(in: database)
                    await send(.setOrganization(noneOrg))
                }
            }
        }
        .ifLet(\.$organizationPicker, action: \.organizationPicker) {
            OrganizationPickerFeature()
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
    existingActivity: ExistingActivityData?,
    editData: TripActivityEditData,
    attachments: [EmbeddedFileAttachment],
    transportationLegs: [TransportationLeg],
    database: DatabaseWriter
) async throws {
    guard let existingActivity else {
        throw ActivitySaveError.saveFailed(NSError(domain: "TripActivityFormFeature", code: 1, userInfo: [NSLocalizedDescriptionKey: "No existing activity to update"]))
    }

    if let customAddress = editData.customAddress {
        try await database.write { db in
            try Address.upsert { customAddress }.execute(db)
        }
    }

    switch existingActivity {
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
    case .transportation(var transportation):
        let legs = normalizeLegs(transportationLegs)
        guard validateTransportationLegs(legs) == nil else {
            throw ActivitySaveError.saveFailed(
                NSError(domain: "TripActivityFormFeature", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid transportation leg times"])
            )
        }
        if let first = legs.first, let last = legs.last {
            transportation.start = first.departure
            transportation.startTZId = first.departureTZId
            transportation.end = last.arrival
            transportation.endTZId = last.arrivalTZId
            transportation.type = first.type
        }
        transportation.name = editData.name
        transportation.cost = editData.cost
        transportation.paid = editData.paid
        transportation.confirmation = editData.confirmationField
        transportation.notes = editData.notes
        transportation.organizationID = editData.organization?.id
        let transportationToSave = transportation
        let attachmentsToSave = attachments
        try await database.write { db in
            try Transportation.upsert { transportationToSave }.execute(db)
            try TransportationLeg.where { $0.transportationID.eq(transportationToSave.id) }.delete().execute(db)
            if !legs.isEmpty {
                let legsToSave = legs.enumerated().map { index, leg -> TransportationLeg in
                    var legToSave = leg
                    legToSave.transportationID = transportationToSave.id
                    legToSave.sortIndex = index
                    if legToSave.departureTZId.isEmpty { legToSave.departureTZId = TimeZone.current.identifier }
                    if legToSave.arrivalTZId.isEmpty { legToSave.arrivalTZId = TimeZone.current.identifier }
                    return legToSave
                }
                try TransportationLeg.insert {
                    for leg in legsToSave { leg }
                }.execute(db)
            }
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

private enum ExistingActivityData {
    case activity(Activity)
    case lodging(Lodging)
    case transportation(Transportation)

    init?(_ activity: (any TripActivityProtocol)?) {
        switch activity {
        case let value as Activity:
            self = .activity(value)
        case let value as Lodging:
            self = .lodging(value)
        case let value as Transportation:
            self = .transportation(value)
        default:
            return nil
        }
    }
}

private func normalizeLegs(_ legs: [TransportationLeg]) -> [TransportationLeg] {
    legs.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated().map { index, leg in
        var updated = leg
        updated.sortIndex = index
        return updated
    }
}

private func validateTransportationLegs(_ legs: [TransportationLeg]) -> String? {
    guard !legs.isEmpty else { return "At least one leg is required." }

    let sorted = legs.sorted(by: { $0.sortIndex < $1.sortIndex })
    for (index, leg) in sorted.enumerated() {
        if leg.arrival < leg.departure {
            return "Leg \(index + 1): arrival must be after departure."
        }
        if index > 0 {
            let prev = sorted[index - 1]
            if leg.departure < prev.arrival {
                return "Leg \(index + 1): departure must be after previous arrival."
            }
        }
    }
    return nil
}

private func createTransportationWithLegs(
    transportationID: Transportation.ID,
    editData: TripActivityEditData,
    legs: [TransportationLeg],
    attachments: [EmbeddedFileAttachment],
    trip: Trip,
    database: DatabaseWriter
) async throws {
    guard let organization = editData.organization else {
        throw ActivitySaveError.missingOrganization
    }

    let noneOrg = await ensureNoneOrganization(in: database)
    let finalOrg = organization.name == "None" ? noneOrg : organization

    let normalizedLegs = normalizeLegs(legs)
    guard validateTransportationLegs(normalizedLegs) == nil else {
        throw ActivitySaveError.saveFailed(
            NSError(domain: "TripActivityFormFeature", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid transportation leg times"])
        )
    }

    let first = normalizedLegs.first!
    let last = normalizedLegs.last!

    let transportationToSave = Transportation(
        id: transportationID,
        name: editData.name,
        type: first.type,
        start: first.departure,
        startTZId: first.departureTZId,
        end: last.arrival,
        endTZId: last.arrivalTZId,
        cost: editData.cost,
        paid: editData.paid,
        confirmation: editData.confirmationField,
        notes: editData.notes,
        tripID: trip.id,
        organizationID: finalOrg.id
    )

    let attachmentsToSave = attachments
    let legsToSave = normalizedLegs.enumerated().map { index, leg -> TransportationLeg in
        var legToSave = leg
        legToSave.transportationID = transportationToSave.id
        legToSave.sortIndex = index
        if legToSave.departureTZId.isEmpty { legToSave.departureTZId = TimeZone.current.identifier }
        if legToSave.arrivalTZId.isEmpty { legToSave.arrivalTZId = TimeZone.current.identifier }
        return legToSave
    }

    try await database.write { db in
        try Transportation.upsert { transportationToSave }.execute(db)

        try TransportationLeg.where { $0.transportationID.eq(transportationToSave.id) }.delete().execute(db)
        try TransportationLeg.insert {
            for leg in legsToSave { leg }
        }.execute(db)

        try EmbeddedFileAttachment.where { $0.transportationID.eq(transportationToSave.id) }.delete().execute(db)
        if !attachmentsToSave.isEmpty {
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
