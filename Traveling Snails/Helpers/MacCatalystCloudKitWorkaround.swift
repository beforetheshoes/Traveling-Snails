//
//  MacCatalystCloudKitWorkaround.swift
//  Traveling Snails
//
//  Workaround for missing CloudKit share delegate methods in Mac Catalyst
//

import Foundation
import CloudKit
import UIKit

#if targetEnvironment(macCatalyst)
/// Extension to add missing CloudKit sharing acceptance handling to Mac Catalyst
/// This addresses the issue where UIApplicationDelegate's userDidAcceptCloudKitShareWith method
/// is not implemented in Mac Catalyst UIKit
extension NSObject {
    @objc func application(_ application: NSObject, userDidAcceptCloudKitShareWithMetadata cloudKitShareMetadata: CKShare.Metadata) {
        Logger.shared.info("Mac Catalyst: Received CloudKit share acceptance", category: .cloudKit)
        
        // Forward to the main app delegate if it exists
        if let appDelegate = UIApplication.shared.delegate,
           let delegate = appDelegate as? any UIApplicationDelegate {
            // Try to call the method if it exists on the main delegate
            if delegate.responds(to: #selector(UIApplicationDelegate.application(_:userDidAcceptCloudKitShareWith:))) {
                delegate.application?(UIApplication.shared, userDidAcceptCloudKitShareWith: cloudKitShareMetadata)
            } else {
                // Handle the share acceptance directly
                handleCloudKitShareAcceptance(metadata: cloudKitShareMetadata)
            }
        } else {
            // Handle the share acceptance directly
            handleCloudKitShareAcceptance(metadata: cloudKitShareMetadata)
        }
    }
    
    private func handleCloudKitShareAcceptance(metadata: CKShare.Metadata) {
        Task {
            do {
                let container = CKContainer(identifier: metadata.containerIdentifier)
                _ = try await container.accept(metadata)
                Logger.shared.info("Mac Catalyst: Successfully accepted CloudKit share", category: .cloudKit)
                
                // Post notification for the app to handle
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .cloudKitShareAccepted,
                        object: metadata
                    )
                }
            } catch {
                Logger.shared.logError(error, message: "Mac Catalyst: Failed to accept CloudKit share", category: .cloudKit)
            }
        }
    }
}

/// Notification name for CloudKit share acceptance
extension Notification.Name {
    static let cloudKitShareAccepted = Notification.Name("CloudKitShareAccepted")
}

#endif