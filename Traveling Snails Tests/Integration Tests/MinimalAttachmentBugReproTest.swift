//
//  MinimalAttachmentBugReproTest.swift
//  Traveling Snails Tests
//
//  Minimal reproduction test for Issue #28: File attachment export investigation
//

import Foundation
import SwiftData
import Testing

@testable import Traveling_Snails

@Suite("Minimal Attachment Bug Reproduction - Issue #28")
struct MinimalAttachmentBugReproTest {
    @Test("Simple attachment export with includeAttachments toggle - Step by step debugging")
    func simpleAttachmentExportWithToggle() async throws {
        // Create test container
        let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // Create minimal test data
        let trip = Trip(name: "Debug Trip")
        let activity = Activity(name: "Debug Activity", start: Date(), end: Date(), trip: trip)

        let testContent = "DEBUG: This is test file content"
        let testData = testContent.data(using: .utf8)!

        let attachment = EmbeddedFileAttachment(
            fileName: "debug.txt",
            originalFileName: "Debug.txt",
            fileSize: Int64(testData.count),
            mimeType: "text/plain",
            fileExtension: "txt",
            fileDescription: "Debug attachment",
            fileData: testData
        )

        // Set up relationships
        attachment.activity = activity
        activity.fileAttachments.append(attachment)
        trip.activity.append(activity)

        context.insert(trip)
        context.insert(activity)
        context.insert(attachment)
        try context.save()

        // TEST 1: Verify attachment has data before export
        #expect(attachment.fileData != nil, "Attachment should have file data before export")
        #expect(attachment.fileData == testData, "File data should match what we set")

        // TEST 2: Simulate DatabaseExportView.attachmentToDict() with includeAttachments = true
        let includeAttachments = true

        // This is the EXACT code from DatabaseExportView.attachmentToDict()
        var dict: [String: Any] = [
            "id": attachment.id.uuidString,
            "fileName": attachment.fileName,
            "originalFileName": attachment.originalFileName,
            "fileSize": attachment.fileSize,
            "mimeType": attachment.mimeType,
            "fileExtension": attachment.fileExtension,
            "createdDate": ISO8601DateFormatter().string(from: attachment.createdDate),
            "fileDescription": attachment.fileDescription,
        ]

        // Include parent relationship information for proper restoration
        if let activity = attachment.activity {
            dict["parentType"] = "activity"
            dict["parentId"] = activity.id.uuidString
        } else if let lodging = attachment.lodging {
            dict["parentType"] = "lodging"
            dict["parentId"] = lodging.id.uuidString
        } else if let transportation = attachment.transportation {
            dict["parentType"] = "transportation"
            dict["parentId"] = transportation.id.uuidString
        }

        // THE CRITICAL SECTION: This is where the bug might be
        if includeAttachments, let fileData = attachment.fileData {
            dict["fileData"] = fileData.base64EncodedString()
        }

        // EXPECTATION: fileData should be included when includeAttachments is true
        #expect(dict["fileData"] != nil, "CRITICAL BUG: fileData should be included in export when includeAttachments is true")
        #expect((dict["fileData"] as? String)?.isEmpty == false, "fileData should not be empty")

        // TEST 3: Verify the base64 encoding works correctly
        if let base64String = dict["fileData"] as? String {
            let decodedData = Data(base64Encoded: base64String)
            #expect(decodedData != nil, "Base64 string should decode successfully")
            #expect(decodedData == testData, "Decoded data should match original")

            let decodedContent = String(data: decodedData!, encoding: .utf8)
            #expect(decodedContent == testContent, "Decoded content should match original text")
        } else {
            Issue.record("BUG FOUND: fileData is nil in export dict even though includeAttachments is true and attachment has data")
        }

        // TEST 4: Verify relationship data is preserved
        #expect(dict["parentType"] as? String == "activity", "Parent type should be preserved")
        #expect(dict["parentId"] as? String == activity.id.uuidString, "Parent ID should be preserved")
    }

    @Test("Simple attachment export with includeAttachments FALSE - Should exclude data")
    func simpleAttachmentExportWithToggleOff() async throws {
        // Create test container
        let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // Create minimal test data
        let trip = Trip(name: "Debug Trip")
        let activity = Activity(name: "Debug Activity", start: Date(), end: Date(), trip: trip)

        let testContent = "This data should NOT be exported"
        let testData = testContent.data(using: .utf8)!

        let attachment = EmbeddedFileAttachment(
            fileName: "secret.txt",
            originalFileName: "Secret.txt",
            fileSize: Int64(testData.count),
            mimeType: "text/plain",
            fileExtension: "txt",
            fileData: testData
        )

        attachment.activity = activity
        activity.fileAttachments.append(attachment)
        trip.activity.append(activity)

        context.insert(trip)
        context.insert(activity)
        context.insert(attachment)
        try context.save()

        // Simulate export with includeAttachments = false

        var dict: [String: Any] = [
            "id": attachment.id.uuidString,
            "fileName": attachment.fileName,
            "originalFileName": attachment.originalFileName,
            "fileSize": attachment.fileSize,
            "mimeType": attachment.mimeType,
            "fileExtension": attachment.fileExtension,
            "createdDate": ISO8601DateFormatter().string(from: attachment.createdDate),
            "fileDescription": attachment.fileDescription,
        ]

        if let activity = attachment.activity {
            dict["parentType"] = "activity"
            dict["parentId"] = activity.id.uuidString
        }

        // THE CRITICAL SECTION: When includeAttachments is false, fileData should NOT be included
        // NOTE: includeAttachments is false, so fileData is intentionally NOT added to dict

        // EXPECTATION: fileData should NOT be included when includeAttachments is false
        #expect(dict["fileData"] == nil, "fileData should be nil when includeAttachments is false")

        // But metadata should still be preserved
        #expect(dict["fileName"] as? String == attachment.fileName, "Metadata should be preserved")
        #expect(dict["originalFileName"] as? String == attachment.originalFileName, "Original filename should be preserved")
        #expect(dict["fileSize"] as? Int64 == attachment.fileSize, "File size should be preserved")
    }

    @Test("Simple import restoration with fileData present")
    func simpleImportRestorationWithFileData() async throws {
        // Create import container (simulating fresh import)
        let container = try ModelContainer(for: Trip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)

        // Create minimal trip and activity for relationship restoration
        let trip = Trip(name: "Imported Trip")
        let activity = Activity(name: "Imported Activity", start: Date(), end: Date(), trip: trip)

        context.insert(trip)
        context.insert(activity)
        try context.save()

        // Simulate attachment data as it would come from export
        let originalContent = "IMPORTED: This file content should be restored"
        let originalData = originalContent.data(using: .utf8)!
        let base64Data = originalData.base64EncodedString()

        let importAttachmentData: [String: Any] = [
            "id": UUID().uuidString,
            "fileName": "imported.txt",
            "originalFileName": "Imported.txt",
            "fileSize": Int64(originalData.count),
            "mimeType": "text/plain",
            "fileExtension": "txt",
            "createdDate": ISO8601DateFormatter().string(from: Date()),
            "fileDescription": "Imported attachment",
            "parentType": "activity",
            "parentId": activity.id.uuidString,
            "fileData": base64Data,  // THIS IS THE CRITICAL PART
        ]

        // Simulate DatabaseImportManager.importAttachment() - EXACT code
        guard let fileName = importAttachmentData["fileName"] as? String,
              let originalFileName = importAttachmentData["originalFileName"] as? String else {
            Issue.record("Should have filename data")
            return
        }

        let importedAttachment = EmbeddedFileAttachment(
            fileName: fileName,
            originalFileName: originalFileName,
            fileSize: importAttachmentData["fileSize"] as? Int64 ?? 0,
            mimeType: importAttachmentData["mimeType"] as? String ?? "",
            fileExtension: importAttachmentData["fileExtension"] as? String ?? "",
            fileDescription: importAttachmentData["fileDescription"] as? String ?? ""
        )

        // Import file data if present - THIS IS THE CRITICAL SECTION
        if let fileDataString = importAttachmentData["fileData"] as? String,
           let fileData = Data(base64Encoded: fileDataString) {
            importedAttachment.fileData = fileData
        } else {
            Issue.record("BUG DETECTED: fileData string should be present and decodable")
            return
        }

        // Set creation date
        if let createdDateString = importAttachmentData["createdDate"] as? String,
           let createdDate = ISO8601DateFormatter().date(from: createdDateString) {
            importedAttachment.createdDate = createdDate
        }

        // Restore parent relationship
        if let parentType = importAttachmentData["parentType"] as? String,
           let parentId = importAttachmentData["parentId"] as? String,
           parentType == "activity" {
            // In real import, this would search through importedTrips, but we'll use our test activity
            if activity.id.uuidString == parentId {
                importedAttachment.activity = activity
                activity.fileAttachments.append(importedAttachment)
            }
        }

        context.insert(importedAttachment)
        try context.save()

        // VERIFY: File data should be restored correctly
        #expect(importedAttachment.fileData != nil, "CRITICAL BUG: File data should be restored after import")
        #expect(importedAttachment.fileData == originalData, "Restored file data should match original")

        if let restoredData = importedAttachment.fileData {
            let restoredContent = String(data: restoredData, encoding: .utf8)
            #expect(restoredContent == originalContent, "Restored file content should match original text")
        }

        // VERIFY: Relationships should be restored
        #expect(importedAttachment.activity?.id == activity.id, "Parent relationship should be restored")
        #expect(activity.fileAttachments.count == 1, "Activity should have restored attachment")
        #expect(activity.hasAttachments == true, "Activity should report having attachments")

        // VERIFY: Metadata should be preserved
        #expect(importedAttachment.originalFileName == "Imported.txt", "Original filename should be preserved")
        #expect(importedAttachment.fileSize == Int64(originalData.count), "File size should be preserved")
        #expect(importedAttachment.mimeType == "text/plain", "MIME type should be preserved")
    }
}
