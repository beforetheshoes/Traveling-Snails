//
//  PaidStatus.swift
//  Traveling Snails
//
//

import Foundation
import SQLiteData

enum PaidStatus: String, CaseIterable, Codable, QueryBindable {
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
