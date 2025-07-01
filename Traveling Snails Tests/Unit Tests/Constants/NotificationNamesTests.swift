//
//  NotificationNamesTests.swift
//  Traveling Snails Tests
//
//

import Testing
import Foundation
@testable import Traveling_Snails

/// Tests for consolidated notification names
/// These tests verify that all notification names are properly centralized in NotificationNames.swift
@Suite("Notification Names Tests")
struct NotificationNamesTests {
    
    // MARK: - Navigation Notifications (Legacy)
    
    @Test("Legacy navigation notifications exist")
    func testLegacyNavigationNotifications() {
        // These should already exist in the current NotificationNames.swift
        #expect(Notification.Name.tripSelectedFromList.rawValue == "tripSelectedFromList")
        #expect(Notification.Name.clearTripSelection.rawValue == "clearTripSelection")
        #expect(Notification.Name.navigateToTrip.rawValue == "navigateToTrip")
    }
    
    // MARK: - Sync Notifications (To be consolidated)
    
    @Test("Sync notification names exist and match expected values")
    func testSyncNotifications() {
        #expect(Notification.Name.syncDidStart.rawValue == "SyncManagerDidStartSync")
        #expect(Notification.Name.syncDidComplete.rawValue == "SyncManagerDidCompleteSync")
        #expect(Notification.Name.crossDeviceSyncDidStart.rawValue == "SyncManagerCrossDeviceSyncDidStart")
        #expect(Notification.Name.crossDeviceSyncDidComplete.rawValue == "SyncManagerCrossDeviceSyncDidComplete")
    }
    
    // MARK: - Localization Notifications
    
    @Test("Localization notification names exist")
    func testLocalizationNotifications() {
        #expect(Notification.Name.languageChanged.rawValue == "LanguageChanged")
    }
    
    // MARK: - Database Notifications
    
    @Test("Database notification names exist")
    func testDatabaseNotifications() {
        #expect(Notification.Name.importCompleted.rawValue == "importCompleted")
    }
    
    // MARK: - Cloud Storage Notifications
    
    @Test("Cloud storage notification names exist")
    func testCloudStorageNotifications() {
        #expect(Notification.Name.cloudStorageDidChangeExternally.rawValue == "CloudStorageDidChangeExternally")
    }
    
    // MARK: - Error Handling Notifications
    
    @Test("Error handling notification names exist")
    func testErrorHandlingNotifications() {
        #expect(Notification.Name.appErrorOccurred.rawValue == "AppErrorOccurred")
    }
    
    // MARK: - Notification Functionality Tests
    
    @Test("Notifications can be posted and observed")
    func testNotificationPosting() async {
        let testObject = "testData"
        var receivedObject: String?
        var notificationReceived = false
        
        // Set up observer
        let observer = NotificationCenter.default.addObserver(
            forName: .syncDidStart,
            object: nil,
            queue: .main
        ) { notification in
            receivedObject = notification.object as? String
            notificationReceived = true
        }
        
        // Post notification
        NotificationCenter.default.post(name: .syncDidStart, object: testObject)
        
        // Give notification time to process
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Verify
        #expect(notificationReceived == true)
        #expect(receivedObject == testObject)
        
        // Clean up
        NotificationCenter.default.removeObserver(observer)
    }
    
    @Test("All notification names are unique")
    func testUniqueNotificationNames() {
        // Collect all notification raw values
        let notificationNames = [
            Notification.Name.tripSelectedFromList.rawValue,
            Notification.Name.clearTripSelection.rawValue,
            Notification.Name.navigateToTrip.rawValue,
            Notification.Name.syncDidStart.rawValue,
            Notification.Name.syncDidComplete.rawValue,
            Notification.Name.crossDeviceSyncDidStart.rawValue,
            Notification.Name.crossDeviceSyncDidComplete.rawValue,
            Notification.Name.languageChanged.rawValue,
            Notification.Name.importCompleted.rawValue,
            Notification.Name.cloudStorageDidChangeExternally.rawValue,
            Notification.Name.appErrorOccurred.rawValue
        ]
        
        // Verify all names are unique
        let uniqueNames = Set(notificationNames)
        #expect(uniqueNames.count == notificationNames.count, "All notification names should be unique")
    }
    
    @Test("All notification names are non-empty")
    func testNonEmptyNotificationNames() {
        let notificationNames = [
            Notification.Name.tripSelectedFromList.rawValue,
            Notification.Name.clearTripSelection.rawValue,
            Notification.Name.navigateToTrip.rawValue,
            Notification.Name.syncDidStart.rawValue,
            Notification.Name.syncDidComplete.rawValue,
            Notification.Name.crossDeviceSyncDidStart.rawValue,
            Notification.Name.crossDeviceSyncDidComplete.rawValue,
            Notification.Name.languageChanged.rawValue,
            Notification.Name.importCompleted.rawValue,
            Notification.Name.cloudStorageDidChangeExternally.rawValue,
            Notification.Name.appErrorOccurred.rawValue
        ]
        
        for name in notificationNames {
            #expect(!name.isEmpty, "Notification name should not be empty: \(name)")
        }
    }
    
    // MARK: - Backward Compatibility Tests
    
    @Test("Consolidated notifications maintain backward compatibility")
    func testBackwardCompatibility() {
        // Verify that consolidating notifications doesn't break existing string values
        // These values must match what's currently scattered in the codebase
        
        #expect(Notification.Name.syncDidStart.rawValue == "SyncManagerDidStartSync")
        #expect(Notification.Name.languageChanged.rawValue == "LanguageChanged") 
        #expect(Notification.Name.importCompleted.rawValue == "importCompleted")
        #expect(Notification.Name.cloudStorageDidChangeExternally.rawValue == "CloudStorageDidChangeExternally")
        #expect(Notification.Name.appErrorOccurred.rawValue == "AppErrorOccurred")
    }
}

