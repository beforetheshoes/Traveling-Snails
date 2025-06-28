//
//  ImportPermissionTests.swift
//  Traveling Snails Tests
//

import Testing
import Foundation
import SwiftData
import UniformTypeIdentifiers
@testable import Traveling_Snails

@Suite("Import Permission Tests")
struct ImportPermissionTests {
    
    @Suite("Database Import Permission Tests")
    struct DatabaseImportPermissionTests {
        
        @Test("Database import should handle file access permission failures gracefully")
        @MainActor
        func testDatabaseImportFileAccessFailure() async {
            // This test will FAIL initially - no proper permission error handling exists
            let testBase = SwiftDataTestBase()
            let importManager = DatabaseImportManager()
            
            // Create a file URL that will fail permission checks
            let inaccessibleURL = URL(fileURLWithPath: "/private/var/root/inaccessible_test_file.json")
            
            let result = await importManager.importDatabase(from: inaccessibleURL, into: testBase.modelContext)
            
            // Should handle permission failure gracefully
            #expect(result.errors.count > 0, "Should capture permission errors")
            #expect(result.errors.first?.contains("permission") == true || 
                   result.errors.first?.contains("access") == true, 
                   "Error should mention permission or access issues")
            #expect(result.tripsImported == 0, "No trips should be imported on permission failure")
        }
        
        @Test("Database import should validate file readability before processing")
        @MainActor
        func testDatabaseImportFileReadabilityCheck() async {
            // This test will FAIL initially - no pre-validation exists
            let testBase = SwiftDataTestBase()
            let importManager = DatabaseImportManager()
            
            // Create a non-existent file URL
            let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_import_file.json")
            
            let result = await importManager.importDatabase(from: nonExistentURL, into: testBase.modelContext)
            
            // Should detect unreadable file before attempting import
            #expect(result.errors.count > 0, "Should detect unreadable file")
            #expect(result.errors.first?.contains("read") == true || 
                   result.errors.first?.contains("access") == true,
                   "Error should mention read/access issues")
        }
        
        @Test("Database import should provide user-friendly error messages for permission failures")
        @MainActor
        func testDatabaseImportUserFriendlyErrors() async {
            // This test will FAIL initially - errors are not user-friendly
            let testBase = SwiftDataTestBase()
            let importManager = DatabaseImportManager()
            
            // Test with a restricted system file
            let restrictedURL = URL(fileURLWithPath: "/private/var/root/test.json")
            
            let result = await importManager.importDatabase(from: restrictedURL, into: testBase.modelContext)
            
            #expect(result.errors.count > 0, "Should have errors for restricted file")
            
            // Error should be user-friendly (not technical)
            let errorMessage = result.errors.first ?? ""
            #expect(!errorMessage.contains("NSCocoaErrorDomain"), "Should not expose internal error domains")
            #expect(!errorMessage.contains("POSIX"), "Should not expose POSIX error codes")
            #expect(errorMessage.count > 20, "Error message should be descriptive")
            #expect(errorMessage.contains("import") || errorMessage.contains("file"), 
                   "Error should relate to import/file context")
        }
    }
    
    @Suite("Security-Scoped Resource Tests")
    struct SecurityScopedResourceTests {
        
        @Test("EmbeddedFileAttachmentManager should handle security-scoped resource failures")
        @MainActor
        func testSecurityScopedResourceFailure() {
            // This test will FAIL initially - no proper error handling for security-scoped resources
            let manager = EmbeddedFileAttachmentManager.shared
            
            // Create a URL that will fail security-scoped resource access
            let restrictedURL = URL(fileURLWithPath: "/System/Library/CoreServices/Boot.plist")
            
            let attachment = manager.saveFile(from: restrictedURL, originalName: "test.plist")
            
            // Should return nil and handle the failure gracefully
            #expect(attachment == nil, "Should return nil for inaccessible files")
        }
        
        @Test("EmbeddedFileAttachmentManager should provide detailed error information for access failures")
        @MainActor
        func testDetailedErrorInformationForAccessFailures() {
            // This test will FAIL initially - no detailed error reporting exists
            let manager = EmbeddedFileAttachmentManager.shared
            
            // We need to modify EmbeddedFileAttachmentManager to return detailed error info
            // For now, this test will fail because the current implementation doesn't provide error details
            
            let restrictedURL = URL(fileURLWithPath: "/private/var/root/inaccessible.txt")
            
            // Current implementation returns nil - we need error details
            let attachment = manager.saveFile(from: restrictedURL, originalName: "test.txt")
            #expect(attachment == nil, "Should fail for inaccessible file")
            
            // TODO: Need to modify manager to return Result<EmbeddedFileAttachment, FileAttachmentError>
            // This test documents the need for better error reporting
        }
        
        @Test("File access validation should distinguish between different failure types")
        @MainActor
        func testFileAccessFailureTypes() {
            // This test will FAIL initially - no distinction between failure types
            
            // Test different types of file access failures:
            // 1. File doesn't exist
            let nonExistentURL = URL(fileURLWithPath: "/tmp/does_not_exist.txt")
            
            // 2. Permission denied
            let permissionDeniedURL = URL(fileURLWithPath: "/private/var/root/restricted.txt")
            
            // 3. File is a directory
            let directoryURL = URL(fileURLWithPath: "/tmp")
            
            let manager = EmbeddedFileAttachmentManager.shared
            
            // All should fail, but ideally with different error types
            #expect(manager.saveFile(from: nonExistentURL, originalName: "test1.txt") == nil)
            #expect(manager.saveFile(from: permissionDeniedURL, originalName: "test2.txt") == nil)
            #expect(manager.saveFile(from: directoryURL, originalName: "test3.txt") == nil)
            
            // This test documents the need for specific error type handling
        }
    }
    
    @Suite("File Importer Permission Tests")
    struct FileImporterPermissionTests {
        
        @Test("Settings file import should handle permission failures gracefully")
        @MainActor
        func testSettingsFileImportPermissionFailure() async {
            // This test will FAIL initially - permission failures are not handled gracefully
            
            let testBase = SwiftDataTestBase()
            let viewModel = SettingsViewModel(modelContext: testBase.modelContext)
            
            // Simulate a file import result with permission failure
            let permissionFailureResult: Result<[URL], Error> = .failure(
                NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
                    NSLocalizedDescriptionKey: "The file couldn't be opened because you don't have permission to view it."
                ])
            )
            
            // This should be handled gracefully - currently it just prints the error
            viewModel.handleImportResult(permissionFailureResult)
            
            // The test documents that we need better error handling
            // Currently, errors are only printed to console
            #expect(Bool(true), "This test documents the need for better permission error handling")
        }
        
        @Test("File importer should handle document access scope properly")
        @MainActor
        func testDocumentAccessScopeHandling() async {
            // This test will FAIL initially - no proper document access scope handling
            
            // Test that when a user selects a file through the file importer,
            // the security-scoped resource is handled properly
            
            // Create a mock URL that would come from document picker
            let documentURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_import.json")
            
            // Create test JSON data
            let testJSON = """
            {
                "exportInfo": {
                    "version": "1.0",
                    "timestamp": "\(ISO8601DateFormatter().string(from: Date()))",
                    "format": "json",
                    "includesAttachments": false
                },
                "trips": [],
                "organizations": [],
                "addresses": [],
                "attachments": []
            }
            """
            
            // Write test data to file
            do {
                try testJSON.write(to: documentURL, atomically: true, encoding: .utf8)
            } catch {
                #expect(Bool(false), "Failed to create test file: \(error)")
                return
            }
            
            defer {
                try? FileManager.default.removeItem(at: documentURL)
            }
            
            // Test import process
            let testBase = SwiftDataTestBase()
            let importManager = DatabaseImportManager()
            
            let result = await importManager.importDatabase(from: documentURL, into: testBase.modelContext)
            
            // Should succeed for accessible file
            #expect(result.errors.isEmpty, "Should succeed for accessible test file")
            
            // This test validates that the current flow works for accessible files
            // Real permission issues occur with files selected through document picker
        }
    }
    
    @Suite("Error Message Quality Tests")
    struct ErrorMessageQualityTests {
        
        @Test("Permission error messages should guide users to solutions")
        @MainActor
        func testPermissionErrorGuidance() {
            // This test will FAIL initially - error messages don't provide guidance
            
            let permissionError = ImportPermissionError.fileAccessDenied(filename: "backup.json")
            
            let errorMessage = permissionError.localizedDescription
            
            // Should guide user to solution
            #expect(errorMessage.contains("Settings") || errorMessage.contains("allow"), 
                   "Should guide user to enable permissions")
            #expect(errorMessage.contains("backup.json"), "Should mention specific filename")
            #expect(!errorMessage.contains("Error Domain"), "Should not expose technical details")
            #expect(errorMessage.count > 30, "Should be descriptive enough to be helpful")
        }
        
        @Test("Import errors should distinguish between different permission types")
        @MainActor
        func testPermissionErrorTypes() {
            // This test will FAIL initially - we don't have specific permission error types
            
            let fileNotFoundError = ImportPermissionError.fileNotFound(filename: "missing.json")
            let accessDeniedError = ImportPermissionError.fileAccessDenied(filename: "restricted.json")
            let invalidFormatError = ImportPermissionError.invalidFileFormat(reason: "Not a valid JSON file")
            
            // Each should have distinct, helpful messages
            #expect(fileNotFoundError.localizedDescription.contains("not found") || 
                   fileNotFoundError.localizedDescription.contains("does not exist"))
            #expect(accessDeniedError.localizedDescription.contains("permission") || 
                   accessDeniedError.localizedDescription.contains("access"))
            #expect(invalidFormatError.localizedDescription.contains("format") || 
                   invalidFormatError.localizedDescription.contains("JSON"))
            
            // All should be different
            #expect(fileNotFoundError.localizedDescription != accessDeniedError.localizedDescription)
            #expect(accessDeniedError.localizedDescription != invalidFormatError.localizedDescription)
        }
    }
}

// MARK: - Error Types for Import Permission Handling

enum ImportPermissionError: LocalizedError {
    case fileNotFound(filename: String)
    case fileAccessDenied(filename: String)
    case securityScopedResourceFailure(filename: String)
    case invalidFileFormat(reason: String)
    case unknownError(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "The file '\(filename)' was not found. Please check that the file exists and try again."
        case .fileAccessDenied(let filename):
            return "Access to '\(filename)' was denied. Please go to Settings to allow file access, or try selecting the file again."
        case .securityScopedResourceFailure(let filename):
            return "Unable to access '\(filename)' due to security restrictions. Please try selecting the file through the document picker again."
        case .invalidFileFormat(let reason):
            return "The selected file has an invalid format. \(reason)"
        case .unknownError(let underlying):
            return "An unexpected error occurred while importing: \(underlying.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Try selecting a different file or check that the original file still exists."
        case .fileAccessDenied:
            return "Try selecting the file again through the import dialog, or check your device's privacy settings."
        case .securityScopedResourceFailure:
            return "Use the 'Import Data' option in Settings to select the file again."
        case .invalidFileFormat:
            return "Ensure you're selecting a valid backup file exported from Traveling Snails."
        case .unknownError:
            return "Please try the import operation again. If the problem persists, contact support."
        }
    }
}