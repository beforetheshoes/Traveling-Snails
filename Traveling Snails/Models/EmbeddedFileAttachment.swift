//
//  EmbeddedFileAttachment.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct EmbeddedFileAttachment: Hashable, Identifiable {
    let id: UUID
    var fileName: String
    var originalFileName: String
    var fileSize: Int64
    var mimeType: String
    var fileExtension: String
    var createdDate: Date
    var fileDescription: String
    var fileData: Data?

    var activityID: Activity.ID?
    var lodgingID: Lodging.ID?
    var transportationID: Transportation.ID?

    init(
        id: UUID = UUID(),
        fileName: String = "",
        originalFileName: String = "",
        fileSize: Int64 = 0,
        mimeType: String = "",
        fileExtension: String = "",
        fileDescription: String = "",
        fileData: Data? = nil,
        createdDate: Date = Date(),
        activityID: Activity.ID? = nil,
        lodgingID: Lodging.ID? = nil,
        transportationID: Transportation.ID? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.originalFileName = originalFileName
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.fileExtension = fileExtension
        self.fileDescription = fileDescription
        self.fileData = fileData
        self.createdDate = createdDate
        self.activityID = activityID
        self.lodgingID = lodgingID
        self.transportationID = transportationID
    }

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
