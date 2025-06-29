//
//  ActivitySaveService.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData

// MARK: - Type-Erased Save Protocol

protocol ActivitySaver: Sendable {
    func save(
        editData: TripActivityEditData,
        attachments: [EmbeddedFileAttachment],
        trip: Trip,
        in modelContext: ModelContext
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
        in modelContext: ModelContext
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = Organization.ensureUniqueNoneOrganization(in: modelContext)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        let activity = Activity(
            name: editData.name,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            customLocationName: editData.customLocationName,
            customAddress: editData.customAddress,
            hideLocation: editData.hideLocation
        )

        modelContext.insert(activity)

        if let customAddress = editData.customAddress {
            modelContext.insert(customAddress)
        }

        activity.trip = trip
        activity.organization = finalOrg

        for attachment in attachments {
            modelContext.insert(attachment)
            attachment.activity = activity
        }

        try modelContext.save()

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
        in modelContext: ModelContext
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = Organization.ensureUniqueNoneOrganization(in: modelContext)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        let lodging = Lodging(
            name: editData.name,
            start: editData.start,
            checkInTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            checkOutTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            customLocationName: editData.customLocationName,
            customAddress: editData.customAddress,
            hideLocation: editData.hideLocation
        )

        modelContext.insert(lodging)

        if let customAddress = editData.customAddress {
            modelContext.insert(customAddress)
        }

        lodging.trip = trip
        lodging.organization = finalOrg

        for attachment in attachments {
            modelContext.insert(attachment)
            attachment.lodging = lodging
        }

        try modelContext.save()

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
        in modelContext: ModelContext
    ) throws {
        guard let organization = editData.organization else {
            throw ActivitySaveError.missingOrganization
        }

        let noneOrg = Organization.ensureUniqueNoneOrganization(in: modelContext)
        let finalOrg = organization.name == "None" ? noneOrg : organization

        let transportation = Transportation(
            name: editData.name,
            type: editData.transportationType ?? .plane,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            confirmation: editData.confirmationField,
            notes: editData.notes
        )

        modelContext.insert(transportation)

        transportation.trip = trip
        transportation.organization = finalOrg

        for attachment in attachments {
            modelContext.insert(attachment)
            attachment.transportation = transportation
        }

        try modelContext.save()

        // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
    }
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
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}
