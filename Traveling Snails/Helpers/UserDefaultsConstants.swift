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
    
    // MARK: - Error Management Configuration Keys
    
    /// Key for configuring the maximum number of error states to retain in memory
    /// Used in: ErrorStateManagement.swift
    /// Default: 50, Range: 10-200 (reasonable bounds for memory vs. debugging needs)
    static let errorStateMaxCount = "ErrorStateMaxCount"
}

// MARK: - UserDefaults Extension for Type Safety

extension UserDefaults {
    /// Type-safe accessors for common UserDefaults operations
    /// These provide compile-time safety and consistent access patterns

    // MARK: - Color Scheme

    /// Get the stored color scheme preference
    /// - Returns: The color scheme string, or nil if not set
    func getColorScheme() -> String? {
        string(forKey: UserDefaultsConstants.colorScheme)
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
        integer(forKey: UserDefaultsConstants.biometricTimeoutMinutes)
    }

    /// Set the biometric timeout value in minutes
    /// - Parameter minutes: The timeout value in minutes
    func setBiometricTimeoutMinutes(_ minutes: Int) {
        set(minutes, forKey: UserDefaultsConstants.biometricTimeoutMinutes)
    }

    // MARK: - Test Environment

    /// Get the test running flag
    /// - Returns: true if running tests, false otherwise
    func getIsRunningTests() -> Bool {
        bool(forKey: UserDefaultsConstants.isRunningTests)
    }

    /// Set the test running flag
    /// - Parameter isRunning: true if running tests, false otherwise
    func setIsRunningTests(_ isRunning: Bool) {
        set(isRunning, forKey: UserDefaultsConstants.isRunningTests)
    }
    
    // MARK: - Error State Configuration
    
    /// Get the maximum number of error states to retain
    /// - Returns: The max count (default: 50, minimum: 10)
    func getErrorStateMaxCount() -> Int {
        let value = integer(forKey: UserDefaultsConstants.errorStateMaxCount)
        return value > 0 ? max(10, value) : 50 // Ensure minimum of 10, default 50
    }
    
    /// Set the maximum number of error states to retain
    /// - Parameter count: The max count (will be clamped to 10-200 range)
    func setErrorStateMaxCount(_ count: Int) {
        let clampedCount = max(10, min(200, count)) // Clamp to reasonable bounds
        set(clampedCount, forKey: UserDefaultsConstants.errorStateMaxCount)
    }
}
