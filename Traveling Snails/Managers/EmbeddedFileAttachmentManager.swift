//
//  EmbeddedFileAttachmentManager.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI
import QuickLook
import UniformTypeIdentifiers

@Observable
class EmbeddedFileAttachmentManager {
    static let shared = EmbeddedFileAttachmentManager()
    
    private init() {}
    
    func saveFile(from sourceURL: URL, originalName: String) -> EmbeddedFileAttachment? {
        print("📂 Embedding file from: \(sourceURL.path)")
        
        // Start accessing security scoped resource
        let hasAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard hasAccess else {
            print("❌ Failed to access security scoped resource")
            return nil
        }
        
        do {
            // Read the file data
            let fileData = try Data(contentsOf: sourceURL)
            
            guard !fileData.isEmpty else {
                print("❌ File data is empty")
                return nil
            }
            
            // Generate unique filename
            let fileExtension = sourceURL.pathExtension
            let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
            
            print("✅ File data loaded. Size: \(fileData.count) bytes")
            
            // Create file attachment with embedded data
            let attachment = EmbeddedFileAttachment(
                fileName: uniqueFileName,
                originalFileName: originalName,
                fileSize: Int64(fileData.count),
                mimeType: getMimeType(for: sourceURL),
                fileExtension: fileExtension,
                fileData: fileData
            )
            
            print("✅ EmbeddedFileAttachment created: \(attachment.fileName)")
            return attachment
            
        } catch {
            print("❌ Failed to read file data: \(error)")
            return nil
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
        return attachment.fileData
    }
    
    private func getMimeType(for url: URL) -> String {
        if let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}
