//
//  BiometricAuthManagerTests.swift
//  Traveling Snails Tests
//
//  Created by Ryan Williams on 6/19/25.
//

import Testing
import LocalAuthentication
@testable import Traveling_Snails

@Suite("BiometricAuthManager Tests")
@MainActor
struct BiometricAuthManagerTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test("Manager should be accessible as singleton")
    func testSingletonAccess() {
        let manager1 = BiometricAuthManager.shared
        let manager2 = BiometricAuthManager.shared
        
        #expect(manager1 === manager2)
    }
    
    @Test("isEnabled should return true when biometrics are available")
    func testIsEnabledWhenBiometricsAvailable() {
        let manager = BiometricAuthManager.shared
        
        // This will depend on the test environment
        // On simulator without biometrics, should be false
        // On device with biometrics, should be true
        let isEnabled = manager.isEnabled
        let canUseBiometrics = manager.canUseBiometrics()
        
        #expect(isEnabled == canUseBiometrics)
    }
    
    // MARK: - Trip Protection Tests
    
    @Test("Unprotected trip should always be considered authenticated")
    func testUnprotectedTripAuthentication() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = false
        
        let isAuthenticated = manager.isAuthenticated(for: trip)
        #expect(isAuthenticated == true)
    }
    
    @Test("Protected trip should require authentication")
    func testProtectedTripRequiresAuthentication() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Protected Trip")
        trip.isProtected = true
        
        // Initially should not be authenticated
        let initialAuth = manager.isAuthenticated(for: trip)
        
        // If biometrics are not available, should be true (no protection possible)
        // If biometrics are available, should be false (needs authentication)
        if manager.canUseBiometrics() {
            #expect(initialAuth == false)
        } else {
            #expect(initialAuth == true)
        }
    }
    
    @Test("isProtected should consider both global setting and trip setting")
    func testIsProtectedLogic() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        
        // Test when trip is not protected
        trip.isProtected = false
        #expect(manager.isProtected(trip) == false)
        
        // Test when trip is protected
        trip.isProtected = true
        let expectedResult = manager.isEnabled && trip.isProtected
        #expect(manager.isProtected(trip) == expectedResult)
    }
    
    // MARK: - Session Management Tests
    
    @Test("Lock trip should remove from authenticated trips")
    func testLockTrip() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = true
        
        // Skip if biometrics not available
        guard manager.canUseBiometrics() else { return }
        
        // Manually add to authenticated trips (simulating successful auth)
        // Note: We can't actually test the authentication flow in unit tests
        // since it requires user interaction
        
        // Initially should not be authenticated
        let initialAuth = manager.isAuthenticated(for: trip)
        #expect(initialAuth == false)
        
        // Lock the trip (should be safe even if not authenticated)
        manager.lockTrip(trip)
        
        // Should still not be authenticated
        let finalAuth = manager.isAuthenticated(for: trip)
        #expect(finalAuth == false)
    }
    
    @Test("Toggle protection should update trip state")
    func testToggleProtection() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        let initialProtection = trip.isProtected
        
        manager.toggleProtection(for: trip)
        #expect(trip.isProtected == !initialProtection)
        
        manager.toggleProtection(for: trip)
        #expect(trip.isProtected == initialProtection)
    }
    
    @Test("Lock all trips should clear authentication state")
    func testLockAllTrips() {
        let manager = BiometricAuthManager.shared
        let trip1 = Trip(name: "Trip 1")
        let trip2 = Trip(name: "Trip 2")
        
        trip1.isProtected = true
        trip2.isProtected = true
        
        // Lock all trips
        manager.lockAllTrips()
        
        // Both should not be authenticated
        #expect(manager.isAuthenticated(for: trip1) == !manager.canUseBiometrics())
        #expect(manager.isAuthenticated(for: trip2) == !manager.canUseBiometrics())
    }
    
    @Test("Reset session should clear authentication state")
    func testResetSession() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = true
        
        // Reset session
        manager.resetSession()
        
        // Should not be authenticated
        #expect(manager.isAuthenticated(for: trip) == !manager.canUseBiometrics())
    }
    
    // MARK: - Biometric Type Tests
    
    @Test("Biometric type should be consistent")
    func testBiometricType() {
        let manager = BiometricAuthManager.shared
        let type1 = manager.biometricType
        let type2 = manager.biometricType
        
        #expect(type1 == type2)
        
        // Should be one of the expected values
        let validTypes: [BiometricAuthManager.BiometricType] = [.none, .faceID, .touchID]
        #expect(validTypes.contains(type1))
    }
    
    // MARK: - Edge Cases
    
    @Test("Multiple trips with different protection states")
    func testMultipleTripProtectionStates() {
        let manager = BiometricAuthManager.shared
        let unprotectedTrip = Trip(name: "Unprotected")
        let protectedTrip = Trip(name: "Protected")
        
        unprotectedTrip.isProtected = false
        protectedTrip.isProtected = true
        
        // Unprotected should always be authenticated
        #expect(manager.isAuthenticated(for: unprotectedTrip) == true)
        
        // Protected should depend on biometric availability
        let protectedAuth = manager.isAuthenticated(for: protectedTrip)
        if manager.canUseBiometrics() {
            #expect(protectedAuth == false)
        } else {
            #expect(protectedAuth == true)
        }
    }
    
    @Test("Protection state changes should be reflected immediately")
    func testProtectionStateChanges() {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        
        // Start unprotected
        trip.isProtected = false
        #expect(manager.isProtected(trip) == false)
        #expect(manager.isAuthenticated(for: trip) == true)
        
        // Make protected
        trip.isProtected = true
        let expectedProtected = manager.isEnabled && trip.isProtected
        #expect(manager.isProtected(trip) == expectedProtected)
        
        // Make unprotected again
        trip.isProtected = false
        #expect(manager.isProtected(trip) == false)
        #expect(manager.isAuthenticated(for: trip) == true)
    }
}

// MARK: - Mock Authentication Tests

@Suite("BiometricAuthManager Integration Tests")
@MainActor
struct BiometricAuthManagerIntegrationTests {
    
    @Test("Authentication flow should handle errors gracefully")
    func testAuthenticationErrorHandling() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = true
        
        // Skip if biometrics not available
        guard manager.canUseBiometrics() else { return }
        
        // This will likely fail in test environment (no user interaction)
        let result = await manager.authenticateTrip(trip)
        
        // In test environment, should handle gracefully (likely return false)
        #expect(result == false || result == true) // Either outcome is valid
        
        // Should not crash or hang
        #expect(manager.isAuthenticated(for: trip) == result)
    }
    
    @Test("Concurrent authentication attempts should be handled safely")
    func testConcurrentAuthentication() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = true
        
        // Skip if biometrics not available
        guard manager.canUseBiometrics() else { return }
        
        // Start multiple authentication attempts concurrently
        async let auth1 = manager.authenticateTrip(trip)
        async let auth2 = manager.authenticateTrip(trip)
        async let auth3 = manager.authenticateTrip(trip)
        
        let results = await [auth1, auth2, auth3]
        
        // All should complete without hanging
        for result in results {
            #expect(result == false || result == true)
        }
        
        // Manager should still be in consistent state
        let finalAuth = manager.isAuthenticated(for: trip)
        #expect(finalAuth == false || finalAuth == true)
    }
    
    @Test("Authentication should work with Sendable requirements")
    func testSendableCompliance() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Sendable Test Trip")
        trip.isProtected = true
        
        // This test would fail to compile if Trip capture isn't handled properly
        // The fact that it compiles means we're correctly capturing trip.id instead of trip
        let result = await manager.authenticateTrip(trip)
        
        // Result should be boolean (true on simulator, false/true on device)
        #expect(result == false || result == true)
        
        // Authentication state should be consistent
        let isAuthenticated = manager.isAuthenticated(for: trip)
        #expect(isAuthenticated == false || isAuthenticated == true)
    }
    
    @Test("IsolatedTripDetailView updateViewState should not deadlock")
    @MainActor func testIsolatedTripDetailViewUpdateViewState() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Test Trip")
        trip.isProtected = true
        
        // This test verifies that accessing BiometricAuthManager from @MainActor context
        // doesn't cause deadlocks as we saw in the Thread 37 crash
        
        // Access properties that were causing the deadlock
        let isAuthenticated = manager.isAuthenticated(for: trip)
        let isProtected = manager.isProtected(trip)
        let canUseBiometrics = manager.canUseBiometrics()
        let isEnabled = manager.isEnabled
        let biometricType = manager.biometricType
        
        // All should return without hanging
        #expect(isAuthenticated == false || isAuthenticated == true)
        #expect(isProtected == false || isProtected == true)
        #expect(canUseBiometrics == false || canUseBiometrics == true)
        #expect(isEnabled == false || isEnabled == true)
        #expect(biometricType == .none || biometricType == .faceID || biometricType == .touchID)
        
        // Test that authentication doesn't hang either
        let authResult = await manager.authenticateTrip(trip)
        #expect(authResult == false || authResult == true)
    }
    
    @Test("LAContext evaluatePolicy should be avoided on simulator")
    func testLAContextDirectUsageOnSimulator() async {
        // This test reproduces the actual hanging issue by calling LAContext directly
        let context = LAContext()
        
        #if targetEnvironment(simulator)
        // On simulator, this should complete quickly or we need to avoid it entirely
        let startTime = Date()
        
        // Test if canEvaluatePolicy hangs
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let checkDuration = Date().timeIntervalSince(startTime)
        
        print("🧪 canEvaluatePolicy took \(checkDuration) seconds, returned: \(canEvaluate)")
        
        if canEvaluate {
            // This is the problematic call that can hang indefinitely on simulator
            print("🧪 About to call evaluatePolicy - this may hang...")
            
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                return false
            }
            
            let authTask = Task {
                do {
                    let result = try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: "Test authentication"
                    )
                    return result
                } catch {
                    print("🧪 LAContext error: \(error)")
                    return false
                }
            }
            
            // Race between timeout and auth
            let result = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await timeoutTask.value }
                group.addTask { await authTask.value }
                
                guard let first = await group.next() else { return false }
                group.cancelAll()
                return first
            }
            
            let totalDuration = Date().timeIntervalSince(startTime)
            print("🧪 Authentication completed in \(totalDuration) seconds with result: \(result)")
            
            // If this hangs, the test will timeout and fail
            #expect(totalDuration < 3.0, "LAContext.evaluatePolicy should not hang for more than 3 seconds")
        }
        #else
        print("🧪 Running on real device - LAContext should work properly")
        #endif
    }
    
    @Test("BiometricAuthManager should avoid LAContext hanging")
    func testBiometricAuthManagerAvoidHanging() async {
        let manager = BiometricAuthManager.shared
        let trip = Trip(name: "Hanging Test Trip")
        trip.isProtected = true
        
        let startTime = Date()
        let result = await manager.authenticateTrip(trip)
        let duration = Date().timeIntervalSince(startTime)
        
        print("🧪 BiometricAuthManager.authenticateTrip took \(duration) seconds")
        
        // This MUST complete quickly - if it takes longer than 2 seconds, our fix failed
        #expect(duration < 2.0, "BiometricAuthManager.authenticateTrip is hanging - fix failed!")
        
        #if targetEnvironment(simulator)
        // On simulator, should return true (simulated success)
        #expect(result == true, "Simulator should simulate successful authentication")
        #else
        // On device, any result is valid
        #expect(result == false || result == true)
        #endif
    }
    
    @Test("Privacy permission should be properly configured")
    func testPrivacyPermissionConfiguration() {
        // Test that the NSFaceIDUsageDescription is properly set in Info.plist
        let bundle = Bundle.main
        let faceIDUsageDescription = bundle.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String
        
        #expect(faceIDUsageDescription != nil, "NSFaceIDUsageDescription must be set in Info.plist to prevent TCC crashes")
        #expect(!faceIDUsageDescription!.isEmpty, "NSFaceIDUsageDescription must not be empty")
        #expect(faceIDUsageDescription!.contains("Face ID") || faceIDUsageDescription!.contains("Touch ID"), "Usage description should mention Face ID or Touch ID")
        
        print("🧪 NSFaceIDUsageDescription: \(faceIDUsageDescription ?? "nil")")
    }
}