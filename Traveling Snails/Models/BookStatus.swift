//
//  BookStatus.swift
//  Traveling Snails
//

import SQLiteData
import SwiftUI

enum BookStatus: String, Codable, CaseIterable, QueryBindable, Hashable {
    case wantToRead
    case reading
    case read
    case abandoned

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .reading: return "Reading"
        case .read: return "Read"
        case .abandoned: return "Abandoned"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .reading: return "book.pages"
        case .read: return "checkmark.circle"
        case .abandoned: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .wantToRead: return .blue
        case .reading: return .orange
        case .read: return .green
        case .abandoned: return .secondary
        }
    }
}
