//
//  FileAttachmentSettingsView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct FileAttachmentSettingsView: View {
    @Bindable var store: StoreOf<FileAttachmentSettingsFeature>
    @FetchAll private var attachmentRecords: [EmbeddedFileAttachment]

    private var totalSize: Int64 {
        attachmentRecords.reduce(0) { $0 + $1.fileSize }
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
                        store.send(.findOrphanedTapped(attachmentRecords))
                    } label: {
                        HStack {
                            if store.isScanning {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Scanning...")
                            } else {
                                Label("Find Orphaned Files", systemImage: "magnifyingglass")
                            }
                        }
                    }
                    .disabled(store.isScanning || store.isCleaning || store.isClearing)

                    if !store.orphanedAttachmentIDs.isEmpty {
                        Button {
                            store.send(.cleanupOrphanedTapped)
                        } label: {
                            HStack {
                                if store.isCleaning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Cleaning...")
                                } else {
                                    Label("Clean Up \(store.orphanedAttachmentIDs.count) Orphaned Files", systemImage: "trash")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .disabled(store.isScanning || store.isCleaning || store.isClearing)
                    }

                    Button(role: .destructive) {
                        store.send(.clearAllTapped)
                    } label: {
                        HStack {
                            if store.isClearing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Clearing...")
                            } else {
                                Label("Clear All Attachments", systemImage: "trash.fill")
                            }
                        }
                    }
                    .disabled(store.isScanning || store.isCleaning || store.isClearing)
                }

                Section("Storage") {
                    LabeledContent("Total Files", value: "\(attachmentRecords.count)")
                    LabeledContent("Total Size", value: ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                }

                Section("File Types") {
                    let imageCount = attachmentRecords.filter { $0.isImage }.count
                    let documentCount = attachmentRecords.filter { $0.isDocument }.count
                    let pdfCount = attachmentRecords.filter { $0.isPDF }.count
                    let otherCount = attachmentRecords.count - imageCount - documentCount - pdfCount

                    LabeledContent("Images", value: "\(imageCount)")
                    LabeledContent("Documents", value: "\(documentCount)")
                    LabeledContent("PDFs", value: "\(pdfCount)")
                    LabeledContent("Other", value: "\(otherCount)")
                }
            }
            .navigationTitle("Attachment Settings")
            .confirmationDialog(
                "Clear All Attachments",
                isPresented: Binding(
                    get: { store.showingClearConfirmation },
                    set: { store.send(.clearDialogChanged($0)) }
                ),
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    store.send(
                        .clearAllConfirmed(
                            ids: attachmentRecords.map(\.id),
                            totalCount: attachmentRecords.count
                        )
                    )
                }
            } message: {
                Text("This will permanently delete all attachments from your device. This action cannot be undone.")
            }
            .confirmationDialog(
                "Clean Up Orphaned Files",
                isPresented: Binding(
                    get: { store.showingCleanupConfirmation },
                    set: { store.send(.cleanupDialogChanged($0)) }
                ),
                titleVisibility: .visible
            ) {
                Button("Clean Up", role: .destructive) {
                    store.send(.cleanupOrphanedConfirmed)
                }
            } message: {
                Text("This will delete \(store.orphanedAttachmentIDs.count) orphaned attachments that are no longer associated with any activities.")
            }
            .alert(store.alertTitle, isPresented: Binding(
                get: { store.showingAlert },
                set: { _ in store.send(.dismissAlert) }
            )) {
                Button("OK") {
                    store.send(.dismissAlert)
                }
            } message: {
                Text(store.alertMessage)
            }
        }
    }
}
