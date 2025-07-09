//
//  ActivitySubmitButtonInlineRecoveryTests.swift
//  Traveling Snails
//
//  Tests for enhanced ActivitySubmitButton with inline recovery actions
//

import SwiftData
import SwiftUI

#if DEBUG && canImport(Testing)
import Testing
#elseif DEBUG
// Testing framework not available - test-related code will be excluded
#endif

@testable import Traveling_Snails

#if DEBUG

@Suite("ActivitySubmitButton Inline Recovery Tests")
struct ActivitySubmitButtonInlineRecoveryTests {
    @Test("ActivitySubmitButton shows inline recovery for network errors")
    func testNetworkErrorInlineRecovery() {
        let error = AppError.networkUnavailable
        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: error,
            recoveryActions: [.retry, .workOffline]
        ) {}

        // This test will fail until we implement recovery actions
        #expect(button.recoveryActions?.count == 2)
        #expect(button.recoveryActions?.contains(.retry) == true)
        #expect(button.recoveryActions?.contains(.workOffline) == true)
    }

    @Test("ActivitySubmitButton shows contextual help for validation errors")
    func testValidationErrorContextualHelp() {
        let error = AppError.missingRequiredField("Activity name")
        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: false,
            isSaving: false,
            color: .blue,
            saveError: error,
            recoveryActions: [.fixInput]
        ) {}

        // This test will fail until we implement contextual help
        #expect(button.contextualHelp == "Please complete the Activity name field before saving")
        #expect(button.recoveryActions?.contains(.fixInput) == true)
    }

    @Test("ActivitySubmitButton handles recovery action callbacks")
    func testRecoveryActionCallbacks() {
        let error = AppError.timeoutError
        var actionCalled: TripEditAction?

        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: error,
            recoveryActions: [.retry, .saveAsDraft]
        ) {
            // Save action
        } onRecoveryAction: { action in
            actionCalled = action
        }

        // This test will fail until we implement recovery callbacks
        button.handleRecoveryAction(.retry)
        #expect(actionCalled == .retry)
    }

    @Test("ActivitySubmitButton shows progressive disclosure for complex errors")
    func testProgressiveDisclosureForComplexErrors() {
        let error = AppError.databaseSaveFailed("Foreign key constraint failed")
        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: error,
            recoveryActions: [.retry, .saveAsDraft]
        ) {}

        // This test will fail until we implement progressive disclosure
        #expect(button.showsProgressiveDisclosure == true)
        #expect(button.errorDetails.contains("Foreign key constraint failed"))
    }

    @Test("ActivitySubmitButton maintains original functionality without recovery actions")
    func testOriginalFunctionalityMaintained() {
        let error = AppError.unknown("Generic error")
        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: error
        ) {}

        // This test should pass - original functionality preserved
        #expect(button.title == "Save Activity")
        #expect(button.isValid == true)
        #expect(button.isSaving == false)
        #expect(button.color == .blue)
        #expect(button.saveError != nil)
    }

    @Test("ActivitySubmitButton provides accessibility for recovery actions")
    func testAccessibilityForRecoveryActions() {
        let error = AppError.cloudKitQuotaExceeded
        let button = ActivitySubmitButton(
            title: "Save Activity",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: error,
            recoveryActions: [.manageStorage, .upgradeStorage]
        ) {}

        // This test will fail until we implement accessibility
        #expect(button.accessibilityLabel.contains("CloudKit error"))
        #expect(button.accessibilityHint.contains("recovery actions available"))
    }

    @Test("ActivitySubmitButton generates appropriate recovery actions for different error types")
    func testRecoveryActionGeneration() {
        let networkError = AppError.networkUnavailable
        let validationError = AppError.missingRequiredField("name")
        let storageError = AppError.cloudKitQuotaExceeded

        let networkButton = ActivitySubmitButton(
            title: "Save",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: networkError
        ) {}

        let validationButton = ActivitySubmitButton(
            title: "Save",
            isValid: false,
            isSaving: false,
            color: .blue,
            saveError: validationError
        ) {}

        let storageButton = ActivitySubmitButton(
            title: "Save",
            isValid: true,
            isSaving: false,
            color: .blue,
            saveError: storageError
        ) {}

        // These tests will fail until we implement automatic recovery action generation
        #expect(networkButton.suggestedRecoveryActions.contains(.retry))
        #expect(networkButton.suggestedRecoveryActions.contains(.workOffline))

        #expect(validationButton.suggestedRecoveryActions.contains(.fixInput))

        #expect(storageButton.suggestedRecoveryActions.contains(.manageStorage))
        #expect(storageButton.suggestedRecoveryActions.contains(.upgradeStorage))
    }
}

#endif
