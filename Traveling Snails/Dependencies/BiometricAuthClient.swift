import Dependencies
import Foundation

struct BiometricAuthClient: Sendable {
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
    static let liveValue: BiometricAuthClient = {
        return BiometricAuthClient(
            canUseBiometrics: {
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .canUseBiometrics()
                }
            },
            isEnabled: {
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .isEnabled
                }
            },
            biometricType: {
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .biometricType
                }
            },
            isProtected: { trip in
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .isProtected(trip)
                }
            },
            isAuthenticated: { trip in
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .isAuthenticated(for: trip)
                }
            },
            authenticateTrip: { trip in
                let authManager = await MainActor.run {
                    ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production()
                }
                return await authManager.authenticateTrip(trip)
            },
            lockTrip: { trip in
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .lockTrip(trip)
                }
            },
            toggleProtection: { trip in
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .toggleProtection(for: trip)
                }
            },
            resetSession: {
                await MainActor.run {
                    (ModernBiometricAuthManager.shared ?? ModernBiometricAuthManager.production())
                        .resetSession()
                }
            }
        )
    }()

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
