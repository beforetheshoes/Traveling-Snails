//
//  CollectionType.swift
//  Traveling Snails
//

import SQLiteData
import SwiftUI

enum CollectionType: String, Codable, CaseIterable, QueryBindable, Hashable {
    case book
    case movie
    case tvShow
    case podcast
    case game
    case music
    case app

    var displayName: String {
        switch self {
        case .book: return "Books"
        case .movie: return "Movies"
        case .tvShow: return "TV Shows"
        case .podcast: return "Podcasts"
        case .game: return "Video Games"
        case .music: return "Music"
        case .app: return "Apps"
        }
    }

    var singularName: String {
        switch self {
        case .book: return "Book"
        case .movie: return "Movie"
        case .tvShow: return "TV Show"
        case .podcast: return "Podcast"
        case .game: return "Video Game"
        case .music: return "Music"
        case .app: return "App"
        }
    }

    var systemImage: String {
        switch self {
        case .book: return "book"
        case .movie: return "film"
        case .tvShow: return "tv"
        case .podcast: return "mic"
        case .game: return "gamecontroller"
        case .music: return "music.note"
        case .app: return "app"
        }
    }

    var color: Color {
        switch self {
        case .book: return .brown
        case .movie: return .red
        case .tvShow: return .purple
        case .podcast: return .orange
        case .game: return .green
        case .music: return .pink
        case .app: return .blue
        }
    }
}
