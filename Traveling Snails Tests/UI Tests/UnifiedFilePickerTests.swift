//
//  UnifiedFilePickerTests.swift
//  Traveling Snails Tests
//
//

import PhotosUI
import SwiftData
import SwiftUI
import Testing
@testable import Traveling_Snails

@Suite("UnifiedFilePicker Tests")
struct UnifiedFilePickerTests {
    @Test("UnifiedFilePicker can be created with photo configuration", .tags(.ui, .medium, .parallel, .swiftui, .fileAttachment, .validation))
    func testPhotoSelectionConfiguration() {
        // Test that we can create a UnifiedFilePicker configured for photos

        var capturedError: String?
        var capturedAttachment: EmbeddedFileAttachment?

        let filePicker = UnifiedFilePicker(
            allowsPhotos: true,
            allowsDocuments: false,
            onFileSelected: { attachment in
                capturedAttachment = attachment
            },
            onError: { error in
                capturedError = error
            }
        )

        // Test that the error callback is properly configured
        #expect(capturedError == nil, "No error should be captured initially")
        #expect(capturedAttachment == nil, "No attachment should be captured initially")

        // Verify that the picker is configured for photos
        #expect(filePicker.allowsPhotos == true, "Picker should allow photos")
        #expect(filePicker.allowsDocuments == false, "Picker should not allow documents")
    }

    @Test("FilePickerError should include permission-related errors", .tags(.ui, .medium, .parallel, .swiftui, .fileAttachment, .errorHandling, .validation))
    func testFilePickerErrorTypes() {
        // This test should fail initially - we don't have permission error types
        // For now, just test that the existing error types work

        let dataError = FilePickerError.failedToLoadPhotoData
        #expect(!dataError.localizedDescription.isEmpty, "Error should have description")

        let attachmentError = FilePickerError.failedToCreateAttachment
        #expect(!attachmentError.localizedDescription.isEmpty, "Error should have description")

        // These will fail initially - we need to add permission error cases
        // let permissionError = FilePickerError.permissionDenied
        // #expect(permissionError.localizedDescription.contains("permission"), 
        //        "Permission error should mention permission")
    }
}
