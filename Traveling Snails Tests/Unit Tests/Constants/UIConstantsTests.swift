//
//  UIConstantsTests.swift
//  Traveling Snails Tests
//
//

import SwiftUI
import Testing
@testable import Traveling_Snails

/// Tests for centralized UI constants
/// These tests verify that UI spacing, timing, and layout constants are properly centralized
@Suite("UI Constants Tests")
struct UIConstantsTests {
    // MARK: - Spacing Constants Tests

    @Test("Spacing constants exist and have expected values")
    func testSpacingConstants() {
        // These tests will initially fail - we need to create UIConstants
        #expect(UIConstants.Spacing.tiny == 4)
        #expect(UIConstants.Spacing.small == 8)
        #expect(UIConstants.Spacing.medium == 12)
        #expect(UIConstants.Spacing.large == 16)
        #expect(UIConstants.Spacing.extraLarge == 20)
    }

    @Test("Spacing constants are properly typed as CGFloat")
    func testSpacingTyping() {
        // Verify that spacing constants are CGFloat for SwiftUI compatibility
        let spacingValue: CGFloat = UIConstants.Spacing.medium
        #expect(spacingValue == 12.0)
    }

    // MARK: - Icon Size Constants Tests

    @Test("Icon size constants exist and have expected values")
    func testIconSizeConstants() {
        #expect(UIConstants.IconSizes.small == 16)
        #expect(UIConstants.IconSizes.medium == 24)
        #expect(UIConstants.IconSizes.large == 50)
    }

    // MARK: - Timing Constants Tests

    @Test("Timing constants exist and have expected values")
    func testTimingConstants() {
        #expect(UIConstants.Timing.biometricTimeoutSeconds == 30)
        #expect(UIConstants.Timing.macCatalystPollingInterval == 10.0)
        #expect(UIConstants.Timing.standardPollingInterval == 30.0)
        #expect(UIConstants.Timing.nanosecondMultiplier == 1_000_000_000)
    }

    @Test("Timing constants have proper types")
    func testTimingTypes() {
        // Verify proper typing for different timing use cases
        let timeoutSeconds: UInt64 = UIConstants.Timing.biometricTimeoutSeconds
        let pollingInterval: TimeInterval = UIConstants.Timing.macCatalystPollingInterval
        let standardInterval: TimeInterval = UIConstants.Timing.standardPollingInterval
        let nanoseconds: UInt64 = UIConstants.Timing.nanosecondMultiplier

        #expect(timeoutSeconds == 30)
        #expect(pollingInterval == 10.0)
        #expect(standardInterval == 30.0)
        #expect(nanoseconds == 1_000_000_000)
    }

    // MARK: - SwiftUI Integration Tests

    @Test("Spacing constants work with SwiftUI padding")
    func testSwiftUIIntegration() {
        // Test that constants can be used in SwiftUI contexts
        let paddingValue = UIConstants.Spacing.medium

        // This should compile and work without issues
        _ = Text("Test")
            .padding(paddingValue)

        #expect(paddingValue == 12)
    }

    @Test("All constants are positive values")
    func testPositiveValues() {
        // Verify that all UI constants are positive (makes sense for UI)
        #expect(UIConstants.Spacing.tiny > 0)
        #expect(UIConstants.Spacing.small > 0)
        #expect(UIConstants.Spacing.medium > 0)
        #expect(UIConstants.Spacing.large > 0)
        #expect(UIConstants.Spacing.extraLarge > 0)

        #expect(UIConstants.IconSizes.small > 0)
        #expect(UIConstants.IconSizes.medium > 0)
        #expect(UIConstants.IconSizes.large > 0)

        #expect(UIConstants.Timing.biometricTimeoutSeconds > 0)
        #expect(UIConstants.Timing.macCatalystPollingInterval > 0)
        #expect(UIConstants.Timing.standardPollingInterval > 0)
        #expect(UIConstants.Timing.nanosecondMultiplier > 0)
    }

    @Test("Spacing constants are in ascending order")
    func testSpacingOrder() {
        // Verify that spacing constants make logical sense (smaller to larger)
        #expect(UIConstants.Spacing.tiny < UIConstants.Spacing.small)
        #expect(UIConstants.Spacing.small < UIConstants.Spacing.medium)
        #expect(UIConstants.Spacing.medium < UIConstants.Spacing.large)
        #expect(UIConstants.Spacing.large < UIConstants.Spacing.extraLarge)
    }
}
