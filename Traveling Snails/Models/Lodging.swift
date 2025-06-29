//
//  Lodging.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

@Model
class Lodging: Identifiable {
    var id = UUID()
    var name: String = ""
    var start = Date()
    var checkInTZId: String = ""
    var end = Date()
    var checkOutTZId: String = ""
    var cost: Decimal = 0
    var paid = PaidStatus.none
    var reservation: String = ""
    var notes: String = ""

    var trip: Trip?
    var organization: Organization?

    // Location fields
    var customLocationName: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Address.lodgings)
    var customAddresss: Address?
    var hideLocation: Bool = false

    // CLOUDKIT REQUIRED: Optional file attachments with SAFE accessor
    @Relationship(deleteRule: .cascade, inverse: \EmbeddedFileAttachment.lodging)
    private var _fileAttachments: [EmbeddedFileAttachment]?

    // SAFE ACCESSOR: Never return nil
    var fileAttachments: [EmbeddedFileAttachment] {
        get { _fileAttachments ?? [] }
        set { _fileAttachments = newValue.isEmpty ? nil : newValue }
    }

    init(
        name: String = "",
        start: Date = Date(),
        checkInTZ: TimeZone? = nil,
        end: Date = Date(),
        checkOutTZ: TimeZone? = nil,
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
        self.checkInTZId = checkInTZ?.identifier ?? TimeZone.current.identifier
        self.end = end
        self.checkOutTZId = checkOutTZ?.identifier ?? TimeZone.current.identifier
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

    // MARK: - Computed properties for TripActivityProtocol
    var startTZId: String {
        get { checkInTZId }
        set { checkInTZId = newValue }
    }

    var endTZId: String {
        get { checkOutTZId }
        set { checkOutTZId = newValue }
    }

    var startTZ: TimeZone {
        TimeZone(identifier: checkInTZId) ?? TimeZone.current
    }

    var endTZ: TimeZone {
        TimeZone(identifier: checkOutTZId) ?? TimeZone.current
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

    var hasLocation: Bool {
        customAddresss != nil || (organization?.address?.isEmpty == false)
    }

    var checkInTZ: TimeZone? {
        TimeZone(identifier: checkInTZId) ?? TimeZone.current
    }

    var checkOutTZ: TimeZone? {
        TimeZone(identifier: checkOutTZId) ?? TimeZone.current
    }

    var checkInDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = checkInTZ
        return formatter.string(from: start)
    }

    var checkOutDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = checkOutTZ
        return formatter.string(from: end)
    }

    // File attachment support
    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }
}
