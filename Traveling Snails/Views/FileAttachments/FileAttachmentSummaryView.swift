//
//  FileAttachmentSummaryView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

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
                .padding(.horizontal, 4)

            // First row: Images, Documents, Other (more space for each)
            HStack(spacing: 12) {
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
            .frame(maxWidth: .infinity)

            // Second row: Total Files and Storage Used
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Files",
                    value: "\(allAttachments.count)",
                    icon: "doc.on.doc",
                    color: .blue
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()

                        Image(systemName: "externaldrive")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text("Storage Used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}
