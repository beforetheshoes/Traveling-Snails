//
//  TripActivityProtocol.swift
//  Traveling Snails
//
//

import SwiftUI

protocol TripActivityProtocol: Identifiable {
    var id: UUID { get }
    var name: String { get set }
    var start: Date { get set }
    var end: Date { get set }
    var cost: Decimal { get set }
    var paid: PaidStatus { get set }
    var notes: String { get set }
    var tripID: Trip.ID? { get set }
    var organizationID: Organization.ID? { get set }
    var trip: Trip? { get set }
    var organization: Organization? { get set }

    // Type-specific fields
    var confirmationField: String { get set }
    var confirmationLabel: String { get }

    // Timezone handling
    var startTZId: String { get set }
    var endTZId: String { get set }
    var startTZ: TimeZone { get }
    var endTZ: TimeZone { get }
    var startFormatted: String { get }
    var endFormatted: String { get }

    // Location handling
    var supportsCustomLocation: Bool { get }
    var customLocationName: String { get set }
    var addressID: Address.ID? { get set }
    var customAddress: Address? { get set }
    var hideLocation: Bool { get set }
    var displayLocation: String { get }
    var displayAddress: Address? { get }
    var hasLocation: Bool { get }

    // File attachment support
    var supportsFileAttachments: Bool { get }
    var hasAttachments: Bool { get }
    var attachmentCount: Int { get }
    var fileAttachments: [EmbeddedFileAttachment] { get set }

    // UI Configuration
    var activityType: ActivityWrapper.ActivityType { get }
    var icon: String { get }
    var color: Color { get }
    var scheduleTitle: String { get }
    var startLabel: String { get }
    var endLabel: String { get }
    var hasTypeSelector: Bool { get }
    var transportationType: TransportationType? { get set }

    // Actions
    func duration() -> TimeInterval
    func copyForEditing() -> TripActivityEditData
    mutating func applyEdits(from data: TripActivityEditData)
}

extension TripActivityProtocol {
    var trip: Trip? {
        get {
            guard let tripID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Trip.find(tripID).fetchOne(db)
            }
        }
        set { tripID = newValue?.id }
    }

    var organization: Organization? {
        get {
            guard let organizationID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Organization.find(organizationID).fetchOne(db)
            }
        }
        set { organizationID = newValue?.id }
    }

    var customAddress: Address? {
        get {
            guard let addressID, let database = DatabaseAccess.database else { return nil }
            return try? database.read { db in
                try Address.find(addressID).fetchOne(db)
            }
        }
        set { addressID = newValue?.id }
    }
}
