//
//  SQLiteRelations.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

// MARK: - Trip Relationships

extension Trip {
    var lodging: [Lodging] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Lodging.where { $0.tripID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var transportation: [Transportation] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Transportation.where { $0.tripID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var activity: [Activity] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Activity.where { $0.tripID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var totalCost: Decimal {
        let lodgingCost = lodging.reduce(Decimal(0)) { $0 + $1.cost }
        let transportationCost = transportation.reduce(Decimal(0)) { $0 + $1.cost }
        let activityCost = activity.reduce(Decimal(0)) { $0 + $1.cost }
        return lodgingCost + transportationCost + activityCost
    }

    var totalActivities: Int {
        lodging.count + transportation.count + activity.count
    }

    var actualDateRange: ClosedRange<Date>? {
        let starts = lodging.map(\.start) + transportation.map(\.start) + activity.map(\.start)
        let ends = lodging.map(\.end) + transportation.map(\.end) + activity.map(\.end)
        guard let minStart = starts.min(), let maxEnd = ends.max() else { return nil }
        return minStart...maxEnd
    }

    func optimizedCheckDateConflicts(
        hasStartDate: Bool,
        startDate: Date,
        hasEndDate: Bool,
        endDate: Date
    ) -> String? {
        guard hasStartDate || hasEndDate else { return nil }
        guard let actualRange = actualDateRange else { return nil }

        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))?
            .addingTimeInterval(-1) ?? endDate

        var messages: [String] = []
        if hasStartDate && actualRange.lowerBound < normalizedStart {
            messages.append("Some activities start before the new trip start date.")
        }
        if hasEndDate && actualRange.upperBound > normalizedEnd {
            messages.append("Some activities end after the new trip end date.")
        }

        guard !messages.isEmpty else { return nil }
        let suffix = " Saving will not modify existing activity dates."
        if messages.count == 2 {
            return "Some activities fall outside the new date range." + suffix
        }
        return messages[0] + suffix
    }
}

// MARK: - Organization Relationships

extension Organization {
    var address: Address? {
        get {
            guard let addressID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Address.find(addressID).fetchOne(db)
            }
        }
        set { addressID = newValue?.id }
    }

    var transportation: [Transportation] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Transportation.where { $0.organizationID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var lodging: [Lodging] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Lodging.where { $0.organizationID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var activity: [Activity] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Activity.where { $0.organizationID.eq(id) }.fetchAll(db)
        }) ?? []
    }
}

// MARK: - Address Relationships

extension Address {
    var activities: [Activity] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Activity.where { $0.addressID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var lodgings: [Lodging] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Lodging.where { $0.addressID.eq(id) }.fetchAll(db)
        }) ?? []
    }

    var organizations: [Organization] {
        guard let database = DatabaseAccess.database else { return [] }
        return (try? database.read { db in
            try Organization.where { $0.addressID.eq(id) }.fetchAll(db)
        }) ?? []
    }
}

// MARK: - Activity File Attachments & Display

extension Activity {
    var fileAttachments: [EmbeddedFileAttachment] {
        get {
            guard let database = DatabaseAccess.database else { return [] }
            return (try? database.read { db in
                try EmbeddedFileAttachment.where { $0.activityID.eq(id) }.fetchAll(db)
            }) ?? []
        }
        set {
            guard let database = DatabaseAccess.database else { return }
            try? database.write { db in
                try EmbeddedFileAttachment.where { $0.activityID.eq(id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in newValue {
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
                            activityID: id,
                            lodgingID: nil,
                            transportationID: nil
                        )
                    }
                }.execute(db)
            }
        }
    }

    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }

    var displayLocation: String {
        if let org = organization, !org.isNone {
            return org.name
        } else if !customLocationName.isEmpty {
            return customLocationName
        } else if let customDisplayAddress = customAddress?.displayAddress {
            return customDisplayAddress
        }

        return "No location specified"
    }

    var displayAddress: Address? {
        if let customAddress {
            return customAddress
        } else if let org = organization, !org.isNone, let orgAddress = org.address, !orgAddress.isEmpty {
            return orgAddress
        }

        return nil
    }

    var hasLocation: Bool { customAddress != nil || (organization?.address?.isEmpty == false) }
}

// MARK: - Lodging File Attachments & Display

extension Lodging {
    var fileAttachments: [EmbeddedFileAttachment] {
        get {
            guard let database = DatabaseAccess.database else { return [] }
            return (try? database.read { db in
                try EmbeddedFileAttachment.where { $0.lodgingID.eq(id) }.fetchAll(db)
            }) ?? []
        }
        set {
            guard let database = DatabaseAccess.database else { return }
            try? database.write { db in
                try EmbeddedFileAttachment.where { $0.lodgingID.eq(id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in newValue {
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
                            lodgingID: id,
                            transportationID: nil
                        )
                    }
                }.execute(db)
            }
        }
    }

    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }

    var displayLocation: String {
        if let org = organization, !org.isNone {
            return org.name
        } else if !customLocationName.isEmpty {
            return customLocationName
        } else if let customDisplayAddress = customAddress?.displayAddress {
            return customDisplayAddress
        }

        return "No location specified"
    }

    var displayAddress: Address? {
        if let customAddress {
            return customAddress
        } else if let org = organization, !org.isNone, let orgAddress = org.address, !orgAddress.isEmpty {
            return orgAddress
        }

        return nil
    }

    var hasLocation: Bool { customAddress != nil || (organization?.address?.isEmpty == false) }
}

// MARK: - Transportation File Attachments

extension Transportation {
    var fileAttachments: [EmbeddedFileAttachment] {
        get {
            guard let database = DatabaseAccess.database else { return [] }
            return (try? database.read { db in
                try EmbeddedFileAttachment.where { $0.transportationID.eq(id) }.fetchAll(db)
            }) ?? []
        }
        set {
            guard let database = DatabaseAccess.database else { return }
            try? database.write { db in
                try EmbeddedFileAttachment.where { $0.transportationID.eq(id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in newValue {
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
                            transportationID: id
                        )
                    }
                }.execute(db)
            }
        }
    }

    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }
}

// MARK: - EmbeddedFileAttachment Parent Accessors

extension EmbeddedFileAttachment {
    var activity: Activity? {
        get {
            guard let activityID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Activity.find(activityID).fetchOne(db)
            }
        }
        set { activityID = newValue?.id }
    }

    var lodging: Lodging? {
        get {
            guard let lodgingID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Lodging.find(lodgingID).fetchOne(db)
            }
        }
        set { lodgingID = newValue?.id }
    }

    var transportation: Transportation? {
        get {
            guard let transportationID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Transportation.find(transportationID).fetchOne(db)
            }
        }
        set { transportationID = newValue?.id }
    }
}
