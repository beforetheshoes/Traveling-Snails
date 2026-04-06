//
//  EmbeddedFileAttachmentListView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// File attachment list view with enhanced UI components and error handling
struct EmbeddedFileAttachmentListView: View {
    let attachments: [EmbeddedFileAttachment]
    let onAttachmentAdded: (EmbeddedFileAttachment) -> Void
    let onAttachmentRemoved: (EmbeddedFileAttachment) -> Void
    @State private var store: StoreOf<EmbeddedFileAttachmentListFeature>

    init(
        attachments: [EmbeddedFileAttachment],
        onAttachmentAdded: @escaping (EmbeddedFileAttachment) -> Void,
        onAttachmentRemoved: @escaping (EmbeddedFileAttachment) -> Void,
        store: StoreOf<EmbeddedFileAttachmentListFeature>
    ) {
        self.attachments = attachments
        self.onAttachmentAdded = onAttachmentAdded
        self.onAttachmentRemoved = onAttachmentRemoved
        self._store = State(initialValue: store)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with attachment count and add button
            headerSection

            // Attachments content
            if attachments.isEmpty {
                emptyStateView
            } else {
                attachmentsList
            }

            // Error display
            if let errorMessage = store.errorMessage {
                errorView(errorMessage)
            }
        }
        .handleErrors()
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Spacer()

            AttachmentPickerView.allFiles(
                onSelected: handleAttachmentAdded,
                onError: handleError
            )
            .disabled(store.isProcessing)
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            L(L10n.FileAttachments.noAttachments),
            systemImage: "paperclip",
            description: Text(L(L10n.FileAttachments.noAttachmentsDescription))
        )
        .frame(maxHeight: 100)
    }

    @ViewBuilder
    private var attachmentsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(attachments) { attachment in
                    EnhancedAttachmentRowView(
                        attachment: attachment,
                    onEdit: {
                        // Edit functionality would be handled here
                        Logger.shared.info("Edit attachment: \(attachment.displayName)", category: .fileAttachment)
                    },
                        onDelete: {
                            handleAttachmentRemoved(attachment)
                        }
                    )
                }
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)

            Spacer()

            Button("Dismiss") {
                store.send(.clearError)
            }
            .font(.caption)
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
    }

    // MARK: - Actions

    private func handleAttachmentAdded(_ attachment: EmbeddedFileAttachment) {
        Logger.shared.info("Attachment added: \(attachment.displayName)", category: .fileAttachment)
        onAttachmentAdded(attachment)
    }

    private func handleAttachmentRemoved(_ attachment: EmbeddedFileAttachment) {
        Logger.shared.info("Removing attachment: \(attachment.displayName)", category: .fileAttachment)

        // Remove from callback first
        onAttachmentRemoved(attachment)
        store.send(.removeAttachmentTapped(attachment))
    }

    private func handleError(_ message: String) {
        Logger.shared.error("File attachment error: \(message)", category: .fileAttachment)
        store.send(.showError(message))
    }
}

// MARK: - Enhanced Attachment Row View (Renamed to avoid conflicts)

struct EnhancedAttachmentRowView: View {
    private enum ActiveSheet: Identifiable {
        case quickLook
        case edit

        var id: Int {
            switch self {
            case .quickLook: 0
            case .edit: 1
            }
        }
    }

    let attachment: EmbeddedFileAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var activeSheet: ActiveSheet?
    #if os(iOS)
    @State private var thumbnailImage: UIImage?
    #elseif os(macOS)
    @State private var thumbnailImage: NSImage?
    #endif
    @State private var thumbnailData: Data?

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            fileIcon

            // File information
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.displayName.isEmpty ? L(L10n.General.untitled) : attachment.displayName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // File type badge
                    Text(attachment.fileExtension.uppercased())
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.brown.opacity(0.1))
                        .foregroundStyle(.brown)
                        .clipShape(.rect(cornerRadius: 4))

                    // File size
                    Text(attachment.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Creation date
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(attachment.createdDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.05))
        .clipShape(.rect(cornerRadius: 12))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(L(L10n.General.delete), systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label(L(L10n.General.edit), systemImage: "pencil")
            }
            .tint(.blue)
        }
        .confirmationDialog(
            "Delete Attachment",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete the attachment. This action cannot be undone.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quickLook:
                CrossDeviceQuickLookView(attachment: attachment)
            case .edit:
                CrossDeviceEditFileAttachmentView(
                    attachment: attachment,
                    store: StoreOf<CrossDeviceEditFileAttachmentFeature>.init(initialState: CrossDeviceEditFileAttachmentFeature.State(attachment: attachment)) {
                        CrossDeviceEditFileAttachmentFeature()
                    }
                )
            }
        }
        .onAppear {
            thumbnailData = attachment.isImage ? attachment.fileData : nil
        }
        .task(id: thumbnailData) {
            thumbnailImage = await decodeThumbnail(from: thumbnailData)
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        Group {
            if attachment.isImage, let image = thumbnailImage {
                platformImage(image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(attachment.fileIconColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: attachment.fileSystemIcon)
                        .font(.title2)
                        .foregroundStyle(attachment.fileIconColor)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 16) {  // Increased spacing for better mobile UX
            // Preview button - works for all file types
            Button {
                activeSheet = .quickLook
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(minWidth: 44, minHeight: 44)  // Apple recommended minimum tap target size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview attachment")

            // Edit button - placeholder for now
            Button {
                activeSheet = .edit
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(minWidth: 44, minHeight: 44)  // Apple recommended minimum tap target size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit attachment")

            // Delete button
            Button {
                showingDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 44)  // Apple recommended minimum tap target size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete attachment")
        }
    }

    #if os(iOS)
    private func platformImage(_ image: UIImage) -> Image {
        Image(uiImage: image)
    }

    private func decodeThumbnail(from data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task(priority: .userInitiated) {
            UIImage(data: data)
        }.value
    }
    #elseif os(macOS)
    private func platformImage(_ image: NSImage) -> Image {
        Image(nsImage: image)
    }

    private func decodeThumbnail(from data: Data?) async -> NSImage? {
        guard let data else { return nil }
        return await Task(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
    #endif
}

// MARK: - EmbeddedFileAttachment Extensions

extension EmbeddedFileAttachment {
    var fileIconColor: Color {
        switch fileExtension.lowercased() {
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "gif", "heic":
            return .blue
        case "doc", "docx":
            return .blue
        case "xls", "xlsx":
            return .green
        case "ppt", "pptx":
            return .orange
        case "txt":
            return .gray
        default:
            return .brown
        }
    }

    var fileSystemIcon: String {
        switch fileExtension.lowercased() {
        case "pdf":
            return "doc.richtext"
        case "jpg", "jpeg", "png", "gif", "heic":
            return "photo"
        case "doc", "docx":
            return "doc.text"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "rectangle.3.offgrid.bubble.left"
        case "txt":
            return "doc.plaintext"
        case "zip", "rar":
            return "archivebox"
        default:
            return "doc"
        }
    }
}


// MARK: - Preview

#Preview {
    EmbeddedFileAttachmentListView(
        attachments: [],
        onAttachmentAdded: { _ in },
        onAttachmentRemoved: { _ in },
        store: StoreOf<EmbeddedFileAttachmentListFeature>.init(initialState: EmbeddedFileAttachmentListFeature.State()) {
            EmbeddedFileAttachmentListFeature()
        }
    )
    .padding()
}
