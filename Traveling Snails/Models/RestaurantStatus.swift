//
//  RestaurantStatus.swift
//  Traveling Snails
//

import SQLiteData
import SwiftUI

enum RestaurantStatus: String, Codable, CaseIterable, QueryBindable, Hashable {
    case wantToVisit
    case enjoyed
    case favorite
    case didNotEnjoy

    var displayName: String {
        switch self {
        case .wantToVisit: return "Want to Visit"
        case .enjoyed: return "Enjoyed"
        case .favorite: return "Favorite"
        case .didNotEnjoy: return "Did Not Enjoy"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToVisit: return "bookmark"
        case .enjoyed: return "checkmark.circle"
        case .favorite: return "star.fill"
        case .didNotEnjoy: return "hand.thumbsdown"
        }
    }

    var color: Color {
        switch self {
        case .wantToVisit: return .blue
        case .enjoyed: return .green
        case .favorite: return .yellow
        case .didNotEnjoy: return .secondary
        }
    }
}
