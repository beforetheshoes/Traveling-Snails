import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    // Simple session tracking - which trips are authenticated this session
    private var authenticatedTripIDs: Set<UUID> = []
    
    // Biometrics are always enabled - protection is per-trip only
    var isEnabled: Bool {
        return canUseBiometrics()
    }
    
    // Notification to allow manual UI updates when needed
    private var stateChangeHandlers: [(UUID) -> Void] = []
    
    private init() {
        // No longer need to initialize from settings - always enabled if available
    }
    
    var biometricType: BiometricType {
        let context = LAContext()
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }
    
    enum BiometricType {
        case none
        case faceID
        case touchID
    }
    
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }
    
    // MARK: - Core Authentication Methods
    
    func isAuthenticated(for trip: Trip) -> Bool {
        let isProtectedTrip = isProtected(trip)
        let isInAuthenticatedSet = authenticatedTripIDs.contains(trip.id)
        let result = !isProtectedTrip || isInAuthenticatedSet
        
        // Only log when state actually changes to reduce noise
        // print("🔐 BiometricAuthManager.isAuthenticated(for: \(trip.name)): \(result)")
        
        return result
    }
    
    func isProtected(_ trip: Trip) -> Bool {
        let result = isEnabled && trip.isProtected
        // print("🛡️ BiometricAuthManager.isProtected(\(trip.name)): \(result)")
        return result
    }
    
    nonisolated func authenticateTrip(_ trip: Trip) async -> Bool {
        // Capture only the values we need to avoid Sendable issues
        let tripId = trip.id
        let tripName = trip.name
        let tripIsProtected = trip.isProtected
        
        #if DEBUG
        print("🔑 BiometricAuthManager.authenticateTrip(\(tripName)) - START")
        #endif
        
        // Check if trip is protected on main actor
        let effectivelyProtected = await MainActor.run {
            self.isEnabled && tripIsProtected
        }
        
        // If trip is not protected, always return true
        guard effectivelyProtected else { 
            #if DEBUG
            print("   - Trip not protected, returning true")
            #endif
            return true 
        }
        
        // Check if already authenticated on main actor
        let alreadyAuthenticated = await MainActor.run {
            self.authenticatedTripIDs.contains(tripId)
        }
        
        if alreadyAuthenticated {
            #if DEBUG
            print("   - Trip already authenticated, returning true")
            #endif
            return true
        }
        
        // Check if we're running on simulator using runtime detection instead of compile-time
        #if DEBUG
        print("   - Checking environment...")
        #if targetEnvironment(simulator)
        print("   - TARGET_OS_SIMULATOR compile flag: true")
        #else
        print("   - TARGET_OS_SIMULATOR compile flag: false")
        #endif
        print("   - Process info: \(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil)")
        #endif
        
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        #endif
        
        if isSimulator {
            // On simulator, simulate successful authentication for testing
            #if DEBUG
            print("   - Simulator detected, simulating successful authentication")
            #endif
            await MainActor.run {
                self.authenticatedTripIDs.insert(tripId)
                #if DEBUG
                print("   - Added trip \(tripId) to authenticated set (simulator)")
                print("   - Updated authenticatedTripIDs: \(self.authenticatedTripIDs)")
                #endif
            }
            return true
        }
        
        #if DEBUG
        print("   - Real device detected, proceeding with actual biometric authentication")
        #endif
        // Perform biometric authentication with fresh context
        let context = LAContext()
        
        // Check if biometrics are available before attempting authentication
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            #if DEBUG
            if let error = error {
                print("   - Biometrics not available: \(error.localizedDescription)")
                print("   - Error code: \(error.code)")
            } else {
                print("   - Biometrics not available, returning false")
            }
            #endif
            return false
        }
        
        #if DEBUG
        print("   - Starting biometric authentication with timeout protection...")
        #endif
        
        // Add timeout protection to prevent indefinite hanging
        let timeoutSeconds: UInt64 = 30 // 30 second timeout
        
        return await withTaskGroup(of: Bool.self) { group in
            // Authentication task
            group.addTask {
                do {
                    let result = try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: "Authenticate to access protected content"
                    )
                    
                    #if DEBUG
                    print("   - Biometric authentication result: \(result)")
                    #endif
                    
                    if result {
                        await MainActor.run {
                            self.authenticatedTripIDs.insert(tripId)
                            #if DEBUG
                            print("   - Added trip \(tripId) to authenticated set")
                            print("   - Updated authenticatedTripIDs: \(self.authenticatedTripIDs)")
                            #endif
                        }
                        return true
                    }
                    #if DEBUG
                    print("   - Authentication failed, returning false")
                    #endif
                    return false
                } catch {
                    #if DEBUG
                    print("   - Authentication error: \(error)")
                    if let laError = error as? LAError {
                        print("   - LAError code: \(laError.code.rawValue)")
                        switch laError.code {
                        case .biometryNotAvailable:
                            print("   - Biometry not available on this device")
                        case .biometryNotEnrolled:
                            print("   - User has not enrolled biometrics")
                        case .biometryLockout:
                            print("   - Biometry is locked out")
                        case .userCancel:
                            print("   - User cancelled authentication")
                        case .userFallback:
                            print("   - User chose fallback method")
                        case .appCancel:
                            print("   - App cancelled authentication")
                        case .invalidContext:
                            print("   - Invalid context")
                        case .notInteractive:
                            print("   - Not interactive")
                        default:
                            print("   - Other LAError: \(laError.localizedDescription)")
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
                print("   - Authentication timed out after \(timeoutSeconds) seconds")
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
    }
    
    func lockTrip(_ trip: Trip) {
        #if DEBUG
        print("🔒 BiometricAuthManager.lockTrip(\(trip.name))")
        print("   - Before: authenticatedTripIDs = \(authenticatedTripIDs)")
        #endif
        authenticatedTripIDs.remove(trip.id)
        #if DEBUG
        print("   - After: authenticatedTripIDs = \(authenticatedTripIDs)")
        #endif
        // Don't notify state change here - let the view manage its own state
        // notifyStateChange(for: trip.id)
    }
    
    func toggleProtection(for trip: Trip) {
        #if DEBUG
        print("🛡️ BiometricAuthManager.toggleProtection(\(trip.name))")
        print("   - Before: trip.isProtected = \(trip.isProtected)")
        #endif
        trip.isProtected.toggle()
        #if DEBUG
        print("   - After: trip.isProtected = \(trip.isProtected)")
        #endif
        
        // If removing protection, also remove from authenticated trips
        if !trip.isProtected {
            #if DEBUG
            print("   - Removing from authenticated trips")
            #endif
            authenticatedTripIDs.remove(trip.id)
        }
        #if DEBUG
        print("   - Final authenticatedTripIDs = \(authenticatedTripIDs)")
        #endif
    }
    
    func lockAllTrips() {
        authenticatedTripIDs.removeAll()
    }
    
    func resetSession() {
        authenticatedTripIDs.removeAll()
    }
    
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
