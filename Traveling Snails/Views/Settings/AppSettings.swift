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
    private var modelContext: ModelContext?
    
    public var colorScheme: ColorSchemePreference {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: "colorScheme")
        }
    }
    
    public var biometricAuthenticationEnabled: Bool {
        get { 
            guard let modelContext = modelContext else {
                // Fallback to UserDefaults if SwiftData not available yet
                return UserDefaults.standard.bool(forKey: "biometricAuthenticationEnabled")
            }
            let settings = SyncedSettings.getOrCreate(in: modelContext)
            return settings.isBiometricAuthEnabled
        }
        set { 
            // Save to both UserDefaults (for backward compatibility) and SwiftData (for sync)
            UserDefaults.standard.set(newValue, forKey: "biometricAuthenticationEnabled")
            
            guard let modelContext = modelContext else { return }
            let settings = SyncedSettings.getOrCreate(in: modelContext)
            settings.isBiometricAuthEnabled = newValue
            
            do {
                try modelContext.save()
            } catch {
                print("❌ AppSettings: Error saving biometric setting: \(error)")
            }
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        
        // Migrate existing UserDefaults setting to SwiftData
        let existingUserDefaultsSetting = UserDefaults.standard.bool(forKey: "biometricAuthenticationEnabled")
        if existingUserDefaultsSetting {
            let settings = SyncedSettings.getOrCreate(in: context)
            if !settings.isBiometricAuthEnabled {
                settings.isBiometricAuthEnabled = true
                try? context.save()
                print("📱 AppSettings: Migrated biometric setting to SwiftData")
            }
        }
    }
    
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

