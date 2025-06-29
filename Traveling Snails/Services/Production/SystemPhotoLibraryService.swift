//
//  SystemPhotoLibraryService.swift
//  Traveling Snails
//
//

import Foundation
import Photos
import UIKit

/// Production implementation of PhotoLibraryService using PHPhotoLibrary
/// PHPhotoLibrary is thread-safe, so this service is naturally Sendable
final class SystemPhotoLibraryService: PhotoLibraryService, Sendable {
    // MARK: - Properties

    private let photoLibrary: PHPhotoLibrary

    // MARK: - Initialization

    init() {
        self.photoLibrary = PHPhotoLibrary.shared()
    }

    // MARK: - PhotoLibraryService Implementation

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return PHPhotoLibrary.authorizationStatus(for: accessLevel)
        } else {
            // Fallback for iOS 13 and earlier
            return PHPhotoLibrary.authorizationStatus()
        }
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            if #available(iOS 14.0, *) {
                PHPhotoLibrary.requestAuthorization(for: accessLevel) { status in
                    continuation.resume(returning: status)
                }
            } else {
                // Fallback for iOS 13 and earlier
                PHPhotoLibrary.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    func presentLimitedLibraryPicker(from viewController: UIViewController?) {
        guard #available(iOS 14.0, *) else {
            Logger.shared.warning("Limited library picker is only available on iOS 14+")
            return
        }

        guard let viewController = viewController else {
            Logger.shared.warning("No view controller provided for limited library picker")
            return
        }

        photoLibrary.presentLimitedLibraryPicker(from: viewController)
    }

    var preventsAutomaticLimitedAccessAlert: Bool {
        get {
            if #available(iOS 14.0, *) {
                // Check Info.plist setting
                return Bundle.main.object(forInfoDictionaryKey: "PHPhotoLibraryPreventAutomaticLimitedAccessAlert") as? Bool ?? false
            } else {
                return false
            }
        }
        set {
            // This property is read-only and set via Info.plist
            Logger.shared.warning("preventsAutomaticLimitedAccessAlert is read-only and must be set in Info.plist")
        }
    }

    func register(_ observer: PHPhotoLibraryChangeObserver) {
        photoLibrary.register(observer)
    }

    func unregister(_ observer: PHPhotoLibraryChangeObserver) {
        photoLibrary.unregisterChangeObserver(observer)
    }
}

// MARK: - Convenience Extensions

extension SystemPhotoLibraryService {
    /// Check if the app has any level of photo library access
    var hasPhotoAccess: Bool {
        let status = authorizationStatus(for: .readWrite)
        return status.allowsPhotoAccess
    }

    /// Check if the app has full photo library access
    var hasFullPhotoAccess: Bool {
        let status = authorizationStatus(for: .readWrite)
        return status == .authorized
    }

    /// Check if the app has limited photo library access
    var hasLimitedPhotoAccess: Bool {
        let status = authorizationStatus(for: .readWrite)
        return status == .limited
    }

    /// Request read-write access to the photo library
    func requestReadWriteAccess() async -> PHAuthorizationStatus {
        await requestAuthorization(for: .readWrite)
    }

    /// Request add-only access to the photo library
    func requestAddOnlyAccess() async -> PHAuthorizationStatus {
        await requestAuthorization(for: .addOnly)
    }

    /// Get user-friendly status description
    func getStatusDescription(for accessLevel: PHAccessLevel) -> String {
        let status = authorizationStatus(for: accessLevel)
        return status.userFriendlyDescription
    }
}

// MARK: - Error Handling

extension SystemPhotoLibraryService {
    /// Convert PHAuthorizationStatus to PhotoLibraryError
    func error(from status: PHAuthorizationStatus) -> PhotoLibraryError? {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .accessRestricted
        case .denied:
            return .accessDenied
        case .limited:
            return .limitedAccess
        case .authorized:
            return nil // No error
        @unknown default:
            return .unknown
        }
    }

    /// Get PhotoLibraryError for current status
    func getCurrentError(for accessLevel: PHAccessLevel) -> PhotoLibraryError? {
        let status = authorizationStatus(for: accessLevel)
        return error(from: status)
    }
}
