//
//  FileAttachmentSettingsView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct FileAttachmentSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttachments: [EmbeddedFileAttachment]

    @State private var showingClearConfirmation = false
    @State private var showingCleanupConfirmation = false
    @State private var orphanedAttachments: [EmbeddedFileAttachment] = []
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var isClearing = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    private var totalSize: Int64 {
        allAttachments.reduce(0) { $0 + $1.fileSize }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FileAttachmentSummaryView()
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("Management") {
                    Button {
                        Task {
                            await findOrphanedAttachments()
                        }
                    } label: {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning...")
                            } else {
                                Label("Find Orphaned Files", systemImage: "magnifyingglass")
                            }
                        }
                    }
                    .disabled(isScanning || isCleaning || isClearing)

                    if !orphanedAttachments.isEmpty {
                        Button {
                            showingCleanupConfirmation = true
                        } label: {
                            HStack {
                                if isCleaning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Cleaning...")
                                } else {
                                    Label("Clean Up \(orphanedAttachments.count) Orphaned Files", systemImage: "trash")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .disabled(isScanning || isCleaning || isClearing)
                    }

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            if isClearing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Clearing...")
                            } else {
                                Label("Clear All Attachments", systemImage: "trash.fill")
                            }
                        }
                    }
                    .disabled(isScanning || isCleaning || isClearing)
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
                    Task {
                        await clearAllAttachments()
                    }
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
                    Task {
                        await cleanupOrphanedAttachments()
                    }
                }
            } message: {
                Text("This will delete \(orphanedAttachments.count) orphaned attachments that are no longer associated with any activities.")
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") { }
            } message: {
                Text(successMessage)
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    @MainActor
    private func findOrphanedAttachments() async {
        isScanning = true

        // Add a small delay to show the progress indicator
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds

        orphanedAttachments = allAttachments.filter { attachment in
            attachment.activity == nil &&
            attachment.lodging == nil &&
            attachment.transportation == nil
        }

        isScanning = false

        // Show completion message
        if orphanedAttachments.isEmpty {
            successMessage = "Scan complete. No orphaned files found."
        } else {
            successMessage = "Scan complete. Found \(orphanedAttachments.count) orphaned file\(orphanedAttachments.count == 1 ? "" : "s")."
        }
        showingSuccessAlert = true

        Logger.shared.info("Orphaned attachments scan completed: \(orphanedAttachments.count) found", category: .fileManagement)
    }

    @MainActor
    private func cleanupOrphanedAttachments() async {
        isCleaning = true
        let orphanedCount = orphanedAttachments.count

        // Add a small delay to show progress
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            for attachment in orphanedAttachments {
                modelContext.delete(attachment)
            }

            try modelContext.save()
            orphanedAttachments = []

            successMessage = "Successfully cleaned up \(orphanedCount) orphaned file\(orphanedCount == 1 ? "" : "s")."
            showingSuccessAlert = true

            Logger.shared.info("Orphaned attachments cleanup completed: \(orphanedCount) files removed", category: .fileManagement)
        } catch {
            errorMessage = "Failed to cleanup orphaned attachments: \(error.localizedDescription)"
            showingErrorAlert = true
            Logger.shared.error("Failed to cleanup orphaned attachments: \(error)", category: .fileManagement)
        }

        isCleaning = false
    }

    @MainActor
    private func clearAllAttachments() async {
        isClearing = true
        let totalCount = allAttachments.count

        // Add a small delay to show progress
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        do {
            for attachment in allAttachments {
                modelContext.delete(attachment)
            }

            try modelContext.save()

            successMessage = "Successfully cleared all \(totalCount) attachment\(totalCount == 1 ? "" : "s")."
            showingSuccessAlert = true

            Logger.shared.info("All attachments cleared: \(totalCount) files removed", category: .fileManagement)
        } catch {
            errorMessage = "Failed to clear all attachments: \(error.localizedDescription)"
            showingErrorAlert = true
            Logger.shared.error("Failed to clear all attachments: \(error)", category: .fileManagement)
        }

        isClearing = false
    }
}
