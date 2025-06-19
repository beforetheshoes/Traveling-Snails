//
//  EmbeddedFileAttachmentExportView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/1/25.
//

import SwiftUI

struct EmbeddedFileAttachmentExportView: View {
    let attachments: [EmbeddedFileAttachment]
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        VStack(spacing: 16) {
            if attachments.isEmpty {
                ContentUnavailableView(
                    "No Attachments",
                    systemImage: "paperclip",
                    description: Text("There are no attachments to export")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Options")
                        .font(.headline)
                    
                    Button {
                        exportAllAttachments()
                    } label: {
                        Label("Share All Attachments", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Text("Individual Files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            Button {
                                exportAttachment(attachment)
                            } label: {
                                HStack {
                                    Image(systemName: attachment.systemIcon)
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.displayName)
                                            .font(.subheadline)
                                        Text(attachment.formattedFileSize)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
    
    private func exportAllAttachments() {
        var items: [Any] = []
        
        for attachment in attachments {
            if let data = attachment.fileData {
                items.append(data)
            }
        }
        
        if !items.isEmpty {
            shareItems = items
            showingShareSheet = true
        }
    }
    
    private func exportAttachment(_ attachment: EmbeddedFileAttachment) {
        guard let data = attachment.fileData else { return }
        shareItems = [data]
        showingShareSheet = true
    }
}

// Keep the existing ShareSheet since it still works
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
