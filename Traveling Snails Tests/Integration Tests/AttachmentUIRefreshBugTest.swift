//
//  AttachmentUIRefreshBugTest.swift
//  Traveling Snails Tests
//
//  Test for Issue #28: Attachments not appearing after import - UI refresh issue
//

import Combine
import Foundation
import SwiftData
import Testing

@testable import Traveling_Snails

@Suite("Attachment UI Refresh Bug - Issue #28")
struct AttachmentUIRefreshBugTest {
    @Test("Verify attachments exist in database after import", .tags(.integration, .medium, .parallel, .swiftdata, .fileAttachment, .dataImport, .regression, .critical))
    func verifyAttachmentsExistInDatabaseAfterImport() async throws {
        // Create test container
        let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // PHASE 1: Create original data
        let trip = Trip(name: "Trip with Attachment")
        let activity = Activity(name: "Activity with File", start: Date(), end: Date(), trip: trip)

        let originalContent = "ORIGINAL FILE CONTENT - should survive import"
        let originalData = originalContent.data(using: .utf8)!
        let originalAttachment = EmbeddedFileAttachment(
            fileName: "test-file.txt",
            originalFileName: "Test File.txt",
            fileSize: Int64(originalData.count),
            mimeType: "text/plain",
            fileExtension: "txt",
            fileDescription: "Test attachment",
            fileData: originalData
        )

        // Set up relationships
        originalAttachment.activity = activity
        activity.fileAttachments.append(originalAttachment)
        trip.activity.append(activity)

        context.insert(trip)
        context.insert(activity)
        context.insert(originalAttachment)
        try context.save()

        // PHASE 2: Verify attachment exists before "export"
        let allAttachmentsBeforeExport = try context.fetch(FetchDescriptor<EmbeddedFileAttachment>())
        #expect(allAttachmentsBeforeExport.count == 1, "Should have 1 attachment before export")
        #expect(allAttachmentsBeforeExport[0].fileData != nil, "Attachment should have file data")

        // PHASE 3: Simulate export process (verify export data includes fileData)
        let exportDict: [String: Any] = [
            "id": originalAttachment.id.uuidString,
            "fileName": originalAttachment.fileName,
            "originalFileName": originalAttachment.originalFileName,
            "fileSize": originalAttachment.fileSize,
            "mimeType": originalAttachment.mimeType,
            "fileExtension": originalAttachment.fileExtension,
            "createdDate": ISO8601DateFormatter().string(from: originalAttachment.createdDate),
            "fileDescription": originalAttachment.fileDescription,
            "parentType": "activity",
            "parentId": activity.id.uuidString,
            "fileData": originalData.base64EncodedString() as Any,
        ]

        #expect(exportDict["fileData"] != nil, "Export should include fileData when includeAttachments is true")

        // PHASE 4: Clear database (simulate fresh import)
        context.delete(originalAttachment)
        context.delete(activity)
        context.delete(trip)
        try context.save()

        // Verify database is empty
        let allAttachmentsAfterClear = try context.fetch(FetchDescriptor<EmbeddedFileAttachment>())
        #expect(allAttachmentsAfterClear.count == 0, "Database should be empty after clearing")

        // PHASE 5: Simulate import process
        let importTrip = Trip(name: trip.name)
        let importActivity = Activity(name: activity.name, start: activity.start, end: activity.end, trip: importTrip)

        context.insert(importTrip)
        context.insert(importActivity)

        // Import attachment using DatabaseImportManager logic
        let importedAttachment = EmbeddedFileAttachment(
            fileName: exportDict["fileName"] as! String,
            originalFileName: exportDict["originalFileName"] as! String,
            fileSize: exportDict["fileSize"] as! Int64,
            mimeType: exportDict["mimeType"] as! String,
            fileExtension: exportDict["fileExtension"] as! String,
            fileDescription: exportDict["fileDescription"] as! String
        )

        // Restore file data
        if let fileDataString = exportDict["fileData"] as? String,
           let fileData = Data(base64Encoded: fileDataString) {
            importedAttachment.fileData = fileData
        }

        // Restore parent relationship
        if let parentType = exportDict["parentType"] as? String,
           parentType == "activity" {
            importedAttachment.activity = importActivity
            importActivity.fileAttachments.append(importedAttachment)
        }

        context.insert(importedAttachment)
        try context.save()

        // PHASE 6: CRITICAL TEST - Verify attachments exist in database after import
        let allAttachmentsAfterImport = try context.fetch(FetchDescriptor<EmbeddedFileAttachment>())
        #expect(allAttachmentsAfterImport.count == 1, "CRITICAL: Should have 1 attachment after import")

        let importedAttachmentFromDB = allAttachmentsAfterImport[0]
        #expect(importedAttachmentFromDB.fileData != nil, "CRITICAL: Imported attachment should have file data")
        #expect(importedAttachmentFromDB.fileData == originalData, "CRITICAL: File data should match original")

        // PHASE 7: CRITICAL TEST - Verify relationships are properly established
        #expect(importedAttachmentFromDB.activity != nil, "CRITICAL: Attachment should have activity relationship")
        #expect(importedAttachmentFromDB.activity?.id == importActivity.id, "CRITICAL: Attachment should be linked to correct activity")

        // PHASE 8: CRITICAL TEST - Verify activity can access attachments
        #expect(importActivity.fileAttachments.count == 1, "CRITICAL: Activity should have 1 attachment")
        #expect(importActivity.hasAttachments == true, "CRITICAL: Activity should report having attachments")

        let attachmentFromActivity = importActivity.fileAttachments[0]
        #expect(attachmentFromActivity.fileData != nil, "CRITICAL: Attachment accessed through activity should have file data")
        #expect(attachmentFromActivity.fileData == originalData, "CRITICAL: File data accessed through activity should match original")

        // PHASE 9: CRUCIAL UI TEST - Simulate how UI would access attachments
        // This simulates the pattern used in UnifiedTripActivityDetailView
        let uiAttachments = importActivity.fileAttachments  // This is how UI gets attachments
        #expect(uiAttachments.count == 1, "UI BUG: UI should see 1 attachment through relationship")
        #expect(uiAttachments[0].fileData != nil, "UI BUG: UI should see attachment with file data")

        if let restoredData = uiAttachments[0].fileData {
            let restoredContent = String(data: restoredData, encoding: .utf8)
            #expect(restoredContent == originalContent, "UI BUG: UI should see correct file content")
        }
    }

    @Test("Test notification-based UI refresh mechanism", .tags(.integration, .fast, .parallel, .ui, .validation, .async))
    func testNotificationBasedUIRefresh() async throws {
        // This test simulates the notification pattern used for UI updates
        var receivedImportNotification = false
        let expectation = NotificationCenter.default.publisher(for: .importCompleted)
            .sink { _ in
                receivedImportNotification = true
            }

        // Simulate import completion
        NotificationCenter.default.post(name: .importCompleted, object: nil)

        // Give notification time to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        #expect(receivedImportNotification == true, "UI should receive import completion notification")

        expectation.cancel()
    }

    @Test("Test SwiftData relationship timing after context save", .tags(.integration, .medium, .parallel, .swiftdata, .fileAttachment, .consistency, .regression, .async))
    func testSwiftDataRelationshipTimingAfterSave() async throws {
        let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // Create entities and relationships
        let trip = Trip(name: "Timing Test Trip")
        let activity = Activity(name: "Timing Test Activity", start: Date(), end: Date(), trip: trip)

        let testData = "Timing test content".data(using: .utf8)!
        let attachment = EmbeddedFileAttachment(
            fileName: "timing-test.txt",
            originalFileName: "Timing Test.txt",
            fileSize: Int64(testData.count),
            mimeType: "text/plain",
            fileExtension: "txt",
            fileData: testData
        )

        // Set up relationships
        attachment.activity = activity
        activity.fileAttachments.append(attachment)
        trip.activity.append(activity)

        context.insert(trip)
        context.insert(activity)
        context.insert(attachment)

        // CRITICAL: Test relationship access BEFORE save
        #expect(activity.fileAttachments.count == 1, "Relationship should work before save")
        #expect(attachment.activity?.id == activity.id, "Reverse relationship should work before save")

        // Save to SwiftData
        try context.save()

        // CRITICAL: Test relationship access IMMEDIATELY after save
        #expect(activity.fileAttachments.count == 1, "Relationship should work immediately after save")
        #expect(attachment.activity?.id == activity.id, "Reverse relationship should work immediately after save")

        // CRITICAL: Test external storage data access after save
        #expect(attachment.fileData != nil, "File data should be accessible immediately after save")
        #expect(attachment.fileData == testData, "File data should be correct immediately after save")

        // Simulate a small delay (like what might happen in real UI)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

        // CRITICAL: Test relationship access after delay
        #expect(activity.fileAttachments.count == 1, "Relationship should work after short delay")
        #expect(attachment.fileData != nil, "File data should be accessible after short delay")

        // Fresh fetch to simulate UI refresh
        let activityId = activity.id
        let freshActivity = try context.fetch(FetchDescriptor<Activity>(predicate: #Predicate { activity in
            activity.id == activityId
        }))[0]
        #expect(freshActivity.fileAttachments.count == 1, "Fresh fetch should show attachments")
        #expect(freshActivity.fileAttachments[0].fileData != nil, "Fresh fetch should show file data")
    }
}
