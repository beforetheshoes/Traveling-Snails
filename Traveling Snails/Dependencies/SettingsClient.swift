import ComposableArchitecture
import Foundation
import SwiftUI

struct SettingsSnapshot: Equatable, Sendable {
    var colorSchemePreference: ColorSchemePreference
    var biometricTimeoutMinutes: Int
}

enum ColorSchemePreference: String, CaseIterable, Equatable, Sendable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

struct SettingsClient: Sendable {
    var load: @Sendable () async -> SettingsSnapshot
    var saveColorScheme: @Sendable (ColorSchemePreference) async -> Void
    var saveBiometricTimeout: @Sendable (Int) async -> Void
}

extension SettingsClient: DependencyKey {
    static let liveValue = Self(
        load: {
            let defaults = UserDefaults.standard
            let colorRaw = defaults.string(forKey: UserDefaultsConstants.colorScheme) ?? ColorSchemePreference.system.rawValue
            let scheme = ColorSchemePreference(rawValue: colorRaw) ?? .system
            let minutes = defaults.integer(forKey: UserDefaultsConstants.biometricTimeoutMinutes)
            return SettingsSnapshot(
                colorSchemePreference: scheme,
                biometricTimeoutMinutes: minutes > 0 ? minutes : 5
            )
        },
        saveColorScheme: { preference in
            UserDefaults.standard.set(preference.rawValue, forKey: UserDefaultsConstants.colorScheme)
        },
        saveBiometricTimeout: { minutes in
            UserDefaults.standard.set(minutes, forKey: UserDefaultsConstants.biometricTimeoutMinutes)
        }
    )

    static let testValue = Self(
        load: { .init(colorSchemePreference: .system, biometricTimeoutMinutes: 5) },
        saveColorScheme: { _ in },
        saveBiometricTimeout: { _ in }
    )
}

extension DependencyValues {
    var settingsClient: SettingsClient {
        get { self[SettingsClient.self] }
        set { self[SettingsClient.self] = newValue }
    }
}
