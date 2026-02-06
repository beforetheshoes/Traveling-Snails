//
//  NavigationItem.swift
//  Traveling Snails
//

import SwiftUI
import Foundation

/**
 * Protocol for items that can be displayed in navigation lists
 *
 * Provides a consistent interface for displaying items in navigation views
 * with standard properties for display name, subtitle, icon, and badge.
 *
 * ## Usage:
 * ```swift
 * extension MyModel: NavigationItem {
 *     var id: UUID { modelID }
 *     var displayName: String { name }
 *     var displaySubtitle: String? { subtitle }
 *     var displayIcon: String { "star" }
 *     var displayColor: Color { .blue }
 *     var displayBadgeCount: Int? { nil }
 * }
 * ```
 */
protocol NavigationItem: Identifiable, Hashable {
    /// Unique identifier for the navigation item
    var id: UUID { get }
    /// Primary display name shown in navigation lists
    var displayName: String { get }
    /// Optional subtitle shown below the primary name
    var displaySubtitle: String? { get }
    /// SF Symbol icon name for the item
    var displayIcon: String { get }
    /// Color theme for the item's icon and selection state
    var displayColor: Color { get }
    /// Optional badge count displayed on the item
    var displayBadgeCount: Int? { get }
}