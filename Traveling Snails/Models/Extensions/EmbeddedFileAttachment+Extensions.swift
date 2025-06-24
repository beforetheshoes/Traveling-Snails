//
//  EmbeddedFileAttachment+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension EmbeddedFileAttachment: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []
        
        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "Display Name", optionalValue: displayName, defaultValue: "Unnamed"),
                DetailRowData(label: "Original Filename", value: originalFileName),
                DetailRowData(label: "Internal Filename", value: fileName),
                DetailRowData(label: "ID", value: id.uuidString)
            ]
        ))
        
        // File Properties
        sections.append(DetailSection(
            title: "File Properties",
            rows: [
                DetailRowData(label: "File Extension", optionalValue: fileExtension.isEmpty ? nil : fileExtension.uppercased(), defaultValue: "Unknown"),
                DetailRowData(label: "MIME Type", optionalValue: mimeType, defaultValue: "Unknown"),
                DetailRowData(label: "File Size", value: formattedFileSize),
                DetailRowData(label: "Created Date", value: createdDate.formatted(date: .abbreviated, time: .shortened)),
                DetailRowData(label: "Is Image", boolValue: isImage),
                DetailRowData(label: "Is PDF", boolValue: isPDF),
                DetailRowData(label: "Is Document", boolValue: isDocument)
            ]
        ))
        
        // Storage
        var storageRows = [DetailRowData(label: "Has File Data", boolValue: fileData != nil)]
        if let data = fileData {
            storageRows.append(DetailRowData(label: "Data Size", value: "\(data.count) bytes"))
            storageRows.append(DetailRowData(label: "Data Empty", boolValue: data.isEmpty))
        }
        sections.append(DetailSection(title: "Storage", rows: storageRows))
        
        // Relationships
        var relationshipValue = "Orphaned (no relationship)"
        if let activity = activity {
            relationshipValue = "Activity: \(activity.name)"
        } else if let lodging = lodging {
            relationshipValue = "Lodging: \(lodging.name)"
        } else if let transportation = transportation {
            relationshipValue = "Transportation: \(transportation.name)"
        }
        
        sections.append(DetailSection(
            title: "Relationships",
            rows: [DetailRowData(label: "Attached To", value: relationshipValue)]
        ))
        
        // Description (conditional)
        if !fileDescription.isEmpty {
            sections.append(DetailSection(title: "Description", rows: [], textContent: fileDescription))
        }
        
        return sections
    }
}
