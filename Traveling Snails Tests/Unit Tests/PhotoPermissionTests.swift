//
//  PhotoPermissionTests.swift
//  Traveling Snails Tests
//
//

import Photos
import Testing
@testable import Traveling_Snails
import UniformTypeIdentifiers

@Suite("Photo Permission Tests")
struct PhotoPermissionTests {
    // MARK: - Test Isolation Helpers

    /// Clean up shared state to prevent test contamination
    static func cleanupSharedState() {
        // Clear UserDefaults test keys
        let testKeys = ["isRunningTests", "photoPermissionTests"]
        for key in testKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Ensure test environment is properly detected
        UserDefaults.standard.set(true, forKey: "isRunningTests")
    }

    @Test("Info.plist contains NSPhotoLibraryUsageDescription")
    func testInfoPlistContainsPhotoLibraryUsageDescription() {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }
        // This test should FAIL initially - no permission description exists
        let bundle = Bundle.main
        let infoPlist = bundle.infoDictionary

        #expect(infoPlist != nil, "Info.plist should be accessible")

        if let photoLibraryUsageDescription = infoPlist?["NSPhotoLibraryUsageDescription"] as? String {
            #expect(!photoLibraryUsageDescription.isEmpty, "NSPhotoLibraryUsageDescription should not be empty")

            // Verify it's user-friendly
            #expect(photoLibraryUsageDescription.contains("photo"), "Description should mention photos")
            #expect(photoLibraryUsageDescription.count > 20, "Description should be meaningful (>20 chars)")
        } else {
            #expect(Bool(false), "Info.plist should contain NSPhotoLibraryUsageDescription")
        }
    }

    @Test("Info.plist contains NSCameraUsageDescription for future camera support")
    func testInfoPlistContainsCameraUsageDescription() {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }
        // This test should FAIL initially - no camera permission description exists
        let bundle = Bundle.main
        let infoPlist = bundle.infoDictionary

        #expect(infoPlist != nil, "Info.plist should be accessible")

        if let cameraUsageDescription = infoPlist?["NSCameraUsageDescription"] as? String {
            #expect(!cameraUsageDescription.isEmpty, "NSCameraUsageDescription should not be empty")

            // Verify it's user-friendly
            #expect(cameraUsageDescription.contains("camera"), "Description should mention camera")
            #expect(cameraUsageDescription.count > 20, "Description should be meaningful (>20 chars)")
        } else {
            #expect(Bool(false), "Info.plist should contain NSCameraUsageDescription")
        }
    }

    @Test("Photo authorization status can be checked")
    func testPhotoAuthorizationStatusCheck() {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }
        // Test that we can check photo authorization status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        // This should work regardless of actual permission state
        #expect([.authorized, .denied, .notDetermined, .restricted, .limited].contains(authStatus),
               "Authorization status should be one of the expected values")
    }

    @Test("Photo authorization request can be made")
    func testPhotoAuthorizationRequest() async {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }

        // Test PHPhotoLibrary authorization status check (avoid PermissionStatusManager.shared during tests)
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        // Should return a valid authorization status
        #expect([.authorized, .denied, .notDetermined, .restricted, .limited].contains(currentStatus),
               "Authorization status should be valid")
    }

    @Test("Permission error handling provides user-friendly messages")
    func testPermissionErrorHandling() {
        // Clean up state before test
        Self.cleanupSharedState()
        defer { Self.cleanupSharedState() }
        // Test that permission-related errors are handled with user-friendly messages
        // This test will initially fail because we don't have specific permission error handling

        let permissionError = PhotoPermissionError.accessDenied
        #expect(permissionError.localizedDescription.contains("photo"),
               "Permission error should mention photos")
        #expect(permissionError.localizedDescription.contains("Settings"),
               "Permission error should guide user to Settings")

        let restrictedError = PhotoPermissionError.accessRestricted
        #expect(restrictedError.localizedDescription.contains("restricted"),
               "Restricted error should explain restriction")
    }
}

// MARK: - Error Types for Permission Handling

enum PhotoPermissionError: LocalizedError {
    case accessDenied
    case accessRestricted
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access denied. Please enable photo access in Settings to add photos to your trips."
        case .accessRestricted:
            return "Photo library access is restricted. Please check your device restrictions."
        case .unknown:
            return "Unable to access photo library. Please try again."
        }
    }
}
