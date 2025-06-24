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
            print("❌ Failed to access security scoped resource")
            return nil
        }
        
        do {
            // Read the file data
            let fileData = try Data(contentsOf: sourceURL)
            print("📊 File data read successfully. Size: \(fileData.count) bytes")
            
            guard !fileData.isEmpty else {
                print("❌ File data is empty for file: \(sourceURL.path)")
                return nil
            }
            
            // Generate unique filename
            let fileExtension = sourceURL.pathExtension
            let uniqueFileName = "\(UUID().uuidString).\(fileExtension)"
            let mimeType = getMimeType(for: sourceURL)
            
            print("📄 File details - Extension: \(fileExtension), MIME: \(mimeType), Original: \(originalName)")
            
            // Create file attachment with embedded data
            let attachment = EmbeddedFileAttachment(
                fileName: uniqueFileName,
                originalFileName: originalName,
                fileSize: Int64(fileData.count),
                mimeType: mimeType,
                fileExtension: fileExtension,
                fileData: fileData
            )
            
            print("✅ EmbeddedFileAttachment created successfully")
            print("   - ID: \(attachment.id)")
            print("   - FileName: \(attachment.fileName)")
            print("   - OriginalName: \(attachment.originalFileName)")
            print("   - Size: \(attachment.fileSize) bytes")
            print("   - MIME: \(attachment.mimeType)")
            print("   - Extension: \(attachment.fileExtension)")
            
            return attachment
            
        } catch {
            print("❌ Failed to read file data from \(sourceURL.path)")
            print("❌ Error details: \(error)")
            print("❌ Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("❌ NSError domain: \(nsError.domain), code: \(nsError.code)")
                print("❌ NSError userInfo: \(nsError.userInfo)")
            }
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
