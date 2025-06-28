//
//  MockPhotoLibraryService.swift
//  Traveling Snails
//
//

import Foundation
import Photos
import UIKit
import os.lock

/// Mock implementation of PhotoLibraryService for testing
/// Provides fake photo library operations without system permission dialogs
final class MockPhotoLibraryService: PhotoLibraryService, Sendable {
    
    // MARK: - Thread-Safe Storage
    private let lock = OSAllocatedUnfairLock()
    
    // MARK: - Mock Configuration (Thread-Safe)
    // nonisolated(unsafe) is appropriate here because we use OSAllocatedUnfairLock for synchronization
    nonisolated(unsafe) private var _mockAuthorizationStatus: PHAuthorizationStatus = .authorized
    nonisolated(unsafe) private var _mockRequestAuthorizationResult: PHAuthorizationStatus = .authorized
    nonisolated(unsafe) private var _mockRequestDelay: TimeInterval = 0.1
    nonisolated(unsafe) private var _requestAuthorizationCallCount: Int = 0
    nonisolated(unsafe) private var _limitedPickerCallCount: Int = 0
    nonisolated(unsafe) private var _observerRegistrationCount: Int = 0
    
    
    // MARK: - Initialization
    
    init() {
        // Mock service starts in clean state
    }
    
    // MARK: - Thread-Safe Configuration Accessors
    
    var mockAuthorizationStatus: PHAuthorizationStatus {
        get { lock.withLock { _mockAuthorizationStatus } }
        set { lock.withLock { _mockAuthorizationStatus = newValue } }
    }
    
    var mockRequestAuthorizationResult: PHAuthorizationStatus {
        get { lock.withLock { _mockRequestAuthorizationResult } }
        set { lock.withLock { _mockRequestAuthorizationResult = newValue } }
    }
    
    var mockRequestDelay: TimeInterval {
        get { lock.withLock { _mockRequestDelay } }
        set { lock.withLock { _mockRequestDelay = newValue } }
    }
    
    var requestAuthorizationCallCount: Int {
        lock.withLock { _requestAuthorizationCallCount }
    }
    
    var limitedPickerCallCount: Int {
        lock.withLock { _limitedPickerCallCount }
    }
    
    var observerRegistrationCount: Int {
        lock.withLock { _observerRegistrationCount }
    }
    
    // MARK: - PhotoLibraryService Implementation
    
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus {
        return mockAuthorizationStatus
    }
    
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        // Simulate permission request delay
        let delay = lock.withLock { _mockRequestDelay }
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        // Track call count
        lock.withLock { _requestAuthorizationCallCount += 1 }
        
        // Update mock status to match request result
        let result = lock.withLock { _mockRequestAuthorizationResult }
        lock.withLock { _mockAuthorizationStatus = result }
        
        return result
    }
    
    func presentLimitedLibraryPicker(from viewController: UIViewController?) {
        // Mock implementation - just track the call for verification
        lock.withLock { _limitedPickerCallCount += 1 }
    }
    
    nonisolated(unsafe) var preventsAutomaticLimitedAccessAlert: Bool = false
    
    func register(_ observer: PHPhotoLibraryChangeObserver) {
        // Mock implementation - track observer registration
        lock.withLock { _observerRegistrationCount += 1 }
    }
    
    func unregister(_ observer: PHPhotoLibraryChangeObserver) {
        // Mock implementation - track observer unregistration
        lock.withLock { _observerRegistrationCount = max(0, _observerRegistrationCount - 1) }
    }
    
    // MARK: - Mock Control Methods
    
    /// Configure mock to simulate authorized photo library access
    func configureAuthorized() {
        lock.withLock {
            _mockAuthorizationStatus = .authorized
            _mockRequestAuthorizationResult = .authorized
        }
    }
    
    /// Configure mock to simulate denied photo library access
    func configureDenied() {
        lock.withLock {
            _mockAuthorizationStatus = .denied
            _mockRequestAuthorizationResult = .denied
        }
    }
    
    /// Configure mock to simulate restricted photo library access
    func configureRestricted() {
        lock.withLock {
            _mockAuthorizationStatus = .restricted
            _mockRequestAuthorizationResult = .restricted
        }
    }
    
    /// Configure mock to simulate limited photo library access
    func configureLimited() {
        lock.withLock {
            _mockAuthorizationStatus = .limited
            _mockRequestAuthorizationResult = .limited
        }
    }
    
    /// Reset mock to clean state for next test
    func resetForTesting() {
        lock.withLock {
            _mockAuthorizationStatus = .authorized
            _mockRequestAuthorizationResult = .authorized
            _mockRequestDelay = 0.1
            
            _requestAuthorizationCallCount = 0
            _limitedPickerCallCount = 0
            _observerRegistrationCount = 0
        }
        preventsAutomaticLimitedAccessAlert = false
    }
    
    /// Get request authorization call count (for test verification)
    func getRequestAuthorizationCallCount() -> Int {
        return requestAuthorizationCallCount
    }
    
    /// Get limited picker call count (for test verification)
    func getLimitedPickerCallCount() -> Int {
        return limitedPickerCallCount
    }
    
    /// Get observer registration count (for test verification)
    func getObserverRegistrationCount() -> Int {
        return observerRegistrationCount
    }
}

// MARK: - Mock Photo Error Types

enum MockPhotoError: Error, LocalizedError {
    case accessDenied
    case accessRestricted
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access was denied"
        case .accessRestricted:
            return "Photo library access is restricted"
        case .unknown:
            return "An unknown photo library error occurred"
        }
    }
}

// MARK: - Test Helper Extensions

extension MockPhotoLibraryService {
    
    /// Create a pre-configured mock for authorized photo library access
    static func authorized() -> MockPhotoLibraryService {
        let mock = MockPhotoLibraryService()
        mock.configureAuthorized()
        return mock
    }
    
    /// Create a pre-configured mock for denied photo library access
    static func denied() -> MockPhotoLibraryService {
        let mock = MockPhotoLibraryService()
        mock.configureDenied()
        return mock
    }
    
    /// Create a pre-configured mock for restricted photo library access
    static func restricted() -> MockPhotoLibraryService {
        let mock = MockPhotoLibraryService()
        mock.configureRestricted()
        return mock
    }
    
    /// Create a pre-configured mock for limited photo library access
    static func limited() -> MockPhotoLibraryService {
        let mock = MockPhotoLibraryService()
        mock.configureLimited()
        return mock
    }
    
}