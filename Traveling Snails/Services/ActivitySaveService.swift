//
//  ActivitySaveService.swift
//  Traveling Snails
//
//

import Foundation
import SQLiteData

// MARK: - Type-Erased Save Protocol

protocol ActivitySaver: Sendable {
    func save(
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        trip: Trip,
        in database: DatabaseWriter
    ) throws

    func createTemplate(in trip: Trip) -> any TripActivityProtocol
    var activityType: ActivityType { get }
    var icon: String { get }
    var color: String { get }
    var startLabel: String { get }
    var endLabel: String { get }
    var confirmationLabel: String { get }
    var supportsCustomLocation: Bool { get }
    var hasTypeSelector: Bool { get }
}

// MARK: - Activity Type Enum

enum ActivityType: String, CaseIterable, Sendable {
    case activity = "Activity"
    case lodging = "Lodging"
    case transportation = "Transportation"

    var displayName: String { rawValue }
}

// MARK: - Concrete Activity Savers

struct ActivitySaverImpl: ActivitySaver {
    let activityType = ActivityType.activity
    let icon = "ticket.fill"
    let color = "purple"
    let startLabel = "Start"
    let endLabel = "End"
    let confirmationLabel = "Reservation"
    let supportsCustomLocation = true
    let hasTypeSelector = false

    func createTemplate(in trip: Trip) -> any TripActivityProtocol {
        let defaultStart = trip.effectiveStartDate ?? Date()
        let defaultEnd = defaultStart.addingTimeInterval(2 * 3600) // 2 hours

        return Activity(
            name: "",
            start: defaultStart,
            end: defaultEnd,
            trip: nil,
            organization: nil
        )
    }

    func save(
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        trip: Trip,
        in database: DatabaseWriter
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = try ensureNoneOrganization(in: database)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        var activity = Activity(
            name: editData.name,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: finalOrg,
            customLocationName: editData.customLocationName,
            customAddress: editData.customAddress,
            hideLocation: editData.hideLocation
        )

        try database.write { db in
            if let customAddress = editData.customAddress, !customAddress.isEmpty {
                try Address.upsert { customAddress }.execute(db)
                activity.addressID = customAddress.id
            }

            activity.tripID = trip.id
            activity.organizationID = finalOrg.id
            try Activity.upsert { activity }.execute(db)

            try EmbeddedFileAttachment.insert {
                for attachment in attachments {
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
                        activityID: activity.id,
                        lodgingID: nil,
                        transportationID: nil
                    )
                }
            }.execute(db)
        }

        // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
    }
}

struct LodgingSaverImpl: ActivitySaver {
    let activityType = ActivityType.lodging
    let icon = "bed.double.fill"
    let color = "indigo"
    let startLabel = "Check-in"
    let endLabel = "Check-out"
    let confirmationLabel = "Reservation"
    let supportsCustomLocation = true
    let hasTypeSelector = false

    func createTemplate(in trip: Trip) -> any TripActivityProtocol {
        let defaultStart = trip.effectiveStartDate ?? Date()
        let defaultEnd = Calendar.current.date(byAdding: .day, value: 1, to: defaultStart) ?? defaultStart.addingTimeInterval(24 * 3600)

        return Lodging(
            name: "",
            start: defaultStart,
            end: defaultEnd,
            cost: 0,
            paid: PaidStatus.none,
            trip: nil,
            organization: nil
        )
    }

    func save(
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        trip: Trip,
        in database: DatabaseWriter
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = try ensureNoneOrganization(in: database)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        var lodging = Lodging(
            name: editData.name,
            start: editData.start,
            checkInTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            checkOutTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: finalOrg,
            customLocationName: editData.customLocationName,
            customAddress: editData.customAddress,
            hideLocation: editData.hideLocation
        )

        try database.write { db in
            if let customAddress = editData.customAddress, !customAddress.isEmpty {
                try Address.upsert { customAddress }.execute(db)
                lodging.addressID = customAddress.id
            }

            lodging.tripID = trip.id
            lodging.organizationID = finalOrg.id
            try Lodging.upsert { lodging }.execute(db)

            try EmbeddedFileAttachment.insert {
                for attachment in attachments {
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
                        lodgingID: lodging.id,
                        transportationID: nil
                    )
                }
            }.execute(db)
        }

        // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
    }
}

struct TransportationSaverImpl: ActivitySaver {
    let activityType = ActivityType.transportation
    let icon = "airplane"
    let color = "blue"
    let startLabel = "Departure"
    let endLabel = "Arrival"
    let confirmationLabel = "Confirmation"
    let supportsCustomLocation = false
    let hasTypeSelector = true

    func createTemplate(in trip: Trip) -> any TripActivityProtocol {
        let defaultStart = trip.effectiveStartDate ?? Date()
        let defaultEnd = defaultStart.addingTimeInterval(2 * 3600) // 2 hours

        return Transportation(
            name: "",
            start: defaultStart,
            end: defaultEnd,
            trip: nil,
            organization: nil
        )
    }

    func save(
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        trip: Trip,
        in database: DatabaseWriter
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = try ensureNoneOrganization(in: database)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        var transportation = Transportation(
            name: editData.name,
            type: editData.transportationType ?? .plane,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            confirmation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: finalOrg
        )

        try database.write { db in
            transportation.tripID = trip.id
            transportation.organizationID = finalOrg.id
            try Transportation.upsert { transportation }.execute(db)

            try EmbeddedFileAttachment.insert {
                for attachment in attachments {
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
                        transportationID: transportation.id
                    )
                }
            }.execute(db)
        }

        // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
    }
}

private func ensureNoneOrganization(in database: DatabaseWriter) throws -> Organization {
    if let existing = try database.read({ db in
        try Organization.where { $0.name.eq("None") }.fetchOne(db)
    }) {
        return existing
    }
    let noneOrg = Organization(name: "None")
    try database.write { db in
        try Organization.insert { noneOrg }.execute(db)
    }
    return noneOrg
}

// MARK: - Factory

struct ActivitySaverFactory {
    static func createSaver(for activityType: ActivityType) -> ActivitySaver {
        switch activityType {
        case .activity:
            return ActivitySaverImpl()
        case .lodging:
            return LodgingSaverImpl()
        case .transportation:
            return TransportationSaverImpl()
        }
    }
}

// MARK: - Error Types

enum ActivitySaveError: Error, LocalizedError {
    case missingOrganization
    case unsupportedActivityType
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingOrganization:
            return "Organization is required"
        case .unsupportedActivityType:
            return "Unsupported activity type"
        case .saveFailed(let error):
            Logger.shared.error("Activity save failed: \(error.localizedDescription)", category: .database)
            return L(L10n.Save.activityFailed)
        }
    }
}
