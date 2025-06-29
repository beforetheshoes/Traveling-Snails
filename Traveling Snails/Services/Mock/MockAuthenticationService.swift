//
//  MockAuthenticationService.swift
//  Traveling Snails
//
//

import Foundation
import os.lock
import SwiftUI

/// Mock implementation of AuthenticationService for testing
/// Provides controllable biometric authentication behavior without LAContext
final class MockAuthenticationService: AuthenticationService, Sendable {
    // MARK: - Thread-Safe Storage
    private let lock = OSAllocatedUnfairLock()

    // MARK: - Mock Configuration (Thread-Safe)
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var _mockIsEnabled: Bool = true
    nonisolated(unsafe) private var _mockBiometricType: BiometricType = .faceID
    nonisolated(unsafe) private var _mockCanUseBiometrics: Bool = true
    nonisolated(unsafe) private var _mockAuthenticationResult: Bool = true
    nonisolated(unsafe) private var _mockAuthenticationDelay: TimeInterval = 0.0
    nonisolated(unsafe) private var _authenticationCallCount: Int = 0
    nonisolated(unsafe) private var _authenticatedTripIDs: Set<UUID> = [] // Start empty so allTripsLocked = true
    nonisolated(unsafe) private var _protectedTripIDs: Set<UUID> = []

    // MARK: - Initialization

    init() {
        // Mock service starts in a clean state
    }

    // MARK: - Thread-Safe Configuration Accessors

    var mockIsEnabled: Bool {
        get { lock.withLock { _mockIsEnabled } }
        set { lock.withLock { _mockIsEnabled = newValue } }
    }

    var mockBiometricType: BiometricType {
        get { lock.withLock { _mockBiometricType } }
        set { lock.withLock { _mockBiometricType = newValue } }
    }

    var mockCanUseBiometrics: Bool {
        get { lock.withLock { _mockCanUseBiometrics } }
        set { lock.withLock { _mockCanUseBiometrics = newValue } }
    }

    var mockAuthenticationResult: Bool {
        get { lock.withLock { _mockAuthenticationResult } }
        set { lock.withLock { _mockAuthenticationResult = newValue } }
    }

    var mockAuthenticationDelay: TimeInterval {
        get { lock.withLock { _mockAuthenticationDelay } }
        set { lock.withLock { _mockAuthenticationDelay = newValue } }
    }

    var authenticationCallCount: Int {
        lock.withLock { _authenticationCallCount }
    }

    // MARK: - AuthenticationService Implementation

    var isEnabled: Bool {
        lock.withLock { _mockIsEnabled }
    }

    var biometricType: BiometricType {
        lock.withLock { _mockBiometricType }
    }

    func canUseBiometrics() -> Bool {
        lock.withLock { _mockCanUseBiometrics }
    }

    func authenticateTrip(_ trip: Trip) async -> Bool {
        let tripId = trip.id
        let tripIsProtected = trip.isProtected

        // Increment call count for verification
        lock.withLock { _authenticationCallCount += 1 }

        // Get delay value under lock
        let delay = lock.withLock { _mockAuthenticationDelay }

        // Simulate authentication delay
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Check authentication logic under lock
        let shouldAuthenticate = lock.withLock { _mockIsEnabled && tripIsProtected }
        guard shouldAuthenticate else {
            return true
        }

        // Check if already authenticated
        let alreadyAuthenticated = lock.withLock { _authenticatedTripIDs.contains(tripId) }

        if alreadyAuthenticated {
            return true
        }

        // Return configured mock result
        let result = lock.withLock { _mockAuthenticationResult }
        if result {
            _ = lock.withLock { _authenticatedTripIDs.insert(tripId) }
        }

        return result
    }

    func isAuthenticated(for trip: Trip) -> Bool {
        let isProtectedTrip = isProtected(trip)
        let tripId = trip.id
        let isInAuthenticatedSet = lock.withLock { _authenticatedTripIDs.contains(tripId) }
        return !isProtectedTrip || isInAuthenticatedSet
    }

    func isProtected(_ trip: Trip) -> Bool {
        let enabled = lock.withLock { _mockIsEnabled }
        return enabled && trip.isProtected
    }

    func lockTrip(_ trip: Trip) {
        let tripId = trip.id
        _ = lock.withLock { _authenticatedTripIDs.remove(tripId) }
    }

    func toggleProtection(for trip: Trip) {
        trip.isProtected.toggle()

        // If removing protection, also remove from authenticated trips
        if !trip.isProtected {
            let tripId = trip.id
            _ = lock.withLock { _authenticatedTripIDs.remove(tripId) }
        }
    }

    func lockAllTrips() {
        lock.withLock { _authenticatedTripIDs.removeAll() }
    }

    func resetSession() {
        lock.withLock { _authenticatedTripIDs.removeAll() }
    }

    var allTripsLocked: Bool {
        // All trips are locked only when explicitly cleared (e.g., via lockAllTrips)
        lock.withLock { _authenticatedTripIDs.isEmpty }
    }

    // MARK: - Mock Control Methods

    /// Configure mock to simulate successful authentication
    func configureSuccessfulAuthentication() {
        lock.withLock {
            _mockIsEnabled = true
            _mockCanUseBiometrics = true
            _mockAuthenticationResult = true
            _mockBiometricType = .faceID
            _authenticatedTripIDs = [UUID()] // Add dummy ID to unlock
        }
    }

    /// Configure mock to simulate failed authentication
    func configureFailedAuthentication() {
        lock.withLock {
            _mockIsEnabled = true
            _mockCanUseBiometrics = true
            _mockAuthenticationResult = false
            _mockBiometricType = .faceID
            _authenticatedTripIDs.removeAll() // Clear authenticated trips for failed auth
        }
    }

    /// Configure mock to simulate no biometric capability
    func configureNoBiometrics() {
        lock.withLock {
            _mockIsEnabled = false
            _mockCanUseBiometrics = false
            _mockBiometricType = .none
            _authenticatedTripIDs.removeAll() // Clear authenticated trips when no biometrics
        }
    }

    /// Configure mock to simulate TouchID instead of FaceID
    func configureTouchID() {
        lock.withLock {
            _mockIsEnabled = true
            _mockCanUseBiometrics = true
            _mockBiometricType = .touchID
        }
    }

    /// Reset mock to clean state for next test
    func resetForTesting() {
        lock.withLock {
            _mockIsEnabled = true
            _mockCanUseBiometrics = true
            _mockAuthenticationResult = true
            _mockBiometricType = .faceID
            _mockAuthenticationDelay = 0.1
            _authenticationCallCount = 0
            _authenticatedTripIDs.removeAll() // Reset to locked state
            _protectedTripIDs.removeAll()
        }
    }

    /// Manually mark a trip as authenticated (for test setup)
    func markTripAsAuthenticated(_ trip: Trip) {
        let tripId = trip.id
        _ = lock.withLock { _authenticatedTripIDs.insert(tripId) }
    }

    /// Check if a specific trip was authenticated (for test verification)
    func wasAuthenticated(_ trip: Trip) -> Bool {
        let tripId = trip.id
        return lock.withLock { _authenticatedTripIDs.contains(tripId) }
    }
}

// MARK: - Test Helper Extensions

extension MockAuthenticationService {
    /// Create a pre-configured mock for successful authentication scenarios
    static func successfulAuth() -> MockAuthenticationService {
        let mock = MockAuthenticationService()
        mock.configureSuccessfulAuthentication()
        return mock
    }

    /// Create a pre-configured mock for failed authentication scenarios
    static func failedAuth() -> MockAuthenticationService {
        let mock = MockAuthenticationService()
        mock.configureFailedAuthentication()
        return mock
    }

    /// Create a pre-configured mock for no biometrics scenarios
    static func noBiometrics() -> MockAuthenticationService {
        let mock = MockAuthenticationService()
        mock.configureNoBiometrics()
        return mock
    }
}
