//
//  AppSettings.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/2/25.
//

import SwiftUI
import SwiftData

// MARK: - Modern App Settings using @Observable
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    public var colorScheme: ColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        }
    }
    
    // Biometric authentication is now always enabled when available
    // Removed global setting - protection is per-trip only
    
    private init() {
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? "system"
        self.colorScheme = ColorSchemePreference(rawValue: savedScheme) ?? .system
    }
}

enum ColorSchemePreference: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

