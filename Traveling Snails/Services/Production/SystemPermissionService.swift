//
//  SystemPermissionService.swift
//  Traveling Snails
//
//

import Foundation
import Photos
import CoreLocation
import AVFoundation
import UIKit
import os.lock

/// Production implementation of PermissionService using system frameworks
final class SystemPermissionService: NSObject, PermissionService, Sendable {
    
    // MARK: - Properties
    
    private let lock = OSAllocatedUnfairLock()
    
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var locationManager: CLLocationManager?
    nonisolated(unsafe) private var observers: [WeakPermissionServiceObserver] = []
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - PermissionService Implementation
    
    func requestPhotoLibraryAccess(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        return await withCheckedContinuation { continuation in
            if #available(iOS 14.0, *) {
                PHPhotoLibrary.requestAuthorization(for: accessLevel) { status in
                    Task { @MainActor in
                        self.notifyObservers(for: .photoLibraryRead, status: PermissionStatus(
                            permission: .photoLibraryRead,
                            isGranted: status.allowsPhotoAccess,
                            isRequired: self.isPermissionRequired(.photoLibraryRead),
                            userFriendlyStatus: status.userFriendlyDescription,
                            canRequestAgain: status == .notDetermined
                        ))
                    }
                    continuation.resume(returning: status)
                }
            } else {
                PHPhotoLibrary.requestAuthorization { status in
                    Task { @MainActor in
                        self.notifyObservers(for: .photoLibraryRead, status: PermissionStatus(
                            permission: .photoLibraryRead,
                            isGranted: status.allowsPhotoAccess,
                            isRequired: self.isPermissionRequired(.photoLibraryRead),
                            userFriendlyStatus: status.userFriendlyDescription,
                            canRequestAgain: status == .notDetermined
                        ))
                    }
                    continuation.resume(returning: status)
                }
            }
        }
    }
    
    func getPhotoLibraryAuthorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return PHPhotoLibrary.authorizationStatus(for: accessLevel)
        } else {
            return PHPhotoLibrary.authorizationStatus()
        }
    }
    
    func requestCameraAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.notifyObservers(for: .camera, status: PermissionStatus(
                        permission: .camera,
                        isGranted: granted,
                        isRequired: self.isPermissionRequired(.camera),
                        userFriendlyStatus: granted ? "Authorized" : "Denied",
                        canRequestAgain: false
                    ))
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    func getCameraAuthorizationStatus() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    func requestMicrophoneAccess() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    self.notifyObservers(for: .microphone, status: PermissionStatus(
                        permission: .microphone,
                        isGranted: granted,
                        isRequired: self.isPermissionRequired(.microphone),
                        userFriendlyStatus: granted ? "Authorized" : "Denied",
                        canRequestAgain: false
                    ))
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    func getMicrophoneAuthorizationStatus() -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        default:
            return false
        }
    }
    
    func requestLocationAccess(for usage: LocationUsage) async -> LocationAuthorizationStatus {
        guard let locationManager = lock.withLock({ locationManager }) else {
            return .denied
        }
        
        // Check if location services are enabled globally
        guard CLLocationManager.locationServicesEnabled() else {
            return .denied
        }
        
        let currentStatus = getLocationAuthorizationStatus()
        
        // If already determined, return current status
        if currentStatus != .notDetermined {
            return currentStatus
        }
        
        // Request appropriate permission
        return await withCheckedContinuation { continuation in
            // Store continuation for delegate callback
            lock.withLock { self.locationContinuation = continuation }
            
            switch usage {
            case .whenInUse:
                locationManager.requestWhenInUseAuthorization()
            case .always:
                locationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    func getLocationAuthorizationStatus() -> LocationAuthorizationStatus {
        guard let locationManager = lock.withLock({ locationManager }) else {
            return .denied
        }
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted, .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .denied
        }
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            Logger.shared.warning("Failed to create Settings URL")
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        } else {
            Logger.shared.warning("Cannot open Settings URL")
        }
    }
    
    func isPermissionRequired(_ permission: PermissionType) -> Bool {
        // Check Info.plist for usage descriptions to determine if permission is required
        let bundle = Bundle.main
        
        switch permission {
        case .photoLibraryRead, .photoLibraryWrite:
            return bundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
        case .camera:
            return bundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") != nil
        case .microphone:
            return bundle.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil
        case .locationWhenInUse:
            return bundle.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil
        case .locationAlways:
            return bundle.object(forInfoDictionaryKey: "NSLocationAlwaysAndWhenInUseUsageDescription") != nil
        }
    }
    
    // MARK: - Private Implementation
    
    nonisolated(unsafe) private var locationContinuation: CheckedContinuation<LocationAuthorizationStatus, Never>?
    
    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        lock.withLock { locationManager = manager }
    }
    
    private func notifyObservers(for permission: PermissionType, status: PermissionStatus) {
        // Clean up nil observers and get current list
        let currentObservers = lock.withLock {
            observers = observers.filter { $0.observer != nil }
            return observers
        }
        
        for weakObserver in currentObservers {
            weakObserver.observer?.permissionService(self, didUpdatePermission: permission, status: status)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SystemPermissionService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = getLocationAuthorizationStatus()
        
        // Notify observers
        let permissionStatus = PermissionStatus(
            permission: .locationWhenInUse, // This could be more specific based on what was requested
            isGranted: status.isAuthorized,
            isRequired: isPermissionRequired(.locationWhenInUse),
            userFriendlyStatus: status.userFriendlyDescription,
            canRequestAgain: status == .notDetermined
        )
        
        notifyObservers(for: .locationWhenInUse, status: permissionStatus)
        
        // Resume any pending continuation
        let continuation = lock.withLock {
            let cont = locationContinuation
            locationContinuation = nil
            return cont
        }
        continuation?.resume(returning: status)
    }
}

// MARK: - AdvancedPermissionService Implementation

extension SystemPermissionService: AdvancedPermissionService {
    
    func getAllPermissionStatuses() async -> [PermissionStatus] {
        var statuses: [PermissionStatus] = []
        
        // Photo Library (Read)
        let photoReadStatus = getPhotoLibraryAuthorizationStatus(for: .readWrite)
        statuses.append(PermissionStatus(
            permission: .photoLibraryRead,
            isGranted: photoReadStatus.allowsPhotoAccess,
            isRequired: isPermissionRequired(.photoLibraryRead),
            userFriendlyStatus: photoReadStatus.userFriendlyDescription,
            canRequestAgain: photoReadStatus == .notDetermined
        ))
        
        // Photo Library (Write)
        statuses.append(PermissionStatus(
            permission: .photoLibraryWrite,
            isGranted: photoReadStatus.allowsAddingPhotos,
            isRequired: isPermissionRequired(.photoLibraryWrite),
            userFriendlyStatus: photoReadStatus.userFriendlyDescription,
            canRequestAgain: photoReadStatus == .notDetermined
        ))
        
        // Camera
        let cameraGranted = getCameraAuthorizationStatus()
        statuses.append(PermissionStatus(
            permission: .camera,
            isGranted: cameraGranted,
            isRequired: isPermissionRequired(.camera),
            userFriendlyStatus: cameraGranted ? "Authorized" : "Not Authorized",
            canRequestAgain: AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
        ))
        
        // Microphone
        let microphoneGranted = getMicrophoneAuthorizationStatus()
        statuses.append(PermissionStatus(
            permission: .microphone,
            isGranted: microphoneGranted,
            isRequired: isPermissionRequired(.microphone),
            userFriendlyStatus: microphoneGranted ? "Authorized" : "Not Authorized",
            canRequestAgain: AVAudioApplication.shared.recordPermission == .undetermined
        ))
        
        // Location When In Use
        let locationStatus = getLocationAuthorizationStatus()
        statuses.append(PermissionStatus(
            permission: .locationWhenInUse,
            isGranted: locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways,
            isRequired: isPermissionRequired(.locationWhenInUse),
            userFriendlyStatus: locationStatus.userFriendlyDescription,
            canRequestAgain: locationStatus == .notDetermined
        ))
        
        // Location Always
        statuses.append(PermissionStatus(
            permission: .locationAlways,
            isGranted: locationStatus == .authorizedAlways,
            isRequired: isPermissionRequired(.locationAlways),
            userFriendlyStatus: locationStatus.userFriendlyDescription,
            canRequestAgain: locationStatus == .notDetermined
        ))
        
        return statuses
    }
    
    func addObserver(_ observer: PermissionServiceObserver) {
        lock.withLock { observers.append(WeakPermissionServiceObserver(observer)) }
    }
    
    func removeObserver(_ observer: PermissionServiceObserver) {
        lock.withLock { observers.removeAll { $0.observer === observer } }
    }
    
    func shouldShowPermissionRationale(for permission: PermissionType) -> Bool {
        // iOS doesn't provide a direct way to check if rationale should be shown
        // This is more relevant for Android, but we can implement some logic
        switch permission {
        case .photoLibraryRead, .photoLibraryWrite:
            return getPhotoLibraryAuthorizationStatus(for: .readWrite) == .denied
        case .camera:
            return AVCaptureDevice.authorizationStatus(for: .video) == .denied
        case .microphone:
            return AVAudioApplication.shared.recordPermission == .denied
        case .locationWhenInUse, .locationAlways:
            let status = getLocationAuthorizationStatus()
            return status == .denied
        }
    }
    
    func requestMultiplePermissions(_ permissions: [PermissionType]) async -> [PermissionType: Bool] {
        var results: [PermissionType: Bool] = [:]
        
        for permission in permissions {
            switch permission {
            case .photoLibraryRead:
                let status = await requestPhotoLibraryAccess(for: .readWrite)
                results[permission] = status.allowsPhotoAccess
            case .photoLibraryWrite:
                let status = await requestPhotoLibraryAccess(for: .readWrite)
                results[permission] = status.allowsAddingPhotos
            case .camera:
                results[permission] = await requestCameraAccess()
            case .microphone:
                results[permission] = await requestMicrophoneAccess()
            case .locationWhenInUse:
                let status = await requestLocationAccess(for: .whenInUse)
                results[permission] = status.isAuthorized
            case .locationAlways:
                let status = await requestLocationAccess(for: .always)
                results[permission] = status == .authorizedAlways
            }
        }
        
        return results
    }
}

// MARK: - Weak Observer Wrapper

private struct WeakPermissionServiceObserver {
    weak var observer: PermissionServiceObserver?
    
    init(_ observer: PermissionServiceObserver) {
        self.observer = observer
    }
}