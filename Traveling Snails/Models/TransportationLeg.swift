//
//  TransportationLeg.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

enum CabinClass: String, CaseIterable, Codable, QueryBindable {
    case unknown
    case economy
    case premiumEconomy
    case business
    case first

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .economy: return "Economy"
        case .premiumEconomy: return "Premium Economy"
        case .business: return "Business"
        case .first: return "First"
        }
    }
}

enum SeatType: String, CaseIterable, Codable, QueryBindable {
    case unknown
    case window
    case aisle
    case middle
    case other

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .window: return "Window"
        case .aisle: return "Aisle"
        case .middle: return "Middle"
        case .other: return "Other"
        }
    }
}

@Table
nonisolated struct TransportationLeg: Hashable, Identifiable {
    let id: UUID

    var transportationID: Transportation.ID
    var sortIndex: Int
    var type: TransportationType

    // Departure
    var departure: Date
    var departureTZId: String
    var departureLocationName: String
    var departureAddressID: Address.ID?
    var departureGateOrPlatform: String
    var departureTerminal: String

    // Arrival
    var arrival: Date
    var arrivalTZId: String
    var arrivalLocationName: String
    var arrivalAddressID: Address.ID?
    var arrivalGateOrPlatform: String
    var arrivalTerminal: String

    // Service + seat
    var serviceNumber: String
    var confirmation: String
    var seatNumber: String
    var cabinClass: CabinClass
    var seatType: SeatType
    var boardingGroup: String

    var notes: String

    init(
        id: UUID = UUID(),
        transportationID: Transportation.ID,
        sortIndex: Int = 0,
        type: TransportationType = .plane,
        departure: Date = Date(),
        departureTZId: String = TimeZone.current.identifier,
        departureLocationName: String = "",
        departureAddressID: Address.ID? = nil,
        departureGateOrPlatform: String = "",
        departureTerminal: String = "",
        arrival: Date = Date(),
        arrivalTZId: String = TimeZone.current.identifier,
        arrivalLocationName: String = "",
        arrivalAddressID: Address.ID? = nil,
        arrivalGateOrPlatform: String = "",
        arrivalTerminal: String = "",
        serviceNumber: String = "",
        confirmation: String = "",
        seatNumber: String = "",
        cabinClass: CabinClass = .unknown,
        seatType: SeatType = .unknown,
        boardingGroup: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.transportationID = transportationID
        self.sortIndex = sortIndex
        self.type = type
        self.departure = departure
        self.departureTZId = departureTZId
        self.departureLocationName = departureLocationName
        self.departureAddressID = departureAddressID
        self.departureGateOrPlatform = departureGateOrPlatform
        self.departureTerminal = departureTerminal
        self.arrival = arrival
        self.arrivalTZId = arrivalTZId
        self.arrivalLocationName = arrivalLocationName
        self.arrivalAddressID = arrivalAddressID
        self.arrivalGateOrPlatform = arrivalGateOrPlatform
        self.arrivalTerminal = arrivalTerminal
        self.serviceNumber = serviceNumber
        self.confirmation = confirmation
        self.seatNumber = seatNumber
        self.cabinClass = cabinClass
        self.seatType = seatType
        self.boardingGroup = boardingGroup
        self.notes = notes
    }

    var departureTZ: TimeZone { TimeZone(identifier: departureTZId) ?? .current }
    var arrivalTZ: TimeZone { TimeZone(identifier: arrivalTZId) ?? .current }

    static func makeDefaultLeg(for transportation: Transportation) -> TransportationLeg {
        TransportationLeg(
            transportationID: transportation.id,
            sortIndex: 0,
            type: transportation.type,
            departure: transportation.start,
            departureTZId: transportation.startTZId,
            arrival: transportation.end,
            arrivalTZId: transportation.endTZId
        )
    }
}

