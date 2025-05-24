//
//  Item.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
