//
//  PaidStatus.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import Foundation

enum PaidStatus: String, CaseIterable, Codable {
    case infull
    case deposit
    case none
    
    var displayName: String {
        switch self {
        case .infull:
            return "In Full"
        case .deposit:
            return "Deposit"
        case .none:
            return "None"
        }
    }
}

