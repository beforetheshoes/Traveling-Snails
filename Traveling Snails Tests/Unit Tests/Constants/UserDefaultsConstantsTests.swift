//
//  UserDefaultsConstantsTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Tests for centralized UserDefaults constants
/// These tests verify that UserDefaults keys are properly centralized and accessible
@Suite("UserDefaults Constants Tests")
struct UserDefaultsConstantsTests {
    @Test("ColorScheme key constant exists and matches expected value", .tags(.unit, .fast, .parallel, .validation, .settings))
    func testColorSchemeKeyConstant() {
        // This test will initially fail - we need to create UserDefaultsConstants
        #expect(UserDefaultsConstants.colorScheme == "colorScheme")
    }

    @Test("Biometric timeout key constant exists and matches expected value", .tags(.unit, .fast, .parallel, .validation, .settings, .biometric))
    func testBiometricTimeoutKeyConstant() {
        // This test will initially fail - we need to create UserDefaultsConstants
        #expect(UserDefaultsConstants.biometricTimeoutMinutes == "biometricTimeoutMinutes")
    }

    @Test("Test running key constant exists and matches expected value", .tags(.unit, .fast, .parallel, .validation, .settings, .utility))
    func testIsRunningTestsKeyConstant() {
        // This test will initially fail - we need to create UserDefaultsConstants
        #expect(UserDefaultsConstants.isRunningTests == "isRunningTests")
    }

    @Test("All constants are non-empty strings", .tags(.unit, .fast, .parallel, .validation, .settings, .boundary))
    func testConstantsAreNonEmpty() {
        // Verify that all constants are properly defined
        let constants = [
            UserDefaultsConstants.colorScheme,
            UserDefaultsConstants.biometricTimeoutMinutes,
            UserDefaultsConstants.isRunningTests,
        ]

        for constant in constants {
            #expect(!constant.isEmpty, "UserDefaults constant should not be empty")
        }
    }

    @Test("Constants maintain backward compatibility with existing usage", .tags(.unit, .fast, .parallel, .validation, .settings, .compatibility, .regression))
    func testBackwardCompatibility() {
        // Test that the constants match what's currently used in AppSettings.swift
        // This ensures we don't break existing functionality

        // These are the actual values currently scattered throughout the codebase
        #expect(UserDefaultsConstants.colorScheme == "colorScheme")
        #expect(UserDefaultsConstants.biometricTimeoutMinutes == "biometricTimeoutMinutes")
        #expect(UserDefaultsConstants.isRunningTests == "isRunningTests")
    }

    @Test("Constants can be used with UserDefaults", .tags(.unit, .fast, .serial, .validation, .settings, .filesystem))
    func testUserDefaultsIntegration() {
        let testValue = "testValue"

        // Test that our constants work with actual UserDefaults operations
        UserDefaults.standard.set(testValue, forKey: UserDefaultsConstants.colorScheme)
        let retrievedValue = UserDefaults.standard.string(forKey: UserDefaultsConstants.colorScheme)

        #expect(retrievedValue == testValue)

        // Clean up
        UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.colorScheme)
    }
}
