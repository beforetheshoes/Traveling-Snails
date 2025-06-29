//
//  Transportation.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

@Model
class Transportation: Identifiable {
    var id = UUID()
    var name: String = ""
    var type = TransportationType.plane
    var start = Date()
    var startTZId: String = ""
    var end = Date()
    var endTZId: String = ""
    var cost: Decimal = 0
    var paid = PaidStatus.none
    var confirmation: String = ""
    var notes: String = ""

    var trip: Trip?
    var organization: Organization?

    // CLOUDKIT REQUIRED: Optional file attachments with SAFE accessor
    @Relationship(deleteRule: .cascade, inverse: \EmbeddedFileAttachment.transportation)
    private var _fileAttachments: [EmbeddedFileAttachment]?

    // SAFE ACCESSOR: Never return nil
    var fileAttachments: [EmbeddedFileAttachment] {
        get { _fileAttachments ?? [] }
        set { _fileAttachments = newValue.isEmpty ? nil : newValue }
    }

    init(
        name: String = "",
        type: TransportationType = TransportationType.plane,
        start: Date = Date(),
        startTZ: TimeZone? = nil,
        end: Date = Date(),
        endTZ: TimeZone? = nil,
        cost: Decimal = 0,
        paid: PaidStatus = PaidStatus.none,
        confirmation: String = "",
        notes: String = "",
        trip: Trip? = nil,
        organization: Organization? = nil
    ) {
        self.name = name
        self.type = type
        self.start = start
        self.startTZId = startTZ?.identifier ?? TimeZone.current.identifier
        self.end = end
        self.endTZId = endTZ?.identifier ?? TimeZone.current.identifier
        self.cost = cost
        self.paid = paid
        self.confirmation = confirmation
        self.notes = notes
        self.trip = trip
        self.organization = organization
    }

    // MARK: - Computed Properties
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

    // File attachment support
    var hasAttachments: Bool { !fileAttachments.isEmpty }
    var attachmentCount: Int { fileAttachments.count }
}

enum TransportationType: String, CaseIterable, Codable {
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
