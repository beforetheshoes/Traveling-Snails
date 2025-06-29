//
//  PermissionStatusManager.swift
//  Traveling Snails
//
//

import Photos
import SwiftUI

@Observable
@MainActor
class PermissionStatusManager {
    static let shared = PermissionStatusManager()

    private init() {}

    // MARK: - Photo Library Permission Management

    var photoLibraryAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    var canUsePhotoLibrary: Bool {
        switch photoLibraryAuthorizationStatus {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    var photoLibraryPermissionMessage: String {
        switch photoLibraryAuthorizationStatus {
        case .authorized:
            return "Photo library access is granted"
        case .limited:
            return "Limited photo library access is granted"
        case .denied:
            return "Photo library access is denied. Please enable access in Settings to add photos to your trips."
        case .restricted:
            return "Photo library access is restricted. Please check your device restrictions."
        case .notDetermined:
            return "Photo library permission has not been requested yet"
        @unknown default:
            return "Photo library permission status is unknown"
        }
    }

    // MARK: - Permission Request Methods

    nonisolated func requestPhotoLibraryAccess() async -> PHAuthorizationStatus {
        // Skip photo permission prompts during testing to prevent hanging
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            // Return .authorized in test environment to avoid blocking tests
            return .authorized
        }

        return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    // MARK: - Settings Navigation

    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }

    // MARK: - Permission Status Checking

    func checkPhotoLibraryPermission() -> LegacyPermissionStatus {
        switch photoLibraryAuthorizationStatus {
        case .authorized:
            return .granted
        case .limited:
            return .limited
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .unknown
        }
    }
}

// MARK: - Supporting Types

enum LegacyPermissionStatus {
    case granted
    case limited
    case denied
    case restricted
    case notDetermined
    case unknown

    var userFriendlyDescription: String {
        switch self {
        case .granted:
            return "Access granted"
        case .limited:
            return "Limited access granted"
        case .denied:
            return "Access denied - please enable in Settings"
        case .restricted:
            return "Access restricted by device settings"
        case .notDetermined:
            return "Permission not yet requested"
        case .unknown:
            return "Permission status unknown"
        }
    }
}
