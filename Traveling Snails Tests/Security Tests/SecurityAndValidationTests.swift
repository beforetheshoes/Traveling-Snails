//
//  SecurityAndValidationTests.swift
//  Traveling Snails
//
//


import Foundation
import Testing

@testable import Traveling_Snails

@Suite("Security and Validation Tests")
struct SecurityAndValidationTests {
    @Suite("SecureURLHandler Tests")
    struct SecureURLHandlerTests {
        @Test("Safe URL patterns")
        func safeURLPatterns() {
            let safeURLs = [
                "https://www.apple.com",
                "https://google.com",
                "mailto:user@example.com",
                "tel:+1-555-123-4567",
            ]

            for url in safeURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .safe, "URL should be safe: \(url)")
            }
        }

        @Test("Suspicious URL patterns")
        func suspiciousURLPatterns() {
            let suspiciousURLs = [
                "https://bit.ly/abc123",
                "https://tinyurl.com/example",
                "https://myapp.herokuapp.com",
            ]

            for url in suspiciousURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .suspicious, "URL should be suspicious: \(url)")
            }
        }

        @Test("Blocked URL patterns")
        func blockedURLPatterns() {
            let blockedURLs = [
                "javascript:alert('xss')",
                "ftp://files.example.com",
                "file:///etc/passwd",
            ]

            for url in blockedURLs {
                let level = SecureURLHandler.evaluateURL(url)
                #expect(level == .blocked, "URL should be blocked: \(url)")
            }
        }
    }

    @Suite("Input Validation Tests")
    struct InputValidationTests {
        @Test("Trip name validation")
        func tripNameValidation() {
            let validNames = ["My Trip", "Business Travel 2024"]
            for name in validNames {
                let trip = Trip(name: name)
                #expect(!trip.name.isEmpty)
            }

            let invalidNames = ["", " ", "   "]
            for name in invalidNames {
                let trip = Trip(name: name)
                let isValid = !trip.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                #expect(!isValid, "Name should be invalid: \(name)")
            }
        }

        @Test("Organization name validation")
        func organizationNameValidation() {
            let noneOrg = Organization(name: "None")
            #expect(noneOrg.isNone == true)

            let validOrg = Organization(name: "Valid Company")
            #expect(!validOrg.isNone)
        }
    }

    @Suite("File Type Security Tests")
    struct FileTypeSecurityTests {
        @Test("File type detection")
        func fileTypeDetection() {
            let imageAttachment = EmbeddedFileAttachment(fileExtension: "jpg")
            #expect(imageAttachment.isImage == true)

            let pdfAttachment = EmbeddedFileAttachment(fileExtension: "pdf")
            #expect(pdfAttachment.isPDF == true)

            let docAttachment = EmbeddedFileAttachment(fileExtension: "txt")
            #expect(docAttachment.isDocument == true)
        }

        @Test("System icon selection")
        func systemIconSelection() {
            let imageAttachment = EmbeddedFileAttachment(fileExtension: "png")
            #expect(imageAttachment.systemIcon == "photo")

            let unknownAttachment = EmbeddedFileAttachment(fileExtension: "xyz")
            #expect(unknownAttachment.systemIcon == "doc")
        }
    }
}
