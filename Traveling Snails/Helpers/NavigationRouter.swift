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

    // Environment-based navigation state
    private(set) var selectedTripId: UUID?
    private(set) var shouldClearNavigationPath = false

    private init() {}

    /// Execute a navigation action
    /// This will be called by views that need to trigger navigation
    func navigate(_ action: NavigationAction) {
        Logger.shared.debug("Executing navigation action: \(action)", category: .navigation)

        switch action {
        case .navigateToTripList:
            // Clear any selected trip to return to list
            clearTripSelection()
            
            // Backward compatibility: still post notification for views not yet migrated
            NotificationCenter.default.post(name: .clearTripSelection, object: nil)
            Logger.shared.debug("Posted clearTripSelection notification to return to trip list", category: .navigation)

        case .navigateToTrip(let tripId):
            // Navigate to specific trip via environment
            selectTrip(tripId)
            
            // Backward compatibility: still post notification for views not yet migrated
            NotificationCenter.default.post(name: .navigateToTrip, object: tripId)
            Logger.shared.debug("Posted navigateToTrip notification for trip: \(tripId)", category: .navigation)

        case .clearTripSelection:
            // Clear current trip selection
            clearTripSelection()
            
            // Backward compatibility: still post notification for views not yet migrated
            NotificationCenter.default.post(name: .clearTripSelection, object: nil)
            Logger.shared.debug("Posted clearTripSelection notification", category: .navigation)
        }
    }
    
    // MARK: - Environment-Based Navigation Methods
    
    /// Select a trip using environment-based pattern instead of notifications
    func selectTrip(_ tripId: UUID) {
        Logger.shared.debug("Environment-based trip selection: \(tripId)", category: .navigation)
        selectedTripId = tripId
        shouldClearNavigationPath = true
    }
    
    /// Clear trip selection using environment-based pattern
    func clearTripSelection() {
        Logger.shared.debug("Environment-based trip selection cleared", category: .navigation)
        selectedTripId = nil
        shouldClearNavigationPath = true
    }
    
    /// Request navigation path to be cleared (used by views to coordinate navigation)
    func requestNavigationPathClear() {
        Logger.shared.debug("Navigation path clear requested", category: .navigation)
        shouldClearNavigationPath = true
    }
    
    /// Acknowledge that navigation path has been cleared (called by views after clearing)
    func acknowledgeNavigationPathClear() {
        Logger.shared.debug("Navigation path clear acknowledged", category: .navigation)
        shouldClearNavigationPath = false
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
