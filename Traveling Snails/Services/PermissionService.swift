//
//  PermissionService.swift
//  Traveling Snails
//
//

import Foundation
import Photos

/// Service protocol for managing system permissions
/// Abstracts various permission-related frameworks for testability
/// Sendable for safe concurrent access
protocol PermissionService: Sendable {
    /// Request photo library access permission
    /// - Parameter accessLevel: The level of access to request
    /// - Returns: The authorization status after the request
    func requestPhotoLibraryAccess(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus

    /// Get current photo library authorization status
    /// - Parameter accessLevel: The level of access to check
    /// - Returns: The current authorization status
    func getPhotoLibraryAuthorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus

    /// Request camera access permission
    /// - Returns: True if camera access is granted
    func requestCameraAccess() async -> Bool

    /// Get current camera authorization status
    /// - Returns: True if camera access is available
    func getCameraAuthorizationStatus() -> Bool

    /// Request microphone access permission
    /// - Returns: True if microphone access is granted
    func requestMicrophoneAccess() async -> Bool

    /// Get current microphone authorization status
    /// - Returns: True if microphone access is available
    func getMicrophoneAuthorizationStatus() -> Bool

    /// Request location access permission
    /// - Parameter usage: The type of location usage
    /// - Returns: The location authorization status
    func requestLocationAccess(for usage: LocationUsage) async -> LocationAuthorizationStatus

    /// Get current location authorization status
    /// - Returns: The current location authorization status
    func getLocationAuthorizationStatus() -> LocationAuthorizationStatus

    /// Open the app's settings page
    func openAppSettings()

    /// Check if a specific permission is required by the app
    /// - Parameter permission: The permission type to check
    /// - Returns: True if the permission is required
    func isPermissionRequired(_ permission: PermissionType) -> Bool
}

/// Types of permissions the app might need
enum PermissionType: CaseIterable {
    case photoLibraryRead
    case photoLibraryWrite
    case camera
    case microphone
    case locationWhenInUse
    case locationAlways

    var displayName: String {
        switch self {
        case .photoLibraryRead:
            return "Photo Library (Read)"
        case .photoLibraryWrite:
            return "Photo Library (Write)"
        case .camera:
            return "Camera"
        case .microphone:
            return "Microphone"
        case .locationWhenInUse:
            return "Location (When In Use)"
        case .locationAlways:
            return "Location (Always)"
        }
    }

    var description: String {
        switch self {
        case .photoLibraryRead:
            return "Access your photos to view trip memories"
        case .photoLibraryWrite:
            return "Save trip photos to your photo library"
        case .camera:
            return "Take photos during your trips"
        case .microphone:
            return "Record audio notes and memories"
        case .locationWhenInUse:
            return "Show your location on trip maps"
        case .locationAlways:
            return "Track your travel routes automatically"
        }
    }
}

/// Location usage types
enum LocationUsage {
    case whenInUse
    case always
}

/// Location authorization status
enum LocationAuthorizationStatus {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways

    var isAuthorized: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }

    var userFriendlyDescription: String {
        switch self {
        case .notDetermined:
            return "Permission not yet requested"
        case .denied:
            return "Access denied by user"
        case .restricted:
            return "Access restricted by system"
        case .authorizedWhenInUse:
            return "Authorized when app is in use"
        case .authorizedAlways:
            return "Always authorized"
        }
    }
}

/// Permission status information
struct PermissionStatus {
    let permission: PermissionType
    let isGranted: Bool
    let isRequired: Bool
    let userFriendlyStatus: String
    let canRequestAgain: Bool
}

/// Errors that can occur with permission requests
enum PermissionError: LocalizedError {
    case notSupported
    case alreadyDenied
    case restricted
    case temporarilyUnavailable
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "This permission is not supported on this device"
        case .alreadyDenied:
            return "Permission was previously denied. Please enable it in Settings."
        case .restricted:
            return "Permission is restricted by system policies"
        case .temporarilyUnavailable:
            return "Permission service is temporarily unavailable"
        case .unknown(let error):
            Logger.shared.error("Unknown permission error: \(error.localizedDescription)", category: .app)
            return L(L10n.Errors.permissionDenied)
        }
    }
}

/// Protocol for observing permission changes
protocol PermissionServiceObserver: AnyObject {
    func permissionService(_ service: PermissionService, didUpdatePermission permission: PermissionType, status: PermissionStatus)
}

/// Extended permission service protocol for advanced features
protocol AdvancedPermissionService: PermissionService {
    /// Get status for all permissions
    /// - Returns: Array of permission statuses
    func getAllPermissionStatuses() async -> [PermissionStatus]

    /// Add an observer for permission changes
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: PermissionServiceObserver)

    /// Remove an observer for permission changes
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: PermissionServiceObserver)

    /// Check if the app should show permission rationale
    /// - Parameter permission: The permission to check
    /// - Returns: True if rationale should be shown
    func shouldShowPermissionRationale(for permission: PermissionType) -> Bool

    /// Request multiple permissions at once
    /// - Parameter permissions: Array of permissions to request
    /// - Returns: Dictionary of permission results
    func requestMultiplePermissions(_ permissions: [PermissionType]) async -> [PermissionType: Bool]
}
