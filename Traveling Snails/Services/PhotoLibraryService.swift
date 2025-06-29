//
//  PhotoLibraryService.swift
//  Traveling Snails
//
//

import Foundation
import Photos
import UIKit

/// Service protocol for photo library access and permissions
/// Abstracts PHPhotoLibrary for testability
/// Sendable for safe concurrent access
protocol PhotoLibraryService: Sendable {
    /// Current authorization status for photo library access
    /// - Parameter accessLevel: The level of access requested (.addOnly or .readWrite)
    /// - Returns: The current authorization status
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus

    /// Request authorization for photo library access
    /// - Parameter accessLevel: The level of access to request
    /// - Returns: The authorization status after the request
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus

    /// Present the limited library picker (iOS 14+)
    /// - Parameter viewController: The view controller to present from
    func presentLimitedLibraryPicker(from viewController: UIViewController?)

    /// Whether the app should prevent automatic limited access alerts
    var preventsAutomaticLimitedAccessAlert: Bool { get set }

    /// Register for photo library change notifications
    /// - Parameter observer: The observer to register
    func register(_ observer: PHPhotoLibraryChangeObserver)

    /// Unregister from photo library change notifications
    /// - Parameter observer: The observer to unregister
    func unregister(_ observer: PHPhotoLibraryChangeObserver)
}

/// Errors that can occur with photo library access
enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case accessRestricted
    case limitedAccess
    case notDetermined
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access denied. Please enable photo access in Settings to add photos to your trips."
        case .accessRestricted:
            return "Photo library access is restricted. Please check your device restrictions."
        case .limitedAccess:
            return "Photo library access is limited. You can select more photos in Settings."
        case .notDetermined:
            return "Photo library permission has not been determined. Please grant permission to continue."
        case .unknown:
            return "Unable to access photo library. Please try again."
        }
    }
}

/// Extension to make PHAuthorizationStatus more convenient
extension PHAuthorizationStatus {
    /// Whether the current status allows reading photos
    var allowsPhotoAccess: Bool {
        switch self {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// Whether the current status allows adding photos
    var allowsAddingPhotos: Bool {
        switch self {
        case .authorized:
            return true
        case .limited, .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    /// User-friendly description of the authorization status
    var userFriendlyDescription: String {
        switch self {
        case .notDetermined:
            return "Permission not yet requested"
        case .restricted:
            return "Access restricted by system"
        case .denied:
            return "Access denied by user"
        case .authorized:
            return "Full access granted"
        case .limited:
            return "Limited access granted"
        @unknown default:
            return "Unknown authorization status"
        }
    }
}
