//
//  FileAttachmentSettingsView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/1/25.
//

import SwiftUI
import SwiftData

struct FileAttachmentSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttachments: [EmbeddedFileAttachment]
    
    @State private var showingClearConfirmation = false
    @State private var showingCleanupConfirmation = false
    @State private var orphanedAttachments: [EmbeddedFileAttachment] = []
    
    private var totalSize: Int64 {
        allAttachments.reduce(0) { $0 + $1.fileSize }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    FileAttachmentSummaryView()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                
                Section("Management") {
                    Button {
                        findOrphanedAttachments()
                    } label: {
                        Label("Find Orphaned Files", systemImage: "magnifyingglass")
                    }
                    
                    if !orphanedAttachments.isEmpty {
                        Button {
                            showingCleanupConfirmation = true
                        } label: {
                            Label("Clean Up \(orphanedAttachments.count) Orphaned Files", systemImage: "trash")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear All Attachments", systemImage: "trash.fill")
                    }
                }
                
                Section("Storage") {
                    LabeledContent("Total Files", value: "\(allAttachments.count)")
                    LabeledContent("Total Size", value: ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                }
                
                Section("File Types") {
                    let imageCount = allAttachments.filter { $0.isImage }.count
                    let documentCount = allAttachments.filter { $0.isDocument }.count
                    let pdfCount = allAttachments.filter { $0.isPDF }.count
                    let otherCount = allAttachments.count - imageCount - documentCount - pdfCount
                    
                    LabeledContent("Images", value: "\(imageCount)")
                    LabeledContent("Documents", value: "\(documentCount)")
                    LabeledContent("PDFs", value: "\(pdfCount)")
                    LabeledContent("Other", value: "\(otherCount)")
                }
            }
            .navigationTitle("Attachment Settings")
            .confirmationDialog(
                "Clear All Attachments",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    clearAllAttachments()
                }
            } message: {
                Text("This will permanently delete all attachments from your device. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clean Up Orphaned Files",
                isPresented: $showingCleanupConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clean Up", role: .destructive) {
                    cleanupOrphanedAttachments()
                }
            } message: {
                Text("This will delete \(orphanedAttachments.count) orphaned attachments that are no longer associated with any activities.")
            }
        }
    }
    
    private func findOrphanedAttachments() {
        orphanedAttachments = allAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }
    }
    
    private func cleanupOrphanedAttachments() {
        for attachment in orphanedAttachments {
            modelContext.delete(attachment)
        }
        
        do {
            try modelContext.save()
            orphanedAttachments = []
        } catch {
            print("Failed to cleanup orphaned attachments: \(error)")
        }
    }
    
    private func clearAllAttachments() {
        for attachment in allAttachments {
            modelContext.delete(attachment)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to clear all attachments: \(error)")
        }
    }
}
