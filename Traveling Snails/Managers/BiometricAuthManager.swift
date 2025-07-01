import Foundation
import LocalAuthentication
import SwiftUI

@Observable
@MainActor
class BiometricAuthManager {
    static let shared: BiometricAuthManager = {
        // Add runtime validation to warn about singleton access during tests
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            Logger.secure(category: .app).warning("⚠️ BiometricAuthManager.shared accessed during test execution! This bypasses dependency injection and may cause hanging. Use injected AuthenticationService instead.")
            // Print stack trace for debugging
            Thread.callStackSymbols.forEach { Logger.secure(category: .app).debug("  \($0, privacy: .public)") }
        }
        #endif
        return BiometricAuthManager()
    }()

    // Simple session tracking - which trips are authenticated this session
    private var authenticatedTripIDs: Set<UUID> = []

    // Biometrics are always enabled - protection is per-trip only
    var isEnabled: Bool {
        #if targetEnvironment(simulator)
        // In simulator, check if we're running tests
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            // During tests, isEnabled should match canUseBiometrics() which returns false
            return false
        }
        #endif
        // For non-test simulator runs, always consider biometrics "enabled" for testing purposes
        return true
        #else
        return canUseBiometrics()
        #endif
    }

    // Notification to allow manual UI updates when needed
    private var stateChangeHandlers: [(UUID) -> Void] = []

    private init() {
        // No longer need to initialize from settings - always enabled if available
    }

    var biometricType: BiometricType {
        // CRITICAL: Test detection FIRST before any LAContext creation
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                           ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ||
                           Bundle.main.bundleIdentifier?.contains("Tests") == true
        if isRunningTests {
            return .none
        }
        #endif

        // SECOND: Check simulator (only for non-test builds)
        #if targetEnvironment(simulator)
        return .none
        #else
        // THIRD: Real device, non-test - safe to use LAContext
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

    enum BiometricType {
        case none
        case faceID
        case touchID
    }

    func canUseBiometrics() -> Bool {
        // CRITICAL: Test detection FIRST before any LAContext creation
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                           ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ||
                           Bundle.main.bundleIdentifier?.contains("Tests") == true
        if isRunningTests {
            return false
        }
        #endif

        // SECOND: Check simulator (only for non-test builds)
        #if targetEnvironment(simulator)
        return false
        #else
        // THIRD: Real device, non-test - safe to use LAContext
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        #endif
    }

    // MARK: - Core Authentication Methods

    func isAuthenticated(for trip: Trip) -> Bool {
        let isProtectedTrip = isProtected(trip)
        let isInAuthenticatedSet = authenticatedTripIDs.contains(trip.id)
        let result = !isProtectedTrip || isInAuthenticatedSet

        // Only log when state actually changes to reduce noise
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricAuthManager.isAuthenticated for trip ID \(trip.id, privacy: .public): \(result, privacy: .public)")
        #endif

        return result
    }

    func isProtected(_ trip: Trip) -> Bool {
        let result = isEnabled && trip.isProtected
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricAuthManager.isProtected for trip ID \(trip.id, privacy: .public): \(result, privacy: .public)")
        #endif
        return result
    }

    nonisolated func authenticateTrip(_ trip: Trip) async -> Bool {
        // Capture only the values we need to avoid Sendable issues
        let tripId = trip.id
        _ = trip.name
        let tripIsProtected = trip.isProtected

        #if DEBUG
        Logger.secure(category: .app).debug("BiometricAuthManager.authenticateTrip for trip ID: \(tripId, privacy: .public) - START")
        #endif

        // CRITICAL: Test detection FIRST before any LAContext creation
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                           ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ||
                           Bundle.main.bundleIdentifier?.contains("Tests") == true
        if isRunningTests {
            #if DEBUG
            Logger.secure(category: .app).debug("Test environment detected, skipping biometric authentication")
            #endif
            _ = await MainActor.run {
                self.authenticatedTripIDs.insert(tripId)
            }
            return true
        }
        #endif

        // Check if trip is protected on main actor
        let effectivelyProtected = await MainActor.run {
            self.isEnabled && tripIsProtected
        }

        // If trip is not protected, always return true
        guard effectivelyProtected else {
            #if DEBUG
            Logger.secure(category: .app).debug("Trip not protected, returning true")
            #endif
            return true
        }

        // Check if already authenticated on main actor
        let alreadyAuthenticated = await MainActor.run {
            self.authenticatedTripIDs.contains(tripId)
        }

        if alreadyAuthenticated {
            #if DEBUG
            Logger.secure(category: .app).debug("Trip already authenticated, returning true")
            #endif
            return true
        }

        // Perform authentication (platform-specific behavior)
        #if targetEnvironment(simulator)
        // On simulator, ALWAYS skip biometric authentication to prevent hanging
        #if DEBUG
        Logger.secure(category: .app).debug("Simulator environment detected, skipping biometric authentication")
        #endif
        _ = await MainActor.run {
            self.authenticatedTripIDs.insert(tripId)
        }
        return true
        #else
        // Real device - perform actual biometric authentication
        #if DEBUG
        Logger.secure(category: .app).debug("Real device detected, proceeding with actual biometric authentication")
        #endif

        // Perform biometric authentication with fresh context
        let context = LAContext()

        // Check if biometrics are available before attempting authentication
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            #if DEBUG
            if let error = error {
                Logger.secure(category: .app).debug("Biometrics not available: \(error.localizedDescription, privacy: .public)")
                Logger.secure(category: .app).debug("Error code: \(error.code, privacy: .public)")
            } else {
                Logger.secure(category: .app).debug("Biometrics not available, returning false")
            }
            #endif
            return false
        }

        #if DEBUG
        Logger.secure(category: .app).debug("Starting biometric authentication with timeout protection...")
        #endif

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

                    #if DEBUG
                    Logger.secure(category: .app).debug("Biometric authentication result: \(result, privacy: .public)")
                    #endif

                    if result {
                        await MainActor.run {
                            self.authenticatedTripIDs.insert(tripId)
                            #if DEBUG
                            Logger.secure(category: .app).debug("Added trip \(tripId, privacy: .public) to authenticated set")
                            Logger.secure(category: .app).debug("Updated authenticatedTripIDs: \(self.authenticatedTripIDs, privacy: .public)")
                            #endif
                        }
                        return true
                    }
                    #if DEBUG
                    Logger.secure(category: .app).debug("Authentication failed, returning false")
                    #endif
                    return false
                } catch {
                    #if DEBUG
                    Logger.secure(category: .app).debug("Authentication error: \(error.localizedDescription, privacy: .public)")
                    if let laError = error as? LAError {
                        #if DEBUG
                        Logger.secure(category: .app).debug("LAError code: \(laError.code.rawValue, privacy: .public)")
                        #endif
                        switch laError.code {
                        case .biometryNotAvailable:
                            #if DEBUG
                            Logger.secure(category: .app).debug("Biometry not available on this device")
                            #endif
                        case .biometryNotEnrolled:
                            #if DEBUG
                            Logger.secure(category: .app).debug("User has not enrolled biometrics")
                            #endif
                        case .biometryLockout:
                            #if DEBUG
                            Logger.secure(category: .app).debug("Biometry is locked out")
                            #endif
                        case .userCancel:
                            #if DEBUG
                            Logger.secure(category: .app).debug("User cancelled authentication")
                            #endif
                        case .userFallback:
                            #if DEBUG
                            Logger.secure(category: .app).debug("User chose fallback method")
                            #endif
                        case .appCancel:
                            #if DEBUG
                            Logger.secure(category: .app).debug("App cancelled authentication")
                            #endif
                        case .invalidContext:
                            #if DEBUG
                            Logger.secure(category: .app).debug("Invalid context")
                            #endif
                        case .notInteractive:
                            #if DEBUG
                            Logger.secure(category: .app).debug("Not interactive")
                            #endif
                        default:
                            #if DEBUG
                            Logger.secure(category: .app).debug("Other LAError: \(laError.localizedDescription, privacy: .public)")
                            #endif
                        }
                    }
                    #endif
                    return false
                }
            }

            // Timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                #if DEBUG
                Logger.secure(category: .app).debug("Authentication timed out after \(timeoutSeconds, privacy: .public) seconds")
                #endif
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

    func lockTrip(_ trip: Trip) {
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricAuthManager.lockTrip for trip ID: \(trip.id, privacy: .public)")
        Logger.secure(category: .app).debug("Before: authenticatedTripIDs = \(self.authenticatedTripIDs, privacy: .public)")
        #endif
        authenticatedTripIDs.remove(trip.id)
        #if DEBUG
        Logger.secure(category: .app).debug("After: authenticatedTripIDs = \(self.authenticatedTripIDs, privacy: .public)")
        #endif
        // Don't notify state change here - let the view manage its own state
        // notifyStateChange(for: trip.id)
    }

    func toggleProtection(for trip: Trip) {
        #if DEBUG
        Logger.secure(category: .app).debug("BiometricAuthManager.toggleProtection for trip ID: \(trip.id, privacy: .public))")
        Logger.secure(category: .app).debug("Before: trip.isProtected = \(trip.isProtected, privacy: .public)")
        #endif
        trip.isProtected.toggle()
        #if DEBUG
        Logger.secure(category: .app).debug("After: trip.isProtected = \(trip.isProtected, privacy: .public)")
        #endif

        // If removing protection, also remove from authenticated trips
        if !trip.isProtected {
            #if DEBUG
            Logger.secure(category: .app).debug("Removing from authenticated trips")
            #endif
            authenticatedTripIDs.remove(trip.id)
        }
        #if DEBUG
        Logger.secure(category: .app).debug("Final authenticatedTripIDs = \(self.authenticatedTripIDs, privacy: .public)")
        #endif
    }

    func lockAllTrips() {
        authenticatedTripIDs.removeAll()
    }

    var allTripsLocked: Bool {
        // Add runtime validation to warn about singleton access during tests
        #if DEBUG
        let isRunningTests = UserDefaults.standard.bool(forKey: "isRunningTests") ||
                           NSClassFromString("XCTestCase") != nil ||
                           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            Logger.secure(category: .app).warning("⚠️ BiometricAuthManager.allTripsLocked accessed during test execution! This bypasses dependency injection and may cause hanging. Use injected AuthenticationService instead.")
        }
        #endif
        return authenticatedTripIDs.isEmpty
    }

    func resetSession() {
        authenticatedTripIDs.removeAll()
    }

    // MARK: - Test Support
    #if DEBUG
    /// Reset authentication state for testing - clears all authenticated trips
    func resetForTesting() {
        authenticatedTripIDs.removeAll()
    }
    #endif

    // MARK: - Manual State Change Notification

    func addStateChangeHandler(_ handler: @escaping (UUID) -> Void) {
        stateChangeHandlers.append(handler)
    }

    private func notifyStateChange(for tripID: UUID) {
        for handler in stateChangeHandlers {
            handler(tripID)
        }
    }
}
