//
//  FileAttachmentSummaryView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/1/25.
//

import SwiftUI
import SwiftData

struct FileAttachmentSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttachments: [EmbeddedFileAttachment]
    
    private var totalSize: Int64 {
        allAttachments.reduce(0) { $0 + $1.fileSize }
    }
    
    private var imageCount: Int {
        allAttachments.filter { $0.isImage }.count
    }
    
    private var documentCount: Int {
        allAttachments.filter { $0.isDocument || $0.isPDF }.count
    }
    
    private var otherCount: Int {
        allAttachments.count - imageCount - documentCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attachment Summary")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Files",
                    value: "\(allAttachments.count)",
                    icon: "doc.on.doc",
                    color: .blue
                )
                
                StatCard(
                    title: "Images",
                    value: "\(imageCount)",
                    icon: "photo",
                    color: .green
                )
                
                StatCard(
                    title: "Documents",
                    value: "\(documentCount)",
                    icon: "doc.text",
                    color: .orange
                )
                
                StatCard(
                    title: "Other",
                    value: "\(otherCount)",
                    icon: "doc",
                    color: .purple
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage Used")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
