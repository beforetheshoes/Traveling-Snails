//
//  EnvironmentBasedNavigationTests.swift
//  Traveling Snails Tests
//
//

import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("Environment-Based Navigation Tests")
@MainActor
struct EnvironmentBasedNavigationTests {
    
    @Test("NavigationRouter should handle trip selection via environment instead of notifications")
    func testEnvironmentBasedTripSelection() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        container.mainContext.insert(trip)
        try container.mainContext.save()
        
        let router = NavigationRouter.shared
        
        // Test: NavigationRouter should have selectTrip method that doesn't use notifications
        router.selectTrip(trip.id)
        
        // Test: NavigationRouter should track selected trip ID
        #expect(router.selectedTripId == trip.id)
        
        // Test: NavigationRouter should notify observers through @Observable pattern
        #expect(router.shouldClearNavigationPath == true)
    }
    
    @Test("NavigationRouter should clear trip selection via environment")
    func testEnvironmentBasedTripClearing() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        container.mainContext.insert(trip)
        try container.mainContext.save()
        
        let router = NavigationRouter.shared
        
        // Setup: Select a trip first
        router.selectTrip(trip.id)
        #expect(router.selectedTripId == trip.id)
        
        // Test: Clear trip selection should work without notifications
        router.clearTripSelection()
        #expect(router.selectedTripId == nil)
        #expect(router.shouldClearNavigationPath == true)
    }
    
    @Test("NavigationRouter should handle multiple observers without notification center")
    func testMultipleEnvironmentObservers() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        container.mainContext.insert(trip)
        try container.mainContext.save()
        
        let router = NavigationRouter.shared
        
        // Test: Router should support multiple observers through @Observable
        actor ObserverState {
            var observer1Triggered = false
            var observer2Triggered = false
            
            func setObserver1Triggered() {
                observer1Triggered = true
            }
            
            func setObserver2Triggered() {
                observer2Triggered = true
            }
        }
        
        let observerState = ObserverState()
        
        // Simulate multiple views observing the same router
        let _ = withObservationTracking {
            _ = router.selectedTripId
        } onChange: {
            Task { await observerState.setObserver1Triggered() }
        }
        
        let _ = withObservationTracking {
            _ = router.selectedTripId
        } onChange: {
            Task { await observerState.setObserver2Triggered() }
        }
        
        router.selectTrip(trip.id)
        
        // Small delay to allow async observer updates
        try await Task.sleep(for: .milliseconds(10))
        
        // Both observers should be notified
        #expect(await observerState.observer1Triggered == true)
        #expect(await observerState.observer2Triggered == true)
    }
    
    @Test("NavigationRouter should provide navigation path coordination")
    func testNavigationPathCoordination() async throws {
        let router = NavigationRouter.shared
        
        // Test: Router should coordinate navigation path clearing
        router.requestNavigationPathClear()
        #expect(router.shouldClearNavigationPath == true)
        
        // Test: Router should allow acknowledging navigation path clear
        router.acknowledgeNavigationPathClear()
        #expect(router.shouldClearNavigationPath == false)
    }
    
    @Test("NavigationRouter should maintain compatibility with existing navigation actions")
    func testBackwardCompatibilityWithNavigationActions() async throws {
        let router = NavigationRouter.shared
        
        // Test: Existing navigation actions should still work
        router.navigate(NavigationRouter.NavigationAction.navigateToTripList)
        #expect(router.selectedTripId == nil)
        
        router.navigate(NavigationRouter.NavigationAction.clearTripSelection)
        #expect(router.selectedTripId == nil)
        #expect(router.shouldClearNavigationPath == true)
    }
    
    @Test("Environment-based navigation should not use NotificationCenter")
    func testNoNotificationCenterUsage() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, configurations: config)
        
        let trip = Trip(name: "Test Trip")
        container.mainContext.insert(trip)
        try container.mainContext.save()
        
        let router = NavigationRouter.shared
        
        // Track notification center usage
        var notificationPosted = false
        let observer = NotificationCenter.default.addObserver(
            forName: .tripSelectedFromList,
            object: nil,
            queue: .main
        ) { _ in
            notificationPosted = true
        }
        
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Test: New trip selection should not post notifications
        router.selectTrip(trip.id)
        
        // Small delay to ensure notification would have been posted if it was going to be
        try await Task.sleep(for: .milliseconds(10))
        
        #expect(notificationPosted == false)
    }
}