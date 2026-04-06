//
//  CloudKitErrorHandler.swift
//  Traveling Snails
//
//  Handles CloudKit sync errors and provides recovery options
//

import CloudKit
import Foundation

final class CloudKitErrorHandler: @unchecked Swift.Sendable {
    static let shared = CloudKitErrorHandler()
    
    private init() {}
    
    /// Handles CloudKit sync errors and determines if recovery is possible
    func handleSyncError(_ error: any Error) -> CloudKitRecoveryAction {
        if let nsError = error as NSError? {
            // Check for specific CloudKit data type mismatch errors
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 134420 {
                if let underlyingException = nsError.userInfo["NSUnderlyingException"] as? String,
                   underlyingException.contains("Unacceptable type of value for attribute") {
                    return .requiresSchemaReset
                }
            }
            
            // Check for other CloudKit-specific errors
            if let cloudKitError = error as? CKError {
                switch cloudKitError.code {
                case .internalError, .serverRejectedRequest:
                    return .requiresSchemaReset
                case .networkUnavailable, .networkFailure:
                    return .retryLater
                case .quotaExceeded:
                    return .quotaExceeded
                case .zoneNotFound, .userDeletedZone:
                    return .requiresSchemaReset
                default:
                    return .unknown
                }
            }
        }
        
        return .unknown
    }
    
    /// Provides user-friendly error messages for CloudKit issues
    func userFriendlyMessage(for action: CloudKitRecoveryAction) -> String {
        switch action {
        case .requiresSchemaReset:
            return "CloudKit data needs to be reset due to a schema change. Go to Settings > Debug > Reset CloudKit Sync to fix this."
        case .retryLater:
            return "Network issue detected. CloudKit sync will retry automatically when connection improves."
        case .quotaExceeded:
            return "iCloud storage quota exceeded. Free up iCloud storage space to continue syncing."
        case .unknown:
            return "CloudKit sync encountered an issue. Try resetting CloudKit sync in Settings if the problem persists."
        }
    }
}

enum CloudKitRecoveryAction {
    case requiresSchemaReset
    case retryLater
    case quotaExceeded
    case unknown
}
