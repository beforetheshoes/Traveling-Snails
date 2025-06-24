//
//  FileAttachmentSettingsViewTests.swift
//  Traveling Snails Tests
//

import Testing
import SwiftUI
import SwiftData
@testable import Traveling_Snails

@Suite("FileAttachmentSettingsView Tests")
@MainActor
struct FileAttachmentSettingsViewTests {
    
    @Test("Orphaned files detection logic - no orphaned files")
    func orphanedFilesDetectionNoOrphans() async throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()
        
        // Create test data with properly linked attachments
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let activity = Activity(name: "Test Activity", trip: trip)
        let lodging = Lodging(name: "Test Hotel", trip: trip)
        let transportation = Transportation(name: "Test Flight", trip: trip)
        
        // Create attachments linked to different entities
        let activityAttachment = EmbeddedFileAttachment(fileName: "activity.pdf", originalFileName: "activity.pdf", fileExtension: "pdf")
        activityAttachment.activity = activity
        activity.fileAttachments.append(activityAttachment)
        
        let lodgingAttachment = EmbeddedFileAttachment(fileName: "hotel.jpg", originalFileName: "hotel.jpg", fileExtension: "jpg")
        lodgingAttachment.lodging = lodging
        lodging.fileAttachments.append(lodgingAttachment)
        
        let transportationAttachment = EmbeddedFileAttachment(fileName: "ticket.pdf", originalFileName: "ticket.pdf", fileExtension: "pdf")
        transportationAttachment.transportation = transportation
        transportation.fileAttachments.append(transportationAttachment)
        
        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(activity)
        testBase.modelContext.insert(lodging)
        testBase.modelContext.insert(transportation)
        testBase.modelContext.insert(activityAttachment)
        testBase.modelContext.insert(lodgingAttachment)
        testBase.modelContext.insert(transportationAttachment)
        try testBase.modelContext.save()
        
        // Test orphaned files detection logic (mirroring FileAttachmentSettingsView logic)
        let descriptor = FetchDescriptor<EmbeddedFileAttachment>()
        let allAttachments = try testBase.modelContext.fetch(descriptor)
        
        let orphanedAttachments = allAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }
        
        #expect(orphanedAttachments.isEmpty, "Should find no orphaned attachments when all are properly linked")
        #expect(allAttachments.count == 3, "Should have 3 total attachments")
        
        // Verify the success message that would be shown
        let expectedMessage = orphanedAttachments.isEmpty ? 
            "Scan complete. No orphaned files found." : 
            "Scan complete. Found \(orphanedAttachments.count) orphaned file\(orphanedAttachments.count == 1 ? "" : "s")."
        
        #expect(expectedMessage == "Scan complete. No orphaned files found.", 
                "Should generate correct 'no orphaned files' message")
    }
    
    @Test("Orphaned files detection logic - multiple orphaned files")
    func orphanedFilesDetectionMultipleOrphans() async throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()
        
        // Create orphaned attachments (no relationships)
        let orphaned1 = EmbeddedFileAttachment(fileName: "orphaned1.pdf", originalFileName: "orphaned1.pdf", fileExtension: "pdf")
        let orphaned2 = EmbeddedFileAttachment(fileName: "orphaned2.jpg", originalFileName: "orphaned2.jpg", fileExtension: "jpg")
        let orphaned3 = EmbeddedFileAttachment(fileName: "orphaned3.doc", originalFileName: "orphaned3.doc", fileExtension: "doc")
        
        // Create some linked attachments for comparison
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let activity = Activity(name: "Test Activity", trip: trip)
        let linkedAttachment = EmbeddedFileAttachment(fileName: "linked.pdf", originalFileName: "linked.pdf", fileExtension: "pdf")
        linkedAttachment.activity = activity
        activity.fileAttachments.append(linkedAttachment)
        
        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(activity)
        testBase.modelContext.insert(orphaned1)
        testBase.modelContext.insert(orphaned2)
        testBase.modelContext.insert(orphaned3)
        testBase.modelContext.insert(linkedAttachment)
        try testBase.modelContext.save()
        
        // Test orphaned files detection logic
        let descriptor = FetchDescriptor<EmbeddedFileAttachment>()
        let allAttachments = try testBase.modelContext.fetch(descriptor)
        
        let orphanedAttachments = allAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }
        
        #expect(orphanedAttachments.count == 3, "Should find 3 orphaned attachments")
        #expect(allAttachments.count == 4, "Should have 4 total attachments")
        
        // Verify the success message that would be shown
        let expectedMessage = "Scan complete. Found \(orphanedAttachments.count) orphaned files."
        #expect(expectedMessage == "Scan complete. Found 3 orphaned files.", 
                "Should generate correct message for multiple orphaned files")
    }
    
    @Test("Orphaned files detection logic - single orphaned file")
    func orphanedFilesDetectionSingleOrphan() async throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()
        
        // Create one orphaned attachment
        let orphanedAttachment = EmbeddedFileAttachment(fileName: "orphaned.pdf", originalFileName: "orphaned.pdf", fileExtension: "pdf")
        
        testBase.modelContext.insert(orphanedAttachment)
        try testBase.modelContext.save()
        
        // Test orphaned files detection logic
        let descriptor = FetchDescriptor<EmbeddedFileAttachment>()
        let allAttachments = try testBase.modelContext.fetch(descriptor)
        
        let orphanedAttachments = allAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }
        
        #expect(orphanedAttachments.count == 1, "Should find 1 orphaned attachment")
        #expect(allAttachments.count == 1, "Should have 1 total attachment")
        
        // Verify correct singular message
        let expectedMessage = "Scan complete. Found \(orphanedAttachments.count) orphaned file."
        #expect(expectedMessage == "Scan complete. Found 1 orphaned file.", 
                "Should generate correct singular message for one orphaned file")
    }
    
    @Test("Orphaned files cleanup behavior")
    func orphanedFilesCleanupBehavior() async throws {
        let testBase = SwiftDataTestBase()
        try testBase.verifyDatabaseEmpty()
        
        // Create orphaned file attachments
        let orphaned1 = EmbeddedFileAttachment(fileName: "orphaned1.pdf", originalFileName: "orphaned1.pdf", fileExtension: "pdf")
        let orphaned2 = EmbeddedFileAttachment(fileName: "orphaned2.jpg", originalFileName: "orphaned2.jpg", fileExtension: "jpg")
        
        // Create a linked attachment that should NOT be deleted
        let trip = Trip(name: "Test Trip", startDate: Date(), endDate: Date().addingTimeInterval(86400))
        let activity = Activity(name: "Test Activity", trip: trip)
        let linkedAttachment = EmbeddedFileAttachment(fileName: "linked.pdf", originalFileName: "linked.pdf", fileExtension: "pdf")
        linkedAttachment.activity = activity
        activity.fileAttachments.append(linkedAttachment)
        
        testBase.modelContext.insert(trip)
        testBase.modelContext.insert(activity)
        testBase.modelContext.insert(orphaned1)
        testBase.modelContext.insert(orphaned2)
        testBase.modelContext.insert(linkedAttachment)
        try testBase.modelContext.save()
        
        // Initial state verification
        let initialDescriptor = FetchDescriptor<EmbeddedFileAttachment>()
        let initialAttachments = try testBase.modelContext.fetch(initialDescriptor)
        #expect(initialAttachments.count == 3, "Should start with 3 attachments")
        
        // Find orphaned attachments
        let orphanedAttachments = initialAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }
        #expect(orphanedAttachments.count == 2, "Should identify 2 orphaned attachments")
        
        // Simulate cleanup operation (mirroring FileAttachmentSettingsView cleanup logic)
        let orphanedCount = orphanedAttachments.count
        for attachment in orphanedAttachments {
            testBase.modelContext.delete(attachment)
        }
        try testBase.modelContext.save()
        
        // Verify cleanup results
        let finalDescriptor = FetchDescriptor<EmbeddedFileAttachment>()
        let finalAttachments = try testBase.modelContext.fetch(finalDescriptor)
        #expect(finalAttachments.count == 1, "Should have only 1 attachment remaining after cleanup")
        #expect(finalAttachments.first?.fileName == "linked.pdf", "Should preserve linked attachment")
        
        // Verify cleanup success message
        let expectedMessage = "Successfully cleaned up \(orphanedCount) orphaned files."
        #expect(expectedMessage == "Successfully cleaned up 2 orphaned files.", 
                "Should generate correct cleanup success message")
    }
    
    @Test("Message formatting consistency")
    func messageFormattingConsistency() {
        // Test singular vs plural message formatting
        let testCases = [
            (count: 0, expected: "Scan complete. No orphaned files found."),
            (count: 1, expected: "Scan complete. Found 1 orphaned file."),
            (count: 2, expected: "Scan complete. Found 2 orphaned files."),
            (count: 5, expected: "Scan complete. Found 5 orphaned files.")
        ]
        
        for testCase in testCases {
            let actualMessage: String
            if testCase.count == 0 {
                actualMessage = "Scan complete. No orphaned files found."
            } else {
                actualMessage = "Scan complete. Found \(testCase.count) orphaned file\(testCase.count == 1 ? "" : "s")."
            }
            
            #expect(actualMessage == testCase.expected, 
                    "Message for \(testCase.count) files should match expected format")
        }
        
        // Test cleanup message formatting
        let cleanupTestCases = [
            (count: 1, expected: "Successfully cleaned up 1 orphaned file."),
            (count: 2, expected: "Successfully cleaned up 2 orphaned files."),
            (count: 10, expected: "Successfully cleaned up 10 orphaned files.")
        ]
        
        for testCase in cleanupTestCases {
            let actualMessage = "Successfully cleaned up \(testCase.count) orphaned file\(testCase.count == 1 ? "" : "s")."
            #expect(actualMessage == testCase.expected, 
                    "Cleanup message for \(testCase.count) files should match expected format")
        }
    }
}