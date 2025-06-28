//
//  ModernBiometricAuthManager.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI
import Observation

/// Modern BiometricAuthManager using dependency injection
/// Replaces the singleton-based BiometricAuthManager for better testability
@MainActor
@Observable
class ModernBiometricAuthManager {
    
    // MARK: - Properties
    
    private let authService: AuthenticationService
    
    // MARK: - Initialization
    
    /// Initialize with injected authentication service
    /// - Parameter authService: The authentication service to use
    init(authService: AuthenticationService) {
        self.authService = authService
    }
    
    // MARK: - Public API (Mirrors BiometricAuthManager for compatibility)
    
    /// Whether biometric authentication is available and enabled
    var isEnabled: Bool {
        return authService.isEnabled
    }
    
    /// The type of biometric authentication available
    var biometricType: BiometricType {
        return authService.biometricType
    }
    
    /// Check if the device can use biometric authentication
    func canUseBiometrics() -> Bool {
        return authService.canUseBiometrics()
    }
    
    /// Authenticate a user for a specific trip
    /// - Parameter trip: The trip to authenticate for
    /// - Returns: True if authentication succeeded, false otherwise
    func authenticateTrip(_ trip: Trip) async -> Bool {
        return await authService.authenticateTrip(trip)
    }
    
    /// Check if a trip is currently authenticated
    /// - Parameter trip: The trip to check
    /// - Returns: True if the trip is authenticated
    func isAuthenticated(for trip: Trip) -> Bool {
        return authService.isAuthenticated(for: trip)
    }
    
    /// Check if a trip is protected (requires authentication)
    /// - Parameter trip: The trip to check
    /// - Returns: True if the trip requires authentication
    func isProtected(_ trip: Trip) -> Bool {
        return authService.isProtected(trip)
    }
    
    /// Lock a specific trip (remove authentication)
    /// - Parameter trip: The trip to lock
    func lockTrip(_ trip: Trip) {
        authService.lockTrip(trip)
    }
    
    /// Toggle protection status for a trip
    /// - Parameter trip: The trip to toggle protection for
    func toggleProtection(for trip: Trip) {
        authService.toggleProtection(for: trip)
    }
    
    /// Lock all authenticated trips
    func lockAllTrips() {
        authService.lockAllTrips()
    }
    
    /// Reset the authentication session
    func resetSession() {
        authService.resetSession()
    }
    
    /// Whether all trips are currently locked
    var allTripsLocked: Bool {
        return authService.allTripsLocked
    }
}

// MARK: - Convenience Factory Methods

extension ModernBiometricAuthManager {
    
    /// Create a BiometricAuthManager with production authentication service
    /// - Returns: Configured manager with production service
    static func production() -> ModernBiometricAuthManager {
        return ModernBiometricAuthManager(authService: ProductionAuthenticationService())
    }
    
    /// Create a BiometricAuthManager from a service container
    /// - Parameter container: The service container to resolve from
    /// - Returns: Configured manager with service from container
    static func from(container: ServiceContainer) -> ModernBiometricAuthManager {
        let authService = container.resolve(AuthenticationService.self)
        return ModernBiometricAuthManager(authService: authService)
    }
}