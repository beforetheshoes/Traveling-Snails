//
//  Transportation.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct Transportation: Hashable, Identifiable {
    let id: UUID
    var name: String
    var type: TransportationType
    var start: Date
    var startTZId: String
    var end: Date
    var endTZId: String
    @Column(as: DecimalStringRepresentation.self)
    var cost: Decimal
    var paid: PaidStatus
    var confirmation: String
    var notes: String

    var tripID: Trip.ID?
    var organizationID: Organization.ID?

    init(
        id: UUID = UUID(),
        name: String = "",
        type: TransportationType = .plane,
        start: Date = Date(),
        startTZId: String = TimeZone.current.identifier,
        end: Date = Date(),
        endTZId: String = TimeZone.current.identifier,
        cost: Decimal = 0,
        paid: PaidStatus = .none,
        confirmation: String = "",
        notes: String = "",
        tripID: Trip.ID? = nil,
        organizationID: Organization.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.start = start
        self.startTZId = startTZId
        self.end = end
        self.endTZId = endTZId
        self.cost = cost
        self.paid = paid
        self.confirmation = confirmation
        self.notes = notes
        self.tripID = tripID
        self.organizationID = organizationID
    }

    var startTZ: TimeZone { TimeZone(identifier: startTZId) ?? TimeZone.current }
    var endTZ: TimeZone { TimeZone(identifier: endTZId) ?? TimeZone.current }

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

    var departureFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = startTZ
        return formatter.string(from: start)
    }

    var arrivalFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = endTZ
        return formatter.string(from: end)
    }
}

enum TransportationType: String, CaseIterable, Codable, QueryBindable {
    case train
    case plane
    case boat
    case car
    case bicycle
    case walking

    var displayName: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .train: return "train.side.front.car"
        case .plane: return "airplane"
        case .boat: return "ferry"
        case .car: return "car"
        case .bicycle: return "bicycle"
        case .walking: return "figure.walk"
        }
    }
}
