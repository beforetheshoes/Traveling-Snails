//
//  NavigationRouter.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI

/// Centralized navigation router following environment-based pattern
@Observable
class NavigationRouter {
    static let shared = NavigationRouter()

    // Navigation actions that can be triggered from anywhere in the app
    enum NavigationAction {
        case navigateToTripList
        case navigateToTrip(UUID)
        case clearTripSelection
    }

    private init() {}

    /// Execute a navigation action
    /// This will be called by views that need to trigger navigation
    func navigate(_ action: NavigationAction) {
        Logger.shared.debug("Executing navigation action: \(action)", category: .navigation)

        switch action {
        case .navigateToTripList:
            // Clear any selected trip to return to list
            NotificationCenter.default.post(name: .clearTripSelection, object: nil)
            Logger.shared.debug("Posted clearTripSelection notification to return to trip list", category: .navigation)

        case .navigateToTrip(let tripId):
            // Navigate to specific trip
            NotificationCenter.default.post(name: .navigateToTrip, object: tripId)
            Logger.shared.debug("Posted navigateToTrip notification for trip: \(tripId)", category: .navigation)

        case .clearTripSelection:
            // Clear current trip selection
            NotificationCenter.default.post(name: .clearTripSelection, object: nil)
            Logger.shared.debug("Posted clearTripSelection notification", category: .navigation)
        }
    }
}

// Environment key for NavigationRouter
struct NavigationRouterKey: EnvironmentKey {
    static let defaultValue = NavigationRouter.shared
}

extension EnvironmentValues {
    var navigationRouter: NavigationRouter {
        get { self[NavigationRouterKey.self] }
        set { self[NavigationRouterKey.self] = newValue }
    }
}
