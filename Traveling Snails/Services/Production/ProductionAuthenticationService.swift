//
//  ProductionAuthenticationService.swift
//  Traveling Snails
//
//

import Foundation
import LocalAuthentication
import os.lock
import SwiftUI

/// Production implementation of AuthenticationService using LocalAuthentication framework
final class ProductionAuthenticationService: AuthenticationService, Sendable {
    // MARK: - Properties

    /// Thread-safe storage
    private let lock = OSAllocatedUnfairLock()

    /// Simple session tracking - which trips are authenticated this session
    /// nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var authenticatedTripIDs: Set<UUID> = []

    /// Notification handlers for state changes
    nonisolated(unsafe) private var stateChangeHandlers: [(UUID) -> Void] = []

    // MARK: - AuthenticationService Implementation

    var isEnabled: Bool {
        canUseBiometrics()
    }

    var biometricType: BiometricType {
        // Skip LAContext during tests to prevent hanging
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            return .none
        }
        #endif

        #if targetEnvironment(simulator)
        return .none
        #else
        let context = LAContext()
        context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
        #endif
    }

    func canUseBiometrics() -> Bool {
        // Skip LAContext during tests to prevent hanging
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            return false
        }
        #endif

        #if targetEnvironment(simulator)
        return false
        #else
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        #endif
    }

    nonisolated func authenticateTrip(_ trip: Trip) async -> Bool {
        // Capture only the values we need to avoid Sendable issues
        let tripId = trip.id
        let tripName = trip.name
        let tripIsProtected = trip.isProtected

        Logger.shared.debug("ProductionAuthenticationService.authenticateTrip(\(tripName)) - START")

        // Skip authentication during tests to prevent hanging
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            Logger.shared.debug("Test environment detected, skipping biometric authentication")
            _ = lock.withLock { authenticatedTripIDs.insert(tripId) }
            return true
        }
        #endif

        // Check if trip is protected on main actor
        let effectivelyProtected = await MainActor.run {
            self.isEnabled && tripIsProtected
        }

        // If trip is not protected, always return true
        guard effectivelyProtected else {
            Logger.shared.debug("Trip not protected, returning true")
            return true
        }

        // Check if already authenticated
        let alreadyAuthenticated = lock.withLock {
            authenticatedTripIDs.contains(tripId)
        }

        if alreadyAuthenticated {
            Logger.shared.debug("Trip already authenticated, returning true")
            return true
        }

        // Handle simulator differently to prevent hanging
        #if targetEnvironment(simulator)
        Logger.shared.debug("Simulator detected, simulating successful authentication")
        _ = lock.withLock { authenticatedTripIDs.insert(tripId) }
        return true
        #else

        // Perform biometric authentication with fresh context
        let context = LAContext()

        // Check if biometrics are available before attempting authentication
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                Logger.shared.debug("Biometrics not available: \(error.localizedDescription)")
            } else {
                Logger.shared.debug("Biometrics not available, returning false")
            }
            return false
        }

        Logger.shared.debug("Starting biometric authentication with timeout protection...")

        // Add timeout protection to prevent indefinite hanging
        let timeoutSeconds: UInt64 = 30 // 30 second timeout

        return await withTaskGroup(of: Bool.self) { group in
            // Authentication task
            group.addTask {
                do {
                    let result = try await context.evaluatePolicy(
                        .deviceOwnerAuthentication,
                        localizedReason: "Authenticate to access protected content"
                    )

                    Logger.shared.debug("Biometric authentication result: \(result)")

                    if result {
                        _ = self.lock.withLock { self.authenticatedTripIDs.insert(tripId) }
                        Logger.shared.debug("Added trip \(tripId) to authenticated set")
                        return true
                    }
                    Logger.shared.debug("Authentication failed, returning false")
                    return false
                } catch {
                    Logger.shared.debug("Authentication error: \(error)")
                    if let laError = error as? LAError {
                        Logger.shared.debug("LAError code: \(laError.code.rawValue)")
                        switch laError.code {
                        case .biometryNotAvailable:
                            Logger.shared.debug("Biometry not available on this device")
                        case .biometryNotEnrolled:
                            Logger.shared.debug("User has not enrolled biometrics")
                        case .biometryLockout:
                            Logger.shared.debug("Biometry is locked out")
                        case .userCancel:
                            Logger.shared.debug("User cancelled authentication")
                        case .userFallback:
                            Logger.shared.debug("User chose fallback method")
                        case .appCancel:
                            Logger.shared.debug("App cancelled authentication")
                        case .invalidContext:
                            Logger.shared.debug("Invalid context")
                        case .notInteractive:
                            Logger.shared.debug("Not interactive")
                        default:
                            Logger.shared.debug("Other LAError: \(laError.localizedDescription)")
                        }
                    }
                    return false
                }
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                Logger.shared.debug("Authentication timed out after \(timeoutSeconds) seconds")
                return false
            }

            // Return the first completed result
            guard let result = await group.next() else {
                return false
            }
            group.cancelAll()
            return result
        }
        #endif
    }

    func isAuthenticated(for trip: Trip) -> Bool {
        let isProtectedTrip = isProtected(trip)
        let tripId = trip.id
        let isInAuthenticatedSet = lock.withLock { authenticatedTripIDs.contains(tripId) }
        let result = !isProtectedTrip || isInAuthenticatedSet

        return result
    }

    func isProtected(_ trip: Trip) -> Bool {
        let result = isEnabled && trip.isProtected
        return result
    }

    func lockTrip(_ trip: Trip) {
        Logger.shared.debug("ProductionAuthenticationService.lockTrip(\(trip.name))")
        let tripId = trip.id
        _ = lock.withLock { authenticatedTripIDs.remove(tripId) }
    }

    func toggleProtection(for trip: Trip) {
        Logger.shared.debug("ProductionAuthenticationService.toggleProtection(\(trip.name))")
        trip.isProtected.toggle()

        // If removing protection, also remove from authenticated trips
        if !trip.isProtected {
            let tripId = trip.id
            _ = lock.withLock { authenticatedTripIDs.remove(tripId) }
        }
    }

    func lockAllTrips() {
        lock.withLock { authenticatedTripIDs.removeAll() }
    }

    func resetSession() {
        lock.withLock { authenticatedTripIDs.removeAll() }
    }

    var allTripsLocked: Bool {
        lock.withLock { authenticatedTripIDs.isEmpty }
    }

    // MARK: - Additional Methods for State Management

    /// Add a state change handler
    /// - Parameter handler: The handler to add
    func addStateChangeHandler(_ handler: @escaping (UUID) -> Void) {
        lock.withLock { stateChangeHandlers.append(handler) }
    }

    /// Notify state change handlers
    /// - Parameter tripID: The trip ID that changed
    private func notifyStateChange(for tripID: UUID) {
        let handlers = lock.withLock { stateChangeHandlers }
        for handler in handlers {
            handler(tripID)
        }
    }
}
