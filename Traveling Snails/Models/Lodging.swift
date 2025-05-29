//
//  Lodging.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

@Model
class Lodging: Identifiable, TripActivity {
    var id = UUID()
    var name: String
    var start: Date
    var checkInTZId: String = ""
    var end: Date
    var checkOutTZId: String = ""
    var cost: Decimal = 0
    var paid = PaidStatus.none
    var reservation: String = ""
    var notes: String = ""
    
    var trip: Trip
    var organization: Organization
    
    init(
        name: String,
        start: Date,
        checkInTZ: TimeZone? = nil,
        end: Date,
        checkOutTZ: TimeZone? = nil,
        cost: Decimal?,
        paid: PaidStatus?,
        reservation: String = "",
        notes: String = "",
        trip: Trip,
        organization: Organization
    ) {
        self.name = name
        self.start = start
        self.checkInTZId = checkInTZ?.identifier ?? TimeZone.current.identifier
        self.end = end
        self.checkOutTZId = checkOutTZ?.identifier ?? TimeZone.current.identifier
        self.cost = cost ?? 0
        self.paid = paid ??  PaidStatus.none
        self.reservation = reservation
        self.notes = notes
        self.trip = trip
        self.organization = organization
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
}
