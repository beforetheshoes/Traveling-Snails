//
//  EmbeddedFileAttachmentManager.swift
//  Traveling Snails
//
//

import Foundation
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@Observable
class EmbeddedFileAttachmentManager {
    static let shared = EmbeddedFileAttachmentManager()

    private init() {}

    func saveFile(from sourceURL: URL, originalName: String) -> EmbeddedFileAttachment? {
        // This is the existing method - keeping for compatibility
        switch saveFileWithResult(from: sourceURL, originalName: originalName) {
        case .success(let attachment):
            return attachment
        case .failure(let error):
            Logger.secure(category: .fileAttachment).error("File save failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func saveFileWithResult(from sourceURL: URL, originalName: String) -> Result<EmbeddedFileAttachment, FileAttachmentError> {
        #if DEBUG
        Logger.secure(category: .fileAttachment).debug("Embedding file from: \(sourceURL.path, privacy: .public)")
        #endif

        // Check if this is a temporary file (created by us) or a security scoped resource
        let isTemporaryFile = sourceURL.path.contains(FileManager.default.temporaryDirectory.path)

        var hasAccess = true
        if !isTemporaryFile {
            // Only try to access security scoped resource for external files
            hasAccess = sourceURL.startAccessingSecurityScopedResource()
        }

        defer {
            if hasAccess && !isTemporaryFile {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard hasAccess else {
            Logger.secure(category: .fileAttachment).error("Failed to access security scoped resource for file: \(sourceURL.path, privacy: .public)")
            Logger.secure(category: .fileAttachment).error("This typically happens when the file was selected through a file picker but the security scope has expired")
            Logger.secure(category: .fileAttachment).error("User should try selecting the file again through the document picker")
            return .failure(.securityScopedResourceAccessDenied(filename: originalName))
        }

        do {
            // Read the file data
            let fileData = try Data(contentsOf: sourceURL)
            #if DEBUG
            Logger.secure(category: .fileAttachment).debug("File data read successfully. Size: \(fileData.count, privacy: .public) bytes")
            #endif

            guard !fileData.isEmpty else {
                Logger.secure(category: .fileAttachment).error("File data is empty for file: \(sourceURL.path, privacy: .public)")
                return .failure(.fileDataEmpty(filename: originalName))
            }

            // Generate unique filename
            let fileExtension = sourceURL.pathExtension
            let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
            let mimeType = getMimeType(for: sourceURL)

            #if DEBUG
            Logger.secure(category: .fileAttachment).debug("File details - Extension: \(fileExtension, privacy: .public), MIME: \(mimeType, privacy: .public), Original: \(originalName, privacy: .public)")
            #endif

            // Create file attachment with embedded data
            let attachment = EmbeddedFileAttachment(
                fileName: uniqueFileName,
                originalFileName: originalName,
                fileSize: Int64(fileData.count),
                mimeType: mimeType,
                fileExtension: fileExtension,
                fileData: fileData
            )

            #if DEBUG
            Logger.secure(category: .fileAttachment).debug("EmbeddedFileAttachment created successfully")
            Logger.secure(category: .fileAttachment).debug("ID: \(attachment.id, privacy: .public)")
            #endif
            #if DEBUG
            Logger.secure(category: .fileAttachment).debug("File attachment created - Extension: \(attachment.fileExtension, privacy: .public), Size: \(attachment.fileSize, privacy: .public) bytes")
            #endif

            return .success(attachment)
        } catch {
            Logger.secure(category: .fileAttachment).error("Failed to read file data")
            Logger.secure(category: .fileAttachment).error("File read error: \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            if let nsError = error as NSError? {
                Logger.secure(category: .fileAttachment).debug("NSError domain: \(nsError.domain, privacy: .public), code: \(nsError.code, privacy: .public)")
            }
            #endif
            return .failure(.fileReadError(filename: originalName, underlying: error))
        }
    }

    func validateFileAccess(for attachment: EmbeddedFileAttachment) -> (isValid: Bool, error: String?) {
        guard let data = attachment.fileData else {
            return (false, "No file data stored")
        }

        guard !data.isEmpty else {
            return (false, "File data is empty")
        }

        // Create temporary file to test QuickLook compatibility
        guard let tempURL = attachment.temporaryFileURL else {
            return (false, "Cannot create temporary file")
        }

        let canPreview = QLPreviewController.canPreview(tempURL as QLPreviewItem)

        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)

        if !canPreview {
            return (false, "File type cannot be previewed")
        }

        return (true, nil)
    }

    func getFileData(for attachment: EmbeddedFileAttachment) -> Data? {
        attachment.fileData
    }

    private func getMimeType(for url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

// MARK: - File Attachment Error Types

enum FileAttachmentError: LocalizedError {
    case securityScopedResourceAccessDenied(filename: String)
    case fileDataEmpty(filename: String)
    case fileReadError(filename: String, underlying: Error)
    case unknownError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .securityScopedResourceAccessDenied(let filename):
            return "Unable to access '\(filename)'. Please try selecting the file again through the file picker."
        case .fileDataEmpty(let filename):
            return "The file '\(filename)' appears to be empty and cannot be attached."
        case .fileReadError(let filename, let underlying):
            return "Failed to read '\(filename)': \(underlying.localizedDescription)"
        case .unknownError(let underlying):
            return "An unexpected error occurred: \(underlying.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .securityScopedResourceAccessDenied:
            return "Use the file picker to select the file again. This grants the app temporary access to read the file."
        case .fileDataEmpty:
            return "Please check that the file contains data and try selecting a different file."
        case .fileReadError:
            return "Ensure the file exists and you have permission to read it, then try again."
        case .unknownError:
            return "Please try the operation again. If the problem persists, contact support."
        }
    }
}
