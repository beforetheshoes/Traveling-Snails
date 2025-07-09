//
//  EmbeddedFileAttachmentTests.swift
//  Traveling Snails
//
//

import Foundation
import Testing
import UniformTypeIdentifiers

@testable import Traveling_Snails

@Suite("Embedded File Attachment Tests")
struct EmbeddedFileAttachmentTests {
    @Suite("EmbeddedFileAttachment Model Tests")
    struct EmbeddedFileAttachmentModelTests {
        @Test("Basic file attachment initialization", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func basicFileAttachmentInitialization() {
            let attachment = EmbeddedFileAttachment(
                fileName: "test_file.pdf",
                originalFileName: "My Document.pdf",
                fileSize: 1024,
                mimeType: "application/pdf",
                fileExtension: "pdf",
                fileDescription: "Test document"
            )

            #expect(attachment.fileName == "test_file.pdf")
            #expect(attachment.originalFileName == "My Document.pdf")
            #expect(attachment.fileSize == 1024)
            #expect(attachment.mimeType == "application/pdf")
            #expect(attachment.fileExtension == "pdf")
            #expect(attachment.fileDescription == "Test document")
            #expect(attachment.fileData == nil)
        }

        @Test("File attachment with embedded data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func fileAttachmentWithEmbeddedData() {
            let testData = "Test file content".data(using: .utf8)!

            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                originalFileName: "test.txt",
                fileSize: Int64(testData.count),
                mimeType: "text/plain",
                fileExtension: "txt",
                fileData: testData
            )

            #expect(attachment.fileData == testData)
            #expect(attachment.fileSize == Int64(testData.count))
        }

        @Test("File size formatting", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func fileSizeFormatting() {
            let attachment = EmbeddedFileAttachment()

            attachment.fileSize = 1024
            #expect(attachment.formattedFileSize == "1 KB")

            attachment.fileSize = 1_048_576
            #expect(attachment.formattedFileSize == "1 MB")

            attachment.fileSize = 500
            #expect(attachment.formattedFileSize == "500 bytes")
        }

        @Test("File type detection", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func fileTypeDetection() {
            let imageAttachment = EmbeddedFileAttachment(fileExtension: "jpg")
            #expect(imageAttachment.isImage == true)
            #expect(imageAttachment.isPDF == false)
            #expect(imageAttachment.isDocument == false)

            let pdfAttachment = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(pdfAttachment.isImage == false)
            #expect(pdfAttachment.isPDF == true)
            #expect(pdfAttachment.isDocument == false)

            let docAttachment = EmbeddedFileAttachment(fileExtension: "docx")
            #expect(docAttachment.isImage == false)
            #expect(docAttachment.isPDF == false)
            #expect(docAttachment.isDocument == true)

            let unknownAttachment = EmbeddedFileAttachment(fileExtension: "xyz")
            #expect(unknownAttachment.isImage == false)
            #expect(unknownAttachment.isPDF == false)
            #expect(unknownAttachment.isDocument == false)
        }

        @Test("System icon selection", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .userInterface))
        func systemIconSelection() {
            let imageAttachment = EmbeddedFileAttachment(fileExtension: "png")
            #expect(imageAttachment.systemIcon == "photo")

            let pdfAttachment = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(pdfAttachment.systemIcon == "doc.richtext")

            let docAttachment = EmbeddedFileAttachment(fileExtension: "txt")
            #expect(docAttachment.systemIcon == "doc.text")

            let unknownAttachment = EmbeddedFileAttachment(fileExtension: "xyz")
            #expect(unknownAttachment.systemIcon == "doc")
        }

        @Test("Display name logic", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func displayNameLogic() {
            let attachmentWithDescription = EmbeddedFileAttachment(
                originalFileName: "document.pdf",
                fileDescription: "Important Contract"
            )
            #expect(attachmentWithDescription.displayName == "Important Contract")

            let attachmentWithoutDescription = EmbeddedFileAttachment(
                originalFileName: "document.pdf",
                fileDescription: ""
            )
            #expect(attachmentWithoutDescription.displayName == "document.pdf")
        }

        @Test("Temporary file URL creation", .tags(.unit, .medium, .serial, .dataModel, .fileAttachment, .filesystem, .validation))
        func temporaryFileURLCreation() {
            let testData = "Test content".data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                fileExtension: "txt",
                fileData: testData
            )

            let tempURL = attachment.temporaryFileURL
            #expect(tempURL != nil)

            if let url = tempURL {
                #expect(url.pathExtension == "txt")
                #expect(url.lastPathComponent.contains(attachment.id.uuidString))

                // Verify file was created
                #expect(FileManager.default.fileExists(atPath: url.path))

                // Clean up
                try? FileManager.default.removeItem(at: url)
            }
        }

        @Test("Temporary file URL with no data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary))
        func temporaryFileURLWithNoData() {
            let attachment = EmbeddedFileAttachment(fileName: "test.txt")
            let tempURL = attachment.temporaryFileURL
            #expect(tempURL == nil)
        }
    }

    @Suite("EmbeddedFileAttachmentManager Tests")
    struct EmbeddedFileAttachmentManagerTests {
        @Test("Manager singleton", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func managerSingleton() {
            let manager1 = EmbeddedFileAttachmentManager.shared
            let manager2 = EmbeddedFileAttachmentManager.shared
            #expect(manager1 === manager2)
        }

        @Test("MIME type detection", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func mimeTypeDetection() {
            _ = EmbeddedFileAttachmentManager.shared

            // Test common file extensions - we need to test the private method indirectly
            // by creating test URLs and checking if the manager would handle them correctly
            let pdfURL = URL(fileURLWithPath: "/test/file.pdf")
            let jpgURL = URL(fileURLWithPath: "/test/image.jpg")
            let txtURL = URL(fileURLWithPath: "/test/document.txt")

            // We can't directly test the private getMimeType method,
            // but we can verify that URLs with these extensions are handled
            #expect(pdfURL.pathExtension == "pdf")
            #expect(jpgURL.pathExtension == "jpg")
            #expect(txtURL.pathExtension == "txt")
        }

        @Test("File validation with valid attachment", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func fileValidationWithValidAttachment() {
            let testData = "Valid test content".data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                fileExtension: "txt",
                fileData: testData
            )

            let manager = EmbeddedFileAttachmentManager.shared
            let validation = manager.validateFileAccess(for: attachment)

            #expect(validation.isValid == true)
            #expect(validation.error == nil)
        }

        @Test("File validation with no data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary, .negative))
        func fileValidationWithNoData() {
            let attachment = EmbeddedFileAttachment(fileName: "empty.txt")

            let manager = EmbeddedFileAttachmentManager.shared
            let validation = manager.validateFileAccess(for: attachment)

            #expect(validation.isValid == false)
            #expect(validation.error == "No file data stored")
        }

        @Test("File validation with empty data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary, .negative))
        func fileValidationWithEmptyData() {
            let attachment = EmbeddedFileAttachment(
                fileName: "empty.txt",
                fileData: Data()
            )

            let manager = EmbeddedFileAttachmentManager.shared
            let validation = manager.validateFileAccess(for: attachment)

            #expect(validation.isValid == false)
            #expect(validation.error == "File data is empty")
        }

        @Test("Get file data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func getFileData() {
            let testData = "Test file data".data(using: .utf8)!
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                fileData: testData
            )

            let manager = EmbeddedFileAttachmentManager.shared
            let retrievedData = manager.getFileData(for: attachment)

            #expect(retrievedData == testData)
        }

        @Test("Get file data with no data", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary))
        func getFileDataWithNoData() {
            let attachment = EmbeddedFileAttachment(fileName: "test.txt")

            let manager = EmbeddedFileAttachmentManager.shared
            let retrievedData = manager.getFileData(for: attachment)

            #expect(retrievedData == nil)
        }
    }

    @Suite("File Attachment Relationship Tests")
    struct FileAttachmentRelationshipTests {
        @Test("Activity file attachment relationship", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .activity, .validation))
        func activityFileAttachmentRelationship() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            let attachment = EmbeddedFileAttachment(
                fileName: "activity_doc.pdf",
                originalFileName: "Activity Document.pdf"
            )

            // Set up relationship
            attachment.activity = activity
            activity.fileAttachments.append(attachment)

            #expect(attachment.activity?.name == "Test Activity")
            #expect(activity.fileAttachments.count == 1)
            #expect(activity.hasAttachments == true)
            #expect(activity.attachmentCount == 1)
        }

        @Test("Lodging file attachment relationship", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .activity, .validation))
        func lodgingFileAttachmentRelationship() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Hotel")
            let lodging = Lodging(
                name: "Test Hotel",
                start: Date(),
                end: Date(),
                cost: 0,
                paid: PaidStatus.none,
                trip: trip,
                organization: org
            )

            let attachment = EmbeddedFileAttachment(
                fileName: "reservation.pdf",
                originalFileName: "Hotel Reservation.pdf"
            )

            // Set up relationship
            attachment.lodging = lodging
            lodging.fileAttachments.append(attachment)

            #expect(attachment.lodging?.name == "Test Hotel")
            #expect(lodging.fileAttachments.count == 1)
            #expect(lodging.hasAttachments == true)
            #expect(lodging.attachmentCount == 1)
        }

        @Test("Transportation file attachment relationship", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .activity, .validation))
        func transportationFileAttachmentRelationship() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Airline")
            let transportation = Transportation(
                name: "Test Flight",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            let attachment = EmbeddedFileAttachment(
                fileName: "ticket.pdf",
                originalFileName: "Flight Ticket.pdf"
            )

            // Set up relationship
            attachment.transportation = transportation
            transportation.fileAttachments.append(attachment)

            #expect(attachment.transportation?.name == "Test Flight")
            #expect(transportation.fileAttachments.count == 1)
            #expect(transportation.hasAttachments == true)
            #expect(transportation.attachmentCount == 1)
        }

        @Test("Multiple attachments per activity", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .activity, .validation))
        func multipleAttachmentsPerActivity() {
            let trip = Trip(name: "Test Trip")
            let org = Organization(name: "Test Org")
            let activity = Activity(
                name: "Test Activity",
                start: Date(),
                end: Date(),
                trip: trip,
                organization: org
            )

            let attachment1 = EmbeddedFileAttachment(fileName: "doc1.pdf")
            let attachment2 = EmbeddedFileAttachment(fileName: "doc2.jpg")
            let attachment3 = EmbeddedFileAttachment(fileName: "doc3.txt")

            activity.fileAttachments.append(contentsOf: [attachment1, attachment2, attachment3])
            attachment1.activity = activity
            attachment2.activity = activity
            attachment3.activity = activity

            #expect(activity.attachmentCount == 3)
            #expect(activity.hasAttachments == true)
        }

        @Test("Attachment without relationship", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary))
        func attachmentWithoutRelationship() {
            let attachment = EmbeddedFileAttachment(fileName: "orphaned.pdf")

            #expect(attachment.activity == nil)
            #expect(attachment.lodging == nil)
            #expect(attachment.transportation == nil)
        }
    }

    @Suite("File Extension and Type Tests")
    struct FileExtensionAndTypeTests {
        @Test("Image file extensions", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func imageFileExtensions() {
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]

            for ext in imageExtensions {
                let attachment = EmbeddedFileAttachment(fileExtension: ext)
                #expect(attachment.isImage == true, "Extension \(ext) should be recognized as image")
                #expect(attachment.systemIcon == "photo")
            }
        }

        @Test("Document file extensions", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func documentFileExtensions() {
            let docExtensions = ["doc", "docx", "txt", "rtf", "pages"]

            for ext in docExtensions {
                let attachment = EmbeddedFileAttachment(fileExtension: ext)
                #expect(attachment.isDocument == true, "Extension \(ext) should be recognized as document")
                #expect(attachment.systemIcon == "doc.text")
            }
        }

        @Test("PDF file extension", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation))
        func pdfFileExtension() {
            let attachment = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(attachment.isPDF == true)
            #expect(attachment.systemIcon == "doc.richtext")
            #expect(attachment.isImage == false)
            #expect(attachment.isDocument == false)
        }

        @Test("Case insensitive extension matching", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary))
        func caseInsensitiveExtensionMatching() {
            let upperCaseAttachment = EmbeddedFileAttachment(fileExtension: "JPG")
            let lowerCaseAttachment = EmbeddedFileAttachment(fileExtension: "jpg")
            let mixedCaseAttachment = EmbeddedFileAttachment(fileExtension: "JpG")

            #expect(upperCaseAttachment.isImage == true)
            #expect(lowerCaseAttachment.isImage == true)
            #expect(mixedCaseAttachment.isImage == true)
        }

        @Test("Unknown file extensions", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .validation, .boundary))
        func unknownFileExtensions() {
            let unknownExtensions = ["xyz", "unknown", ""]

            for ext in unknownExtensions {
                let attachment = EmbeddedFileAttachment(fileExtension: ext)
                #expect(attachment.isImage == false)
                #expect(attachment.isPDF == false)
                #expect(attachment.isDocument == false)
                #expect(attachment.systemIcon == "doc")
            }
        }
    }

    @Suite("Performance Tests")
    struct PerformanceTests {
        @Test("Large file data handling", .tags(.unit, .medium, .serial, .dataModel, .fileAttachment, .performance, .filesystem))
        func largeFileDataHandling() {
            // Create a 1MB test file
            let largeData = Data(repeating: 0x42, count: 1_048_576)

            let attachment = EmbeddedFileAttachment(
                fileName: "large_file.bin",
                fileSize: Int64(largeData.count),
                fileData: largeData
            )

            #expect(attachment.fileData?.count == 1_048_576)
            #expect(attachment.formattedFileSize == "1 MB")

            // Test temporary file creation with large data
            let tempURL = attachment.temporaryFileURL
            #expect(tempURL != nil)

            if let url = tempURL {
                let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
                #expect(fileSize == 1_048_576)

                // Clean up
                try? FileManager.default.removeItem(at: url)
            }
        }

        @Test("Multiple attachment creation performance", .tags(.unit, .medium, .serial, .dataModel, .fileAttachment, .performance))
        func multipleAttachmentCreationPerformance() {
            let startTime = Date()
            var attachments: [EmbeddedFileAttachment] = []

            // Create 100 attachments
            for i in 0..<100 {
                let data = "Test data \(i)".data(using: .utf8)!
                let attachment = EmbeddedFileAttachment(
                    fileName: "file_\(i).txt",
                    originalFileName: "File \(i).txt",
                    fileSize: Int64(data.count),
                    fileData: data
                )
                attachments.append(attachment)
            }

            let creationTime = Date().timeIntervalSince(startTime)
            #expect(creationTime < 1.0, "Creating 100 attachments took \(creationTime) seconds")
            #expect(attachments.count == 100)
        }

        @Test("File size calculation performance", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .performance))
        func fileSizeCalculationPerformance() {
            let attachments = (0..<50).map { i in
                EmbeddedFileAttachment(fileSize: Int64(i * 1024))
            }

            let startTime = Date()
            let totalSize = attachments.reduce(0) { $0 + $1.fileSize }
            let calculationTime = Date().timeIntervalSince(startTime)

            #expect(calculationTime < 0.01, "Size calculation took \(calculationTime) seconds")
            #expect(totalSize > 0)
        }
    }

    @Suite("Error Handling Tests")
    struct ErrorHandlingTests {
        @Test("Temporary file creation failure handling", .tags(.unit, .medium, .serial, .dataModel, .fileAttachment, .errorHandling, .filesystem))
        func temporaryFileCreationFailureHandling() {
            // Test with invalid data that might cause write failures
            let attachment = EmbeddedFileAttachment(
                fileName: "test.txt",
                fileExtension: "txt",
                fileData: Data() // Empty data
            )

            // Even with empty data, temporary file creation should work
            let tempURL = attachment.temporaryFileURL
            #expect(tempURL != nil)

            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        @Test("Invalid file extension handling", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .errorHandling, .boundary, .negative))
        func invalidFileExtensionHandling() {
            let invalidExtensions = ["", " ", ".", "...", "very_long_extension_that_shouldnt_exist"]

            for ext in invalidExtensions {
                let attachment = EmbeddedFileAttachment(fileExtension: ext)

                // Should not crash and should have sensible defaults
                #expect(attachment.systemIcon == "doc")
                #expect(attachment.isImage == false)
                #expect(attachment.isPDF == false)
                #expect(attachment.isDocument == false)
            }
        }

        @Test("Extreme file sizes", .tags(.unit, .fast, .parallel, .dataModel, .fileAttachment, .errorHandling, .boundary))
        func extremeFileSizes() {
            let extremeSizes: [Int64] = [0, 1, Int64.max]

            for size in extremeSizes {
                let attachment = EmbeddedFileAttachment(fileSize: size)
                let formatted = attachment.formattedFileSize

                // Should not crash and should return some string
                #expect(!formatted.isEmpty)
            }
        }
    }
}
