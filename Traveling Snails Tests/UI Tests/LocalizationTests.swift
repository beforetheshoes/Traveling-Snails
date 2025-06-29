//
//  LocalizationTests.swift
//  Traveling Snails Tests
//
//

import Foundation
import Testing
@testable import Traveling_Snails

@Suite("File Attachment Localization Tests")
struct FileAttachmentLocalizationTests {
    @Test("File attachments localization keys should return proper text")
    func fileAttachmentsLocalizationTest() {
        // Test the L() function with file attachment keys
        let titleText = L(L10n.FileAttachments.title)
        let noAttachmentsText = L(L10n.FileAttachments.noAttachments)
        let noAttachmentsDescText = L(L10n.FileAttachments.noAttachmentsDescription)

        // These should return the actual English text, not the keys
        #expect(titleText == "Attachments", "Expected 'Attachments' but got '\(titleText)'")
        #expect(noAttachmentsText == "No attachments yet", "Expected 'No attachments yet' but got '\(noAttachmentsText)'")
        #expect(noAttachmentsDescText == "Add files to keep them with this activity", "Expected description but got '\(noAttachmentsDescText)'")
    }

    @Test("General localization keys should work")
    func generalLocalizationTest() {
        let cancelText = L(L10n.General.cancel)
        let saveText = L(L10n.General.save)
        let editText = L(L10n.General.edit)

        #expect(cancelText == "Cancel", "Expected 'Cancel' but got '\(cancelText)'")
        #expect(saveText == "Save", "Expected 'Save' but got '\(saveText)'")
        #expect(editText == "Edit", "Expected 'Edit' but got '\(editText)'")
    }

    @Test("Localization manager should load English bundle")
    func localizationManagerTest() {
        let manager = LocalizationManager.shared
        let currentLanguage = manager.currentLanguage

        // Should default to English or current system language
        #expect(!currentLanguage.isEmpty, "Current language should not be empty")

        // Test direct string localization
        let testKey = "file_attachments.title"
        let localizedString = manager.localizedString(for: testKey)

        #expect(localizedString == "Attachments", "Expected 'Attachments' but got '\(localizedString)'")
    }
}
