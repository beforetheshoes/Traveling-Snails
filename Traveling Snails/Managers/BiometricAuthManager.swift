import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager {
    static let shared = BiometricAuthManager()
    
    // Cache the enabled state to avoid repeated access to @Observable AppSettings
    private var _isEnabled: Bool = false
    
    var isEnabled: Bool {
        get { _isEnabled }
        set { 
            _isEnabled = newValue
            AppSettings.shared.biometricAuthenticationEnabled = newValue
        }
    }
    
    // Simple session tracking - which trips are authenticated this session
    private var authenticatedTripIDs: Set<UUID> = []
    
    // Notification to allow manual UI updates when needed
    private var stateChangeHandlers: [(UUID) -> Void] = []
    
    private init() {
        // Initialize cached value from AppSettings
        _isEnabled = AppSettings.shared.biometricAuthenticationEnabled
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
    
    func authenticateTrip(_ trip: Trip) async -> Bool {
        #if DEBUG
        print("🔑 BiometricAuthManager.authenticateTrip(\(trip.name)) - START")
        print("   - Current authenticatedTripIDs: \(authenticatedTripIDs)")
        #endif
        
        // If trip is not protected, always return true
        guard isProtected(trip) else { 
            #if DEBUG
            print("   - Trip not protected, returning true")
            #endif
            return true 
        }
        
        // If already authenticated, return true
        if authenticatedTripIDs.contains(trip.id) {
            #if DEBUG
            print("   - Trip already authenticated, returning true")
            #endif
            return true
        }
        
        // Perform biometric authentication with fresh context
        let context = LAContext()
        
        // Check if biometrics are available before attempting authentication
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            #if DEBUG
            print("   - Biometrics not available, returning false")
            #endif
            return false
        }
        
        #if DEBUG
        print("   - Starting biometric authentication...")
        #endif
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access protected content"
            )
            
            #if DEBUG
            print("   - Biometric authentication result: \(result)")
            #endif
            
            if result {
                authenticatedTripIDs.insert(trip.id)
                #if DEBUG
                print("   - Added trip \(trip.id) to authenticated set")
                print("   - Updated authenticatedTripIDs: \(authenticatedTripIDs)")
                #endif
                // Don't notify state change here - let the view manage its own state
                // notifyStateChange(for: trip.id)
                return true
            }
            #if DEBUG
            print("   - Authentication failed, returning false")
            #endif
            return false
        } catch {
            #if DEBUG
            print("   - Authentication error: \(error)")
            #endif
            return false
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
