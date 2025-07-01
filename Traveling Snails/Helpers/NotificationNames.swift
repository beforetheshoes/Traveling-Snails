//
//  NotificationNames.swift
//  Traveling Snails
//
//

import Foundation

// MARK: - Notification Names
extension Notification.Name {
    // DEPRECATED: Use NavigationRouter.selectTrip() instead
    static let tripSelectedFromList = Notification.Name("tripSelectedFromList")

    // NOTE: Still used by some views during migration to environment-based navigation
    static let clearTripSelection = Notification.Name("clearTripSelection")
    static let navigateToTrip = Notification.Name("navigateToTrip")
}
