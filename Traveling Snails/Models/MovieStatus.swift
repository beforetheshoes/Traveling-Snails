//
//  MovieStatus.swift
//  Traveling Snails
//

import SQLiteData
import SwiftUI

enum MovieStatus: String, Codable, CaseIterable, QueryBindable, Hashable {
    case wantToWatch
    case watching
    case watched
    case abandoned

    var displayName: String {
        switch self {
        case .wantToWatch: return "Want to Watch"
        case .watching: return "Watching"
        case .watched: return "Watched"
        case .abandoned: return "Abandoned"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToWatch: return "bookmark"
        case .watching: return "play.circle"
        case .watched: return "checkmark.circle"
        case .abandoned: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .wantToWatch: return .blue
        case .watching: return .orange
        case .watched: return .green
        case .abandoned: return .secondary
        }
    }
}
