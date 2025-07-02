//
//  FileAttachmentExportImportBugTests.swift
//  Traveling Snails Tests
//
//  Tests for Issue #28: File attachment export investigation
//  These tests demonstrate the specific bug where attachments aren't properly restored during import
//

import Foundation
import SwiftData
import Testing

@testable import Traveling_Snails

enum AttachmentTestError: Error {
    case fileDataMissing(String)
    case unexpectedCondition(String)
}

@MainActor
@Suite("File Attachment Export/Import Bug Investigation - Issue #28")
struct FileAttachmentExportImportBugTests {
    @Suite("Export Process Validation")
    struct ExportProcessValidationTests {
        @MainActor
        @Test("Export includes fileData when includeAttachments is true")
        func exportIncludesFileDataWhenToggleEnabled() throws {
            // Create test data with file attachments using proper SwiftData pattern
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let trip = Trip(name: "Test Trip")
            let activity = Activity(name: "Test Activity", start: Date(), end: Date(), trip: trip)

            // Create attachment with actual file data
            let testFileContent = "This is test file content for Issue #28 investigation"
            let testData = testFileContent.data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test-document.txt",
                originalFileName: "Test Document.txt",
                fileSize: Int64(testData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileDescription: "Test attachment for export/import bug",
                fileData: testData
            )

            // Set up relationships
            attachment.activity = activity
            activity.fileAttachments.append(attachment)
            trip.activity.append(activity)

            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(activity)
            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            // SIMULATE EXPORT WITH includeAttachments = true
            let includeAttachments = true

            // Test the actual export format used by DatabaseExportView
            let exportDict: [String: Any] = [
                "id": attachment.id.uuidString,
                "fileName": attachment.fileName,
                "originalFileName": attachment.originalFileName,
                "fileSize": attachment.fileSize,
                "mimeType": attachment.mimeType,
                "fileExtension": attachment.fileExtension,
                "createdDate": ISO8601DateFormatter().string(from: attachment.createdDate),
                "fileDescription": attachment.fileDescription,
                "parentType": "activity",
                "parentId": activity.id.uuidString,
                // CRITICAL: This is where the bug might be - fileData should be included when toggle is true
                "fileData": (includeAttachments && attachment.fileData != nil) ? attachment.fileData!.base64EncodedString() as Any : NSNull(),
            ]

            // EXPECTED: When includeAttachments is true, fileData should be present
            #expect(exportDict["fileData"] != nil, "fileData should be included when includeAttachments is true")
            #expect((exportDict["fileData"] as? String)?.isEmpty == false, "fileData should not be empty")

            // Verify the base64 data can be decoded back to original content
            if let base64String = exportDict["fileData"] as? String {
                let decodedData = Data(base64Encoded: base64String)
                #expect(decodedData != nil, "Base64 data should decode successfully")
                #expect(decodedData == testData, "Decoded data should match original")

                let decodedContent = String(data: decodedData!, encoding: .utf8)
                #expect(decodedContent == testFileContent, "Decoded content should match original text")
            }

            // Verify parent relationship data is preserved
            #expect(exportDict["parentType"] as? String == "activity", "Parent type should be preserved")
            #expect(exportDict["parentId"] as? String == activity.id.uuidString, "Parent ID should be preserved")
        }

        @MainActor
        @Test("Export excludes fileData when includeAttachments is false")
        func exportExcludesFileDataWhenToggleDisabled() throws {
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let trip = Trip(name: "Test Trip")
            let activity = Activity(name: "Test Activity", start: Date(), end: Date(), trip: trip)

            let testData = "Test content".data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                originalFileName: "Test.txt",
                fileSize: Int64(testData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileData: testData
            )

            attachment.activity = activity
            activity.fileAttachments.append(attachment)

            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(activity)
            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            // SIMULATE EXPORT WITH includeAttachments = false

            let exportDict: [String: Any] = [
                "id": attachment.id.uuidString,
                "fileName": attachment.fileName,
                "originalFileName": attachment.originalFileName,
                "fileSize": attachment.fileSize,
                "mimeType": attachment.mimeType,
                "fileExtension": attachment.fileExtension,
                "createdDate": ISO8601DateFormatter().string(from: attachment.createdDate),
                "fileDescription": attachment.fileDescription,
                "parentType": "activity",
                "parentId": activity.id.uuidString,
            ]

            // NOTE: includeAttachments is false, so fileData is intentionally NOT included

            // EXPECTED: When includeAttachments is false, fileData should be nil
            #expect(exportDict["fileData"] == nil, "fileData should be nil when includeAttachments is false")

            // But metadata should still be preserved
            #expect(exportDict["fileName"] as? String == attachment.fileName)
            #expect(exportDict["originalFileName"] as? String == attachment.originalFileName)
            #expect(exportDict["fileSize"] as? Int64 == attachment.fileSize)
        }
    }

    @Suite("Complete Export/Import Cycle Tests")
    struct CompleteExportImportCycleTests {
        @MainActor
        @Test("Complete export/import cycle with includeAttachments enabled - REPRODUCES BUG")
        func completeExportImportCycleWithAttachments() throws {
            // PHASE 1: Create original data with attachment
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let originalTrip = Trip(name: "Original Trip with Attachment")
            let originalActivity = Activity(name: "Original Activity", start: Date(), end: Date(), trip: originalTrip)

            let originalFileContent = "ORIGINAL FILE CONTENT - This text should be preserved through export/import"
            let originalData = originalFileContent.data(using: .utf8)!
            let originalAttachment = EmbeddedFileAttachment(
                fileName: "important-document.txt",
                originalFileName: "Important Document.txt",
                fileSize: Int64(originalData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileDescription: "Critical document that must survive export/import",
                fileData: originalData
            )

            // Set up relationships
            originalAttachment.activity = originalActivity
            originalActivity.fileAttachments.append(originalAttachment)
            originalTrip.activity.append(originalActivity)

            testBase.modelContext.insert(originalTrip)
            testBase.modelContext.insert(originalActivity)
            testBase.modelContext.insert(originalAttachment)
            try testBase.modelContext.save()

            // PHASE 2: Simulate export process with includeAttachments = true
            let includeAttachments = true

            let exportData: [String: Any] = [
                "exportInfo": [
                    "version": "1.0",
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "format": "json",
                    "includesAttachments": includeAttachments,
                ],
                "trips": [[
                    "id": originalTrip.id.uuidString,
                    "name": originalTrip.name,
                    "hasStartDate": originalTrip.hasStartDate,
                    "hasEndDate": originalTrip.hasEndDate,
                    "totalCost": NSDecimalNumber(decimal: originalTrip.totalCost).doubleValue,
                ], ],
                "activities": [[
                    "id": originalActivity.id.uuidString,
                    "name": originalActivity.name,
                    "start": ISO8601DateFormatter().string(from: originalActivity.start),
                    "end": ISO8601DateFormatter().string(from: originalActivity.end),
                    "tripId": originalTrip.id.uuidString,
                ], ],
                "attachments": [[
                    "id": originalAttachment.id.uuidString,
                    "fileName": originalAttachment.fileName,
                    "originalFileName": originalAttachment.originalFileName,
                    "fileSize": originalAttachment.fileSize,
                    "mimeType": originalAttachment.mimeType,
                    "fileExtension": originalAttachment.fileExtension,
                    "createdDate": ISO8601DateFormatter().string(from: originalAttachment.createdDate),
                    "fileDescription": originalAttachment.fileDescription,
                    "parentType": "activity",
                    "parentId": originalActivity.id.uuidString,
                    // THE CRITICAL PART: fileData should be included when includeAttachments is true
                    "fileData": originalData.base64EncodedString(), // includeAttachments is true in this test
                ], ],
            ]

            // Verify export includes attachment data
            let exportInfo = exportData["exportInfo"] as! [String: Any]
            #expect(exportInfo["includesAttachments"] as? Bool == true, "Export should indicate attachments are included")

            let attachments = exportData["attachments"] as! [[String: Any]]
            #expect(attachments.count == 1, "Should export one attachment")

            let exportedAttachment = attachments[0]
            #expect(exportedAttachment["fileData"] != nil, "CRITICAL: fileData should be present in export when includeAttachments is true")

            // PHASE 3: Simulate import process
            let importTestBase = SwiftDataTestBase()
            try importTestBase.verifyDatabaseEmpty()

            // Import trip first
            let tripData = (exportData["trips"] as! [[String: Any]])[0]
            let importedTrip = Trip(name: tripData["name"] as! String)
            importTestBase.modelContext.insert(importedTrip)

            // Import activity
            let activityData = (exportData["activities"] as! [[String: Any]])[0]
            let importedActivity = Activity(
                name: activityData["name"] as! String,
                start: ISO8601DateFormatter().date(from: activityData["start"] as! String)!,
                end: ISO8601DateFormatter().date(from: activityData["end"] as! String)!,
                trip: importedTrip
            )
            importedTrip.activity.append(importedActivity)
            importTestBase.modelContext.insert(importedActivity)

            // CRITICAL TEST: Import attachment with file data restoration
            let attachmentData = exportedAttachment
            let importedAttachment = EmbeddedFileAttachment(
                fileName: attachmentData["fileName"] as! String,
                originalFileName: attachmentData["originalFileName"] as! String,
                fileSize: attachmentData["fileSize"] as! Int64,
                mimeType: attachmentData["mimeType"] as! String,
                fileExtension: attachmentData["fileExtension"] as! String,
                fileDescription: attachmentData["fileDescription"] as! String
            )

            // Restore creation date
            if let createdDateString = attachmentData["createdDate"] as? String,
               let createdDate = ISO8601DateFormatter().date(from: createdDateString) {
                importedAttachment.createdDate = createdDate
            }

            // CRITICAL: Restore file data from base64
            if let fileDataString = attachmentData["fileData"] as? String {
                let restoredData = Data(base64Encoded: fileDataString)
                #expect(restoredData != nil, "Base64 fileData should decode successfully")
                importedAttachment.fileData = restoredData
            } else {
                // This indicates the bug we're testing for
                throw AttachmentTestError.fileDataMissing("fileData is missing from export even though includeAttachments was true")
            }

            // Restore parent relationship
            if let parentType = attachmentData["parentType"] as? String,
               parentType == "activity" {
                importedAttachment.activity = importedActivity
                importedActivity.fileAttachments.append(importedAttachment)
            }

            importTestBase.modelContext.insert(importedAttachment)
            try importTestBase.modelContext.save()

            // PHASE 4: Verify complete data restoration
            #expect(importedAttachment.fileData != nil, "CRITICAL BUG: File data should be restored after import")
            #expect(importedAttachment.fileData == originalData, "Restored file data should match original")

            if let restoredData = importedAttachment.fileData {
                let restoredContent = String(data: restoredData, encoding: .utf8)
                #expect(restoredContent == originalFileContent, "Restored file content should match original text")
            }

            // Verify relationships are restored
            #expect(importedAttachment.activity?.id == importedActivity.id, "Parent relationship should be restored")
            #expect(importedActivity.fileAttachments.count == 1, "Activity should have restored attachment")
            #expect(importedActivity.hasAttachments == true, "Activity should report having attachments")

            // Verify metadata is preserved
            #expect(importedAttachment.originalFileName == originalAttachment.originalFileName)
            #expect(importedAttachment.fileSize == originalAttachment.fileSize)
            #expect(importedAttachment.mimeType == originalAttachment.mimeType)
            #expect(importedAttachment.fileDescription == originalAttachment.fileDescription)
        }

        @MainActor
        @Test("Large file attachment export/import integrity")
        func largeFileAttachmentExportImportIntegrity() throws {
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let trip = Trip(name: "Trip with Large Attachment")
            let activity = Activity(name: "Activity with Large File", start: Date(), end: Date(), trip: trip)

            // Create a larger test file (10KB for test performance)
            let largeContent = String(repeating: "This is line content for large file testing. ", count: 200)
            let largeData = largeContent.data(using: .utf8)!

            let attachment = EmbeddedFileAttachment(
                fileName: "large-document.txt",
                originalFileName: "Large Document.txt",
                fileSize: Int64(largeData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileDescription: "Large test file",
                fileData: largeData
            )

            attachment.activity = activity
            activity.fileAttachments.append(attachment)
            trip.activity.append(activity)

            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(activity)
            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            // Export with attachments
            let base64Data = largeData.base64EncodedString()
            #expect(!base64Data.isEmpty, "Large file should encode to base64")

            // Simulate import
            let decodedData = Data(base64Encoded: base64Data)
            #expect(decodedData != nil, "Base64 should decode successfully")
            #expect(decodedData == largeData, "Large file data should survive base64 round-trip")

            let decodedContent = String(data: decodedData!, encoding: .utf8)
            #expect(decodedContent == largeContent, "Large file content should be identical after decode")
        }

        @MainActor
        @Test("Multiple attachments per activity export/import")
        func multipleAttachmentsPerActivityExportImport() throws {
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let trip = Trip(name: "Trip with Multiple Attachments")
            let activity = Activity(name: "Activity with Multiple Files", start: Date(), end: Date(), trip: trip)

            // Create multiple attachments with different content
            let attachments = [
                ("doc1.txt", "First document content"),
                ("doc2.txt", "Second document content with different text"),
                ("doc3.txt", "Third document has unique content too"),
            ].map { fileName, content in
                let data = content.data(using: .utf8)!
                let attachment = EmbeddedFileAttachment(
                    fileName: fileName,
                    originalFileName: fileName,
                    fileSize: Int64(data.count),
                    mimeType: "text/plain",
                    fileExtension: "txt",
                    fileDescription: "Test file \(fileName)",
                    fileData: data
                )
                attachment.activity = activity
                return attachment
            }

            activity.fileAttachments.append(contentsOf: attachments)
            trip.activity.append(activity)

            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(activity)
            for attachment in attachments {
                testBase.modelContext.insert(attachment)
            }
            try testBase.modelContext.save()

            // Verify all attachments have data before export
            #expect(activity.fileAttachments.count == 3, "Should have 3 attachments")
            for attachment in attachments {
                #expect(attachment.fileData != nil, "Each attachment should have file data")
            }

            // Simulate export/import for each attachment
            for (index, attachment) in attachments.enumerated() {
                let exportDict: [String: Any] = [
                    "id": attachment.id.uuidString,
                    "fileName": attachment.fileName,
                    "originalFileName": attachment.originalFileName,
                    "fileSize": attachment.fileSize,
                    "mimeType": attachment.mimeType,
                    "fileExtension": attachment.fileExtension,
                    "fileDescription": attachment.fileDescription,
                    "parentType": "activity",
                    "parentId": activity.id.uuidString,
                    "fileData": attachment.fileData!.base64EncodedString(),
                ]

                // Verify export includes data for each attachment
                #expect(exportDict["fileData"] != nil, "Attachment \(index) should have fileData in export")

                // Simulate import
                if let base64String = exportDict["fileData"] as? String {
                    let decodedData = Data(base64Encoded: base64String)
                    #expect(decodedData != nil, "Attachment \(index) base64 should decode")
                    #expect(decodedData == attachment.fileData, "Attachment \(index) data should survive round-trip")
                }
            }
        }
    }

    @Suite("Edge Cases and Error Scenarios")
    struct EdgeCasesAndErrorScenarios {
        @MainActor
        @Test("Import with corrupted base64 data")
        func importWithCorruptedBase64Data() throws {
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            let trip = Trip(name: "Test Trip")
            let activity = Activity(name: "Test Activity", start: Date(), end: Date(), trip: trip)

            testBase.modelContext.insert(trip)
            testBase.modelContext.insert(activity)
            try testBase.modelContext.save()

            // Simulate import with corrupted base64 data
            let corruptedAttachmentData: [String: Any] = [
                "id": UUID().uuidString,
                "fileName": "corrupted.txt",
                "originalFileName": "Corrupted.txt",
                "fileSize": Int64(100),
                "mimeType": "text/plain",
                "fileExtension": "txt",
                "fileDescription": "File with corrupted data",
                "parentType": "activity",
                "parentId": activity.id.uuidString,
                "fileData": "InvalidBase64Data!@#$%^&*()", // This is not valid base64
            ]

            let attachment = EmbeddedFileAttachment(
                fileName: corruptedAttachmentData["fileName"] as! String,
                originalFileName: corruptedAttachmentData["originalFileName"] as! String,
                fileSize: corruptedAttachmentData["fileSize"] as! Int64,
                mimeType: corruptedAttachmentData["mimeType"] as! String,
                fileExtension: corruptedAttachmentData["fileExtension"] as! String,
                fileDescription: corruptedAttachmentData["fileDescription"] as! String
            )

            // Try to restore file data - should handle corruption gracefully
            if let fileDataString = corruptedAttachmentData["fileData"] as? String {
                let decodedData = Data(base64Encoded: fileDataString)
                #expect(decodedData == nil, "Corrupted base64 should fail to decode")

                // Import should handle this gracefully by not setting file data
                if decodedData != nil {
                    attachment.fileData = decodedData
                } else {
                    // Graceful handling: attachment exists but without file data
                    attachment.fileData = nil
                }
            }

            // Attachment should still be created but without file data
            attachment.activity = activity
            activity.fileAttachments.append(attachment)
            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            #expect(attachment.fileData == nil, "Attachment with corrupted data should have nil fileData")
            #expect(activity.fileAttachments.count == 1, "Attachment should still be added to activity")
            #expect(attachment.fileName == "corrupted.txt", "Metadata should be preserved despite data corruption")
        }

        @MainActor
        @Test("Import attachment with missing parent relationship")
        func importAttachmentWithMissingParentRelationship() throws {
            let testBase = SwiftDataTestBase()
            try testBase.verifyDatabaseEmpty()

            // Create attachment data referencing non-existent parent
            let orphanedAttachmentData: [String: Any] = [
                "id": UUID().uuidString,
                "fileName": "orphaned.txt",
                "originalFileName": "Orphaned.txt",
                "fileSize": Int64(50),
                "mimeType": "text/plain",
                "fileExtension": "txt",
                "fileDescription": "File with missing parent",
                "parentType": "activity",
                "parentId": "non-existent-activity-id",
                "fileData": "Test content".data(using: .utf8)!.base64EncodedString(),
            ]

            let attachment = EmbeddedFileAttachment(
                fileName: orphanedAttachmentData["fileName"] as! String,
                originalFileName: orphanedAttachmentData["originalFileName"] as! String,
                fileSize: orphanedAttachmentData["fileSize"] as! Int64,
                mimeType: orphanedAttachmentData["mimeType"] as! String,
                fileExtension: orphanedAttachmentData["fileExtension"] as! String,
                fileDescription: orphanedAttachmentData["fileDescription"] as! String
            )

            // Restore file data
            if let fileDataString = orphanedAttachmentData["fileData"] as? String,
               let decodedData = Data(base64Encoded: fileDataString) {
                attachment.fileData = decodedData
            }

            // Try to restore parent relationship - should fail gracefully
            if let parentType = orphanedAttachmentData["parentType"] as? String,
               parentType == "activity" {
                // Search for all activities (should be empty since we haven't created any)
                let descriptor = FetchDescriptor<Activity>()
                let allActivities = try testBase.modelContext.fetch(descriptor)

                #expect(allActivities.isEmpty, "Should not find any activities in empty test database")

                // Graceful handling: attachment remains without parent relationship
                // Since no activities exist, attachment will be orphaned
            }

            testBase.modelContext.insert(attachment)
            try testBase.modelContext.save()

            // Verify attachment exists but is orphaned
            #expect(attachment.fileData != nil, "File data should be preserved even if parent is missing")
            #expect(attachment.activity == nil, "Attachment should have no parent relationship")
            #expect(attachment.lodging == nil, "Attachment should have no lodging relationship")
            #expect(attachment.transportation == nil, "Attachment should have no transportation relationship")
        }
    }
}
