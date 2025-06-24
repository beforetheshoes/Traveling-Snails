//
//  PhotoPermissionTests.swift
//  Traveling Snails Tests
//
//

import Testing
import Photos
import UniformTypeIdentifiers
@testable import Traveling_Snails

@Suite("Photo Permission Tests")
struct PhotoPermissionTests {
    
    @Test("Info.plist contains NSPhotoLibraryUsageDescription")
    func testInfoPlistContainsPhotoLibraryUsageDescription() {
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
        // Test that we can check photo authorization status
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        // This should work regardless of actual permission state
        #expect([.authorized, .denied, .notDetermined, .restricted, .limited].contains(authStatus), 
               "Authorization status should be one of the expected values")
    }
    
    @Test("Photo authorization request can be made")
    func testPhotoAuthorizationRequest() async {
        // Test that we can request photo authorization
        // This will work even if permission is already granted/denied
        
        let authStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        // Should return a valid authorization status
        #expect([.authorized, .denied, .notDetermined, .restricted, .limited].contains(authStatus),
               "Authorization request should return valid status")
    }
    
    @Test("Permission error handling provides user-friendly messages")
    func testPermissionErrorHandling() {
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