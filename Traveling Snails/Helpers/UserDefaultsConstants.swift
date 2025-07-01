//
//  UserDefaultsConstants.swift
//  Traveling Snails
//
//

import Foundation

/// Centralized UserDefaults keys to prevent scattered string literals throughout the codebase
/// This provides type-safe access to UserDefaults keys and prevents typos/inconsistencies
enum UserDefaultsConstants {
    
    // MARK: - App Settings Keys
    
    /// Key for storing the user's preferred color scheme (light/dark/auto)
    /// Used in: AppSettings.swift
    static let colorScheme = "colorScheme"
    
    /// Key for storing biometric authentication timeout in minutes
    /// Used in: AppSettings.swift, BiometricAuthManager.swift
    static let biometricTimeoutMinutes = "biometricTimeoutMinutes"
    
    // MARK: - Environment Detection Keys
    
    /// Key for detecting if the app is running in test mode
    /// Used throughout test files and environment detection
    static let isRunningTests = "isRunningTests"
}

// MARK: - UserDefaults Extension for Type Safety

extension UserDefaults {
    
    /// Type-safe accessors for common UserDefaults operations
    /// These provide compile-time safety and consistent access patterns
    
    // MARK: - Color Scheme
    
    /// Get the stored color scheme preference
    /// - Returns: The color scheme string, or nil if not set
    func getColorScheme() -> String? {
        return string(forKey: UserDefaultsConstants.colorScheme)
    }
    
    /// Set the color scheme preference
    /// - Parameter scheme: The color scheme to store
    func setColorScheme(_ scheme: String) {
        set(scheme, forKey: UserDefaultsConstants.colorScheme)
    }
    
    // MARK: - Biometric Timeout
    
    /// Get the biometric timeout value in minutes
    /// - Returns: The timeout in minutes, or 0 if not set
    func getBiometricTimeoutMinutes() -> Int {
        return integer(forKey: UserDefaultsConstants.biometricTimeoutMinutes)
    }
    
    /// Set the biometric timeout value in minutes
    /// - Parameter minutes: The timeout value in minutes
    func setBiometricTimeoutMinutes(_ minutes: Int) {
        set(minutes, forKey: UserDefaultsConstants.biometricTimeoutMinutes)
    }
    
    // MARK: - Test Environment
    
    /// Check if the app is running in test mode
    /// - Returns: true if running tests, false otherwise
    func isRunningTests() -> Bool {
        return bool(forKey: UserDefaultsConstants.isRunningTests)
    }
    
    /// Set the test running flag
    /// - Parameter isRunning: true if running tests, false otherwise
    func setIsRunningTests(_ isRunning: Bool) {
        set(isRunning, forKey: UserDefaultsConstants.isRunningTests)
    }
}