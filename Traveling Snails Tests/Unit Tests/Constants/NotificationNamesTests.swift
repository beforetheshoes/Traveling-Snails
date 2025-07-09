//
//  NotificationNamesTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

/// Tests for consolidated notification names
/// These tests verify that all notification names are properly centralized in NotificationNames.swift
@Suite("Notification Names Tests")
struct NotificationNamesTests {
    // MARK: - Navigation Notifications (Legacy)

    @Test("Legacy navigation notifications exist", .tags(.unit, .fast, .parallel, .validation, .navigation, .compatibility))
    func testLegacyNavigationNotifications() {
        // These should already exist in the current NotificationNames.swift
        #expect(Notification.Name.tripSelectedFromList.rawValue == "tripSelectedFromList")
        #expect(Notification.Name.clearTripSelection.rawValue == "clearTripSelection")
        #expect(Notification.Name.navigateToTrip.rawValue == "navigateToTrip")
    }

    // MARK: - Sync Notifications (To be consolidated)

    @Test("Sync notification names exist and match expected values", .tags(.unit, .fast, .parallel, .validation, .sync, .compatibility))
    func testSyncNotifications() {
        #expect(Notification.Name.syncDidStart.rawValue == "SyncManagerDidStartSync")
        #expect(Notification.Name.syncDidComplete.rawValue == "SyncManagerDidCompleteSync")
        #expect(Notification.Name.crossDeviceSyncDidStart.rawValue == "SyncManagerCrossDeviceSyncDidStart")
        #expect(Notification.Name.crossDeviceSyncDidComplete.rawValue == "SyncManagerCrossDeviceSyncDidComplete")
    }

    // MARK: - Localization Notifications

    @Test("Localization notification names exist", .tags(.unit, .fast, .parallel, .validation, .localization, .compatibility))
    func testLocalizationNotifications() {
        #expect(Notification.Name.languageChanged.rawValue == "LanguageChanged")
    }

    // MARK: - Database Notifications

    @Test("Database notification names exist", .tags(.unit, .fast, .parallel, .validation, .dataImport, .compatibility))
    func testDatabaseNotifications() {
        #expect(Notification.Name.importCompleted.rawValue == "importCompleted")
    }

    // MARK: - Cloud Storage Notifications

    @Test("Cloud storage notification names exist", .tags(.unit, .fast, .parallel, .validation, .cloudkit, .compatibility))
    func testCloudStorageNotifications() {
        #expect(Notification.Name.cloudStorageDidChangeExternally.rawValue == "CloudStorageDidChangeExternally")
    }

    // MARK: - Error Handling Notifications

    @Test("Error handling notification names exist", .tags(.unit, .fast, .parallel, .validation, .errorHandling, .compatibility))
    func testErrorHandlingNotifications() {
        #expect(Notification.Name.appErrorOccurred.rawValue == "AppErrorOccurred")
    }

    // MARK: - Notification Functionality Tests

    @Test("Notifications can be posted and observed", .tags(.unit, .medium, .serial, .validation, .async, .mainActor))
    func testNotificationPosting() async {
        await MainActor.run {
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

            // Process run loop to ensure notification is delivered
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))

            // Verify
            #expect(notificationReceived == true)
            #expect(receivedObject == testObject)

            // Clean up
            NotificationCenter.default.removeObserver(observer)
        }
    }

    @Test("All notification names are unique", .tags(.unit, .fast, .parallel, .validation, .boundary))
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
            Notification.Name.appErrorOccurred.rawValue,
        ]

        // Verify all names are unique
        let uniqueNames = Set(notificationNames)
        #expect(uniqueNames.count == notificationNames.count, "All notification names should be unique")
    }

    @Test("All notification names are non-empty", .tags(.unit, .fast, .parallel, .validation, .boundary))
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
            Notification.Name.appErrorOccurred.rawValue,
        ]

        for name in notificationNames {
            #expect(!name.isEmpty, "Notification name should not be empty: \(name)")
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("Consolidated notifications maintain backward compatibility", .tags(.unit, .fast, .parallel, .validation, .compatibility, .regression))
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
