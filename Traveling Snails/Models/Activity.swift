//
//  Activity.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

@Model
class Activity: Identifiable {
    var id = UUID()
    var name: String = ""
    var start = Date()
    var startTZId: String = ""
    var end = Date()
    var endTZId: String = ""
    var cost: Decimal = 0
    var paid = PaidStatus.none
    var reservation: String = ""
    var notes: String = ""

    var trip: Trip?
    var organization: Organization?

    // Location fields
    var customLocationName: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Address.activities)
    var customAddresss: Address?
    var hideLocation: Bool = false

    // CLOUDKIT REQUIRED: Optional file attachments with SAFE accessor
    @Relationship(deleteRule: .cascade, inverse: \EmbeddedFileAttachment.activity)
    private var _fileAttachments: [EmbeddedFileAttachment]?

    // SAFE ACCESSOR: Never return nil
    var fileAttachments: [EmbeddedFileAttachment] {
        get { _fileAttachments ?? [] }
        set { _fileAttachments = newValue.isEmpty ? nil : newValue }
    }

    init(
        name: String = "",
        start: Date = Date(),
        startTZ: TimeZone? = nil,
        end: Date = Date(),
        endTZ: TimeZone? = nil,
        cost: Decimal = 0,
        paid: PaidStatus = PaidStatus.none,
        reservation: String = "",
        notes: String = "",
        trip: Trip? = nil,
        organization: Organization? = nil,
        customLocationName: String = "",
        customAddress: Address? = nil,
        hideLocation: Bool = false
    ) {
        self.name = name
        self.start = start
        self.startTZId = startTZ?.identifier ?? TimeZone.current.identifier
        self.end = end
        self.endTZId = endTZ?.identifier ?? TimeZone.current.identifier
        self.cost = cost
        self.paid = paid
        self.reservation = reservation
        self.notes = notes
        self.trip = trip
        self.organization = organization
        self.customLocationName = customLocationName
        self.customAddresss = customAddress
        self.hideLocation = hideLocation
    }

    // MARK: - Computed properties
    var startTZ: TimeZone {
        TimeZone(identifier: startTZId) ?? TimeZone.current
    }

    var endTZ: TimeZone {
        TimeZone(identifier: endTZId) ?? TimeZone.current
    }

    var startFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = startTZ
        return formatter.string(from: start)
    }

    var endFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = endTZ
        return formatter.string(from: end)
    }

    var displayLocation: String {
        if let org = organization, org.name != "None" {
            return org.name
        } else if !customLocationName.isEmpty {
            return customLocationName
        } else if let customDisplayAddress = customAddresss?.displayAddress {
            return customDisplayAddress
        }

        return "No location specified"
    }

    var displayAddress: Address? {
        if let customAddress = customAddresss {
            return customAddress
        } else if let org = organization, org.name != "None", let orgAddress = org.address, !orgAddress.isEmpty {
            return orgAddress
        }

        return nil
    }

    var hasLocation: Bool { customAddresss != nil || (organization?.address?.isEmpty == false) }

    // File attachment support
    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }
}
