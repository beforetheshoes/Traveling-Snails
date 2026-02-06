//
//  Lodging.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct Lodging: Hashable, Identifiable {
    let id: UUID
    var name: String
    var start: Date
    var checkInTZId: String
    var end: Date
    var checkOutTZId: String
    @Column(as: DecimalStringRepresentation.self)
    var cost: Decimal
    var paid: PaidStatus
    var reservation: String
    var notes: String

    var tripID: Trip.ID?
    var organizationID: Organization.ID?
    var addressID: Address.ID?

    var customLocationName: String
    var hideLocation: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        start: Date = Date(),
        checkInTZId: String = TimeZone.current.identifier,
        end: Date = Date(),
        checkOutTZId: String = TimeZone.current.identifier,
        cost: Decimal = 0,
        paid: PaidStatus = .none,
        reservation: String = "",
        notes: String = "",
        tripID: Trip.ID? = nil,
        organizationID: Organization.ID? = nil,
        addressID: Address.ID? = nil,
        customLocationName: String = "",
        hideLocation: Bool = false
    ) {
        self.id = id
        self.name = name
        self.start = start
        self.checkInTZId = checkInTZId
        self.end = end
        self.checkOutTZId = checkOutTZId
        self.cost = cost
        self.paid = paid
        self.reservation = reservation
        self.notes = notes
        self.tripID = tripID
        self.organizationID = organizationID
        self.addressID = addressID
        self.customLocationName = customLocationName
        self.hideLocation = hideLocation
    }

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

    var checkInDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = startTZ
        return formatter.string(from: start)
    }

    var checkOutDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = endTZ
        return formatter.string(from: end)
    }
}
