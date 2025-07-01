//
//  AuthenticationService.swift
//  Traveling Snails
//
//

import Foundation
import LocalAuthentication

/// Service protocol for handling biometric authentication
/// Abstracts LocalAuthentication framework for testability
/// Sendable for safe concurrent access
protocol AuthenticationService: Sendable {
    /// Whether biometric authentication is available and enabled
    var isEnabled: Bool { get }

    /// The type of biometric authentication available
    var biometricType: BiometricType { get }

    /// Check if the device can use biometric authentication
    func canUseBiometrics() -> Bool

    /// Authenticate a user for a specific trip
    /// - Parameter trip: The trip to authenticate for
    /// - Returns: True if authentication succeeded, false otherwise
    func authenticateTrip(_ trip: Trip) async -> Bool

    /// Check if a trip is currently authenticated
    /// - Parameter trip: The trip to check
    /// - Returns: True if the trip is authenticated
    func isAuthenticated(for trip: Trip) -> Bool

    /// Check if a trip is protected (requires authentication)
    /// - Parameter trip: The trip to check
    /// - Returns: True if the trip requires authentication
    func isProtected(_ trip: Trip) -> Bool

    /// Lock a specific trip (remove authentication)
    /// - Parameter trip: The trip to lock
    @MainActor func lockTrip(_ trip: Trip)

    /// Toggle protection status for a trip
    /// - Parameter trip: The trip to toggle protection for
    @MainActor func toggleProtection(for trip: Trip)

    /// Lock all authenticated trips
    @MainActor func lockAllTrips()

    /// Reset the authentication session
    @MainActor func resetSession()

    /// Whether all trips are currently locked
    var allTripsLocked: Bool { get }
}

/// Represents the type of biometric authentication available
enum BiometricType: Sendable {
    case none
    case faceID
    case touchID
}

/// Errors that can occur during authentication
enum AuthenticationError: LocalizedError, Sendable {
    case notAvailable
    case notEnrolled
    case lockout
    case userCancelled
    case userFallback
    case systemCancel
    case invalidContext
    case notInteractive
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication is enrolled on this device"
        case .lockout:
            return "Biometric authentication is locked out"
        case .userCancelled:
            return "Authentication was cancelled by the user"
        case .userFallback:
            return "User chose to use fallback authentication"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .invalidContext:
            return "The authentication context is invalid"
        case .notInteractive:
            return "Authentication requires user interaction"
        case .timeout:
            return "Authentication timed out"
        case .unknown(let error):
            Logger.shared.error("Unknown authentication error: \(error.localizedDescription)", category: .app)
            return L(L10n.Errors.unknown)
        }
    }
}
