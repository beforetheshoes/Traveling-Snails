//
//  Trip.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import Foundation
import SwiftData

@Model
class Trip: Identifiable {
    var id = UUID()
    var name: String
    var notes: String = ""
    var createdDate: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \Lodging.trip) var lodging: [Lodging] = []
    @Relationship(deleteRule: .cascade, inverse: \Transportation.trip) var transportation: [Transportation] = []
    
    init(name: String, notes: String = "") {
        self.name = name
        self.notes = notes
        self.createdDate = Date()
    }
    
    var totalActivities: Int {
        lodging.count + transportation.count
    }
    
    var totalCost: Decimal {
        let lodgingCost = lodging.reduce(Decimal(0)) { $0 + $1.cost }
        let transportationCost = transportation.reduce(Decimal(0)) { $0 + $1.cost }
        return lodgingCost + transportationCost
    }
}
