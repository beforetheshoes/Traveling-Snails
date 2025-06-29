//
//  NavigationContext.swift
//  Traveling Snails
//
//

import SwiftUI

// Environment key for tracking navigation context
struct NavigationContextKey: EnvironmentKey {
    static let defaultValue = NavigationContext.shared
}

extension EnvironmentValues {
    var navigationContext: NavigationContext {
        get { self[NavigationContextKey.self] }
        set { self[NavigationContextKey.self] = newValue }
    }
}

// Navigation context to track tab switches and restoration needs
@Observable
class NavigationContext {
    static let shared = NavigationContext()

    private(set) var lastTabSwitchTime: Date?
    private(set) var shouldRestoreNavigation = false
    private(set) var lastTabSwitchToTrips: Date?

    private init() {}

    func markTabSwitch(to newTab: Int, from oldTab: Int) {
        lastTabSwitchTime = Date()

        // Only mark for restoration when switching TO the trips tab (tab 0)
        if newTab == 0 && oldTab != 0 {
            shouldRestoreNavigation = true
            lastTabSwitchToTrips = Date()
        } else if newTab != 0 {
            // Clear restoration flag when leaving trips tab
            shouldRestoreNavigation = false
        }
    }

    func markNavigationRestored() {
        shouldRestoreNavigation = false
    }

    func isRecentTabSwitch(within seconds: TimeInterval = 1.0) -> Bool {
        guard let lastSwitch = lastTabSwitchToTrips else {
            return false
        }
        let timeSince = Date().timeIntervalSince(lastSwitch)
        return timeSince < seconds
    }
}
