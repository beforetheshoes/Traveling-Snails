//
//  EmbeddedFileAttachment.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

@Model
class EmbeddedFileAttachment: Identifiable {
    var id = UUID()
    var fileName: String = ""
    var originalFileName: String = ""
    var fileSize: Int64 = 0
    var mimeType: String = ""
    var fileExtension: String = ""
    var createdDate = Date()
    var fileDescription: String = ""

    // Store the actual file data in the database for cross-device sync
    @Attribute(.externalStorage) var fileData: Data?

    // Relationships
    var activity: Activity?
    var lodging: Lodging?
    var transportation: Transportation?

    init(
        fileName: String = "",
        originalFileName: String = "",
        fileSize: Int64 = 0,
        mimeType: String = "",
        fileExtension: String = "",
        fileDescription: String = "",
        fileData: Data? = nil
    ) {
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.fileDescription = fileDescription
        self.createdDate = Date()
        self.fileData = fileData
    }

    // MARK: - Computed Properties

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png", "gif", "heic", "webp"].contains(fileExtension.lowercased())
    }

    var isPDF: Bool {
        fileExtension.lowercased() == "pdf"
    }

    var isDocument: Bool {
        ["doc", "docx", "txt", "rtf", "pages"].contains(fileExtension.lowercased())
    }

    var systemIcon: String {
        if isImage {
            return "photo"
        } else if isPDF {
            return "doc.richtext"
        } else if isDocument {
            return "doc.text"
        } else {
            return "doc"
        }
    }

    var displayName: String {
        fileDescription.isEmpty ? originalFileName : fileDescription
    }

    // Create a temporary file URL for QuickLook
    var temporaryFileURL: URL? {
        guard let data = fileData else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(id.uuidString).\(fileExtension)")

        do {
            try data.write(to: tempFile)
            return tempFile
        } catch {
            Logger.shared.error("Failed to create temporary file: \(error)")
            return nil
        }
    }
}
