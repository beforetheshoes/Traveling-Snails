//
//  NavigationConfiguration.swift
//  Traveling Snails
//

import Foundation

/**
 * Configuration for EntityNavigationView appearance and behavior
 *
 * This struct contains all the customizable aspects of the navigation view,
 * including titles, empty states, and UI preferences.
 *
 * ## Usage:
 * ```swift
 * let config = NavigationConfiguration<Trip>(
 *     title: "Trips",
 *     emptyStateTitle: "No Trips",
 *     emptyStateIcon: "airplane",
 *     searchPlaceholder: "Search trips..."
 * )
 * ```
 */
struct NavigationConfiguration<Item: NavigationItem> {
    let title: String
    let emptyStateTitle: String
    let emptyStateIcon: String
    let emptyStateDescription: String
    let addButtonTitle: String
    let addButtonIcon: String
    let searchPlaceholder: String
    let allowsSearch: Bool
    let allowsSelection: Bool

    init(
        title: String,
        emptyStateTitle: String = "No Items",
        emptyStateIcon: String = "tray",
        emptyStateDescription: String = "No items found",
        addButtonTitle: String = "Add Item",
        addButtonIcon: String = "plus",
        searchPlaceholder: String = "Search...",
        allowsSearch: Bool = true,
        allowsSelection: Bool = true
    ) {
        self.title = title
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateIcon = emptyStateIcon
        self.emptyStateDescription = emptyStateDescription
        self.addButtonTitle = addButtonTitle
        self.addButtonIcon = addButtonIcon
        self.searchPlaceholder = searchPlaceholder
        self.allowsSearch = allowsSearch
        self.allowsSelection = allowsSelection
    }
}