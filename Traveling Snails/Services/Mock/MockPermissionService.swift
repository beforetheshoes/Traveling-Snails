//
//  MockPermissionService.swift
//  Traveling Snails
//
//

import Foundation
import Photos
import os.lock

/// Mock implementation of PermissionService for testing
/// Provides controllable permission states without system permission dialogs
final class MockPermissionService: PermissionService, Sendable {
    
    // MARK: - Thread-Safe Storage
    private let lock = OSAllocatedUnfairLock()
    
    // MARK: - Mock Configuration (Thread-Safe)
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var _mockPhotoLibraryStatus: PHAuthorizationStatus = .authorized
    nonisolated(unsafe) private var _mockCameraAuthorized: Bool = true
    nonisolated(unsafe) private var _mockMicrophoneAuthorized: Bool = true
    nonisolated(unsafe) private var _mockLocationAuthorizationStatus: LocationAuthorizationStatus = .authorizedWhenInUse
    nonisolated(unsafe) private var _requestResults: [PermissionType: Bool] = [:]
    nonisolated(unsafe) private var _requiredPermissions: Set<PermissionType> = []
    nonisolated(unsafe) private var _mockRequestDelay: TimeInterval = 0.1
    nonisolated(unsafe) private var _requestCallCounts: [String: Int] = [:]
    
    
    // MARK: - Initialization
    
    init() {
        // Mock service starts with all permissions granted
    }
    
    // MARK: - Thread-Safe Configuration Accessors
    
    var mockPhotoLibraryStatus: PHAuthorizationStatus {
        get { lock.withLock { _mockPhotoLibraryStatus } }
        set { lock.withLock { _mockPhotoLibraryStatus = newValue } }
    }
    
    var mockCameraAuthorized: Bool {
        get { lock.withLock { _mockCameraAuthorized } }
        set { lock.withLock { _mockCameraAuthorized = newValue } }
    }
    
    var mockMicrophoneAuthorized: Bool {
        get { lock.withLock { _mockMicrophoneAuthorized } }
        set { lock.withLock { _mockMicrophoneAuthorized = newValue } }
    }
    
    var mockLocationAuthorizationStatus: LocationAuthorizationStatus {
        get { lock.withLock { _mockLocationAuthorizationStatus } }
        set { lock.withLock { _mockLocationAuthorizationStatus = newValue } }
    }
    
    var mockRequestDelay: TimeInterval {
        get { lock.withLock { _mockRequestDelay } }
        set { lock.withLock { _mockRequestDelay = newValue } }
    }
    
    // MARK: - PermissionService Implementation
    
    func requestPhotoLibraryAccess(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        await performMockRequest(key: "photoLibrary")
        return mockPhotoLibraryStatus
    }
    
    func getPhotoLibraryAuthorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        return mockPhotoLibraryStatus
    }
    
    func requestCameraAccess() async -> Bool {
        await performMockRequest(key: "camera")
        return mockCameraAuthorized
    }
    
    func getCameraAuthorizationStatus() -> Bool {
        return mockCameraAuthorized
    }
    
    func requestMicrophoneAccess() async -> Bool {
        await performMockRequest(key: "microphone")
        return mockMicrophoneAuthorized
    }
    
    func getMicrophoneAuthorizationStatus() -> Bool {
        return mockMicrophoneAuthorized
    }
    
    func requestLocationAccess(for usage: LocationUsage) async -> LocationAuthorizationStatus {
        let key = usage == .always ? "locationAlways" : "locationWhenInUse"
        await performMockRequest(key: key)
        return mockLocationAuthorizationStatus
    }
    
    func getLocationAuthorizationStatus() -> LocationAuthorizationStatus {
        return mockLocationAuthorizationStatus
    }
    
    func openAppSettings() {
        // Mock implementation - track the call for verification
        lock.withLock { _requestCallCounts["openAppSettings", default: 0] += 1 }
    }
    
    func isPermissionRequired(_ permission: PermissionType) -> Bool {
        return lock.withLock { _requiredPermissions.contains(permission) }
    }
    
    // MARK: - Private Helper Methods
    
    private func performMockRequest(key: String) async {
        // Simulate request delay
        let delay = lock.withLock { _mockRequestDelay }
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Track call count
        lock.withLock { _requestCallCounts[key, default: 0] += 1 }
    }
    
    // MARK: - Mock Control Methods
    
    /// Set photo library authorization status
    func setPhotoLibraryStatus(_ status: PHAuthorizationStatus) {
        mockPhotoLibraryStatus = status
    }
    
    /// Set camera authorization status
    func setCameraAuthorized(_ authorized: Bool) {
        mockCameraAuthorized = authorized
    }
    
    /// Set microphone authorization status
    func setMicrophoneAuthorized(_ authorized: Bool) {
        mockMicrophoneAuthorized = authorized
    }
    
    /// Set location authorization status
    func setLocationAuthorizationStatus(_ status: LocationAuthorizationStatus) {
        mockLocationAuthorizationStatus = status
    }
    
    /// Set whether a permission is required
    func setPermissionRequired(_ permission: PermissionType, required: Bool) {
        lock.withLock {
            if required {
                _requiredPermissions.insert(permission)
            } else {
                _requiredPermissions.remove(permission)
            }
        }
    }
    
    /// Configure mock to grant all permissions
    func configureAllPermissionsGranted() {
        lock.withLock {
            _mockPhotoLibraryStatus = .authorized
            _mockCameraAuthorized = true
            _mockMicrophoneAuthorized = true
            _mockLocationAuthorizationStatus = .authorizedWhenInUse
        }
    }
    
    /// Configure mock to deny all permissions
    func configureAllPermissionsDenied() {
        lock.withLock {
            _mockPhotoLibraryStatus = .denied
            _mockCameraAuthorized = false
            _mockMicrophoneAuthorized = false
            _mockLocationAuthorizationStatus = .denied
        }
    }
    
    /// Configure realistic permission scenario (photo/camera granted, others restricted)
    func configureRealisticPermissions() {
        lock.withLock {
            _mockPhotoLibraryStatus = .authorized
            _mockCameraAuthorized = true
            _mockMicrophoneAuthorized = false
            _mockLocationAuthorizationStatus = .denied
        }
    }
    
    /// Reset mock to clean state for next test
    func resetForTesting() {
        lock.withLock {
            _mockPhotoLibraryStatus = .authorized
            _mockCameraAuthorized = true
            _mockMicrophoneAuthorized = true
            _mockLocationAuthorizationStatus = .authorizedWhenInUse
            
            _requestResults.removeAll()
            _requiredPermissions.removeAll()
            _requestCallCounts.removeAll()
            
            _mockRequestDelay = 0.1
        }
    }
    
    /// Get request call count for a specific permission (for test verification)
    func getRequestCallCount(for key: String) -> Int {
        return lock.withLock { _requestCallCounts[key] ?? 0 }
    }
    
    /// Get total request call count across all permissions
    func getTotalRequestCallCount() -> Int {
        return lock.withLock { _requestCallCounts.values.reduce(0, +) }
    }
    
    /// Check if a specific permission was requested (for test verification)
    func wasPermissionRequested(_ key: String) -> Bool {
        return getRequestCallCount(for: key) > 0
    }
    
    /// Get count of openAppSettings calls
    func getOpenAppSettingsCallCount() -> Int {
        return getRequestCallCount(for: "openAppSettings")
    }
}

// MARK: - Test Helper Extensions

extension MockPermissionService {
    
    /// Create a pre-configured mock with all permissions granted
    static func allGranted() -> MockPermissionService {
        let mock = MockPermissionService()
        mock.configureAllPermissionsGranted()
        return mock
    }
    
    /// Create a pre-configured mock with all permissions denied
    static func allDenied() -> MockPermissionService {
        let mock = MockPermissionService()
        mock.configureAllPermissionsDenied()
        return mock
    }
    
    /// Create a pre-configured mock with realistic permission scenario
    static func realistic() -> MockPermissionService {
        let mock = MockPermissionService()
        mock.configureRealisticPermissions()
        return mock
    }
    
    /// Create a pre-configured mock with specific permission configuration
    static func with(
        photoLibrary: PHAuthorizationStatus = .authorized,
        camera: Bool = true,
        microphone: Bool = false,
        location: LocationAuthorizationStatus = .denied
    ) -> MockPermissionService {
        let mock = MockPermissionService()
        mock.setPhotoLibraryStatus(photoLibrary)
        mock.setCameraAuthorized(camera)
        mock.setMicrophoneAuthorized(microphone)
        mock.setLocationAuthorizationStatus(location)
        return mock
    }
}