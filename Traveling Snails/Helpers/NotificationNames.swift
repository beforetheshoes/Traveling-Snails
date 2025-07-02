//
//  NotificationNames.swift
//  Traveling Snails
//
//

import Foundation

/// Centralized notification names to prevent scattered definitions across the codebase
/// This provides type-safe access to notification names and prevents typos/inconsistencies
/// 
/// Note: Some notifications are marked as deprecated as the app migrates to modern 
/// environment-based patterns (@Observable, NavigationRouter, etc.)
extension Notification.Name {
    // MARK: - Navigation Notifications (Legacy - Migrating to Environment-Based)

    /// DEPRECATED: Use NavigationRouter.selectTrip() instead
    /// Legacy notification for trip selection from list
    static let tripSelectedFromList = Notification.Name("tripSelectedFromList")

    /// Still used by some views during migration to environment-based navigation
    /// Notification to clear current trip selection
    static let clearTripSelection = Notification.Name("clearTripSelection")

    /// Still used by some views during migration to environment-based navigation
    /// Notification to navigate to a specific trip
    static let navigateToTrip = Notification.Name("navigateToTrip")

    // MARK: - Sync Operation Notifications

    /// Posted when sync operation starts
    /// Used by: SyncManager.swift
    static let syncDidStart = Notification.Name("SyncManagerDidStartSync")

    /// Posted when sync operation completes successfully
    /// Used by: SyncManager.swift
    static let syncDidComplete = Notification.Name("SyncManagerDidCompleteSync")

    /// Posted when cross-device sync starts
    /// Used by: SyncManager.swift
    static let crossDeviceSyncDidStart = Notification.Name("SyncManagerCrossDeviceSyncDidStart")

    /// Posted when cross-device sync completes
    /// Used by: SyncManager.swift
    static let crossDeviceSyncDidComplete = Notification.Name("SyncManagerCrossDeviceSyncDidComplete")

    // MARK: - Localization Notifications

    /// Posted when the app language changes
    /// Used by: LocalizationManager.swift
    static let languageChanged = Notification.Name("LanguageChanged")

    // MARK: - Database Operation Notifications

    /// Posted when database import operation completes
    /// Used by: DatabaseImportProgressView.swift
    static let importCompleted = Notification.Name("importCompleted")

    // MARK: - Cloud Storage Notifications

    /// Posted when cloud storage changes externally (outside the app)
    /// Used by: CloudStorageService.swift
    static let cloudStorageDidChangeExternally = Notification.Name("CloudStorageDidChangeExternally")

    // MARK: - Error Handling Notifications

    /// Posted when an application error occurs that needs global handling
    /// Used by: ErrorHandling.swift
    static let appErrorOccurred = Notification.Name("AppErrorOccurred")

    // MARK: - File Attachment Notifications

    /// Posted when a file attachment is added to an activity
    /// Used by: EmbeddedFileAttachmentListView.swift
    static let fileAttachmentAdded = Notification.Name("FileAttachmentAdded")

    /// Posted when a file attachment is removed from an activity
    /// Used by: EmbeddedFileAttachmentListView.swift
    static let fileAttachmentRemoved = Notification.Name("FileAttachmentRemoved")

    /// Posted when a file attachment is updated
    /// Used by: EmbeddedFileAttachmentListView.swift
    static let fileAttachmentUpdated = Notification.Name("FileAttachmentUpdated")
}
