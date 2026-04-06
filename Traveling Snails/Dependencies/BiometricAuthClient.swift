import Dependencies
import Foundation

struct BiometricAuthClient {
    var canUseBiometrics: @Sendable () async -> Bool
    var isEnabled: @Sendable () async -> Bool
    var biometricType: @Sendable () async -> BiometricType
    var isProtected: @Sendable (Trip) async -> Bool
    var isAuthenticated: @Sendable (Trip) async -> Bool
    var authenticateTrip: @Sendable (Trip) async -> Bool
    var lockTrip: @Sendable (Trip) async -> Void
    var toggleProtection: @Sendable (Trip) async -> Void
    var resetSession: @Sendable () async -> Void
}

extension BiometricAuthClient: DependencyKey {
    private static let authService = ProductionAuthenticationService()

    static let liveValue = BiometricAuthClient(
        canUseBiometrics: { authService.canUseBiometrics() },
        isEnabled: { authService.isEnabled },
        biometricType: { authService.biometricType },
        isProtected: { trip in authService.isProtected(trip) },
        isAuthenticated: { trip in authService.isAuthenticated(for: trip) },
        authenticateTrip: { trip in await authService.authenticateTrip(trip) },
        lockTrip: { trip in await MainActor.run { authService.lockTrip(trip) } },
        toggleProtection: { trip in await MainActor.run { authService.toggleProtection(for: trip) } },
        resetSession: { await MainActor.run { authService.resetSession() } }
    )

    static let testValue = BiometricAuthClient(
        canUseBiometrics: { false },
        isEnabled: { false },
        biometricType: { .none },
        isProtected: { _ in false },
        isAuthenticated: { _ in true },
        authenticateTrip: { _ in true },
        lockTrip: { _ in },
        toggleProtection: { _ in },
        resetSession: {}
    )
}

extension DependencyValues {
    var biometricAuthClient: BiometricAuthClient {
        get { self[BiometricAuthClient.self] }
        set { self[BiometricAuthClient.self] = newValue }
    }
}
