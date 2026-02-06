//
//  AuthenticationClient.swift
//  Traveling Snails
//

import Dependencies
import Foundation

struct AuthenticationClient: Sendable {
    var allTripsLocked: @Sendable () async -> Bool
    var lockAllTrips: @Sendable () async -> Void
}

extension AuthenticationClient: DependencyKey {
    static let liveValue: AuthenticationClient = {
        let service = ProductionAuthenticationService()
        return AuthenticationClient(
            allTripsLocked: { @MainActor in service.allTripsLocked },
            lockAllTrips: { @MainActor in service.lockAllTrips() }
        )
    }()

    static let testValue: AuthenticationClient = AuthenticationClient(
        allTripsLocked: { false },
        lockAllTrips: {}
    )
}

extension DependencyValues {
    var authenticationClient: AuthenticationClient {
        get { self[AuthenticationClient.self] }
        set { self[AuthenticationClient.self] = newValue }
    }
}
