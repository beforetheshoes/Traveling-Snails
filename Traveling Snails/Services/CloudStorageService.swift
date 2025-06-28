//
//  CloudStorageService.swift
//  Traveling Snails
//
//

import Foundation

/// Service protocol for cloud-based key-value storage
/// Abstracts NSUbiquitousKeyValueStore for testability
/// Sendable for safe concurrent access
protocol CloudStorageService: Sendable {
    /// Store a string value for a key
    /// - Parameters:
    ///   - value: The string value to store
    ///   - key: The key to associate with the value
    func setString(_ value: String, forKey key: String)
    
    /// Retrieve a string value for a key
    /// - Parameter key: The key to look up
    /// - Returns: The stored string value, or nil if not found
    func getString(forKey key: String) -> String?
    
    /// Store an integer value for a key
    /// - Parameters:
    ///   - value: The integer value to store
    ///   - key: The key to associate with the value
    func setInteger(_ value: Int, forKey key: String)
    
    /// Retrieve an integer value for a key
    /// - Parameter key: The key to look up
    /// - Returns: The stored integer value, or 0 if not found
    func getInteger(forKey key: String) -> Int
    
    /// Store a boolean value for a key
    /// - Parameters:
    ///   - value: The boolean value to store
    ///   - key: The key to associate with the value
    func setBoolean(_ value: Bool, forKey key: String)
    
    /// Retrieve a boolean value for a key
    /// - Parameter key: The key to look up
    /// - Returns: The stored boolean value, or false if not found
    func getBoolean(forKey key: String) -> Bool
    
    /// Store a double value for a key
    /// - Parameters:
    ///   - value: The double value to store
    ///   - key: The key to associate with the value
    func setDouble(_ value: Double, forKey key: String)
    
    /// Retrieve a double value for a key
    /// - Parameter key: The key to look up
    /// - Returns: The stored double value, or 0.0 if not found
    func getDouble(forKey key: String) -> Double
    
    /// Remove a value for a key
    /// - Parameter key: The key to remove
    func removeValue(forKey key: String)
    
    /// Force synchronization with cloud storage
    /// - Returns: True if synchronization was successful
    @discardableResult
    func synchronize() -> Bool
    
    /// Whether cloud storage is available
    var isAvailable: Bool { get }
}

/// Notification names for cloud storage changes
extension Notification.Name {
    static let cloudStorageDidChangeExternally = Notification.Name("CloudStorageDidChangeExternally")
}

/// Keys for cloud storage change notifications
struct CloudStorageNotificationKey {
    static let changedKeys = "changedKeys"
    static let reasonForChange = "reasonForChange"
}

/// Reasons for cloud storage changes
enum CloudStorageChangeReason: Int {
    case serverChange = 0
    case initialSyncChange = 1
    case quotaViolationChange = 2
    case accountChange = 3
}

/// Errors that can occur with cloud storage
enum CloudStorageError: LocalizedError {
    case notAvailable
    case quotaExceeded
    case accountNotAvailable
    case networkUnavailable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Cloud storage is not available"
        case .quotaExceeded:
            return "Cloud storage quota has been exceeded"
        case .accountNotAvailable:
            return "No iCloud account is available"
        case .networkUnavailable:
            return "Network is unavailable for cloud storage"
        case .unknown(let error):
            return "Unknown cloud storage error: \(error.localizedDescription)"
        }
    }
}