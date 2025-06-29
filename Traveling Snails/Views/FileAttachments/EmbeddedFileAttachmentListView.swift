//
//  EmbeddedFileAttachmentListView.swift
//  Traveling Snails
//
//

import SwiftUI

/// Unified file attachment list view with enhanced UI components and error handling
struct EmbeddedFileAttachmentListView: View {
    @Environment(\.modelContext) private var modelContext

    let attachments: [EmbeddedFileAttachment]
    let onAttachmentAdded: (EmbeddedFileAttachment) -> Void
    let onAttachmentRemoved: (EmbeddedFileAttachment) -> Void

    @State private var errorMessage: String?
    @State private var isProcessing = false

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
            if let errorMessage = errorMessage {
                errorView(errorMessage)
            }
        }
        .handleErrors()
    }

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Spacer()

            UnifiedFilePicker.allFiles(
                onSelected: handleAttachmentAdded,
                onError: handleError
            )
            .disabled(isProcessing)
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
                .foregroundColor(.orange)

            Text(message)
                .font(.caption)
                .foregroundColor(.orange)

            Spacer()

            Button("Dismiss") {
                errorMessage = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func handleAttachmentAdded(_ attachment: EmbeddedFileAttachment) {
        Logger.shared.info("Attachment added: \(attachment.displayName)", category: .fileAttachment)
        onAttachmentAdded(attachment)

        // Post success notification
        NotificationCenter.default.post(
            name: .fileAttachmentAdded,
            object: attachment
        )
    }

    private func handleAttachmentRemoved(_ attachment: EmbeddedFileAttachment) {
        Logger.shared.info("Removing attachment: \(attachment.displayName)", category: .fileAttachment)

        isProcessing = true

        // Remove from callback first
        onAttachmentRemoved(attachment)

        // Delete from database
        modelContext.delete(attachment)

        // Save context
        modelContext.safeSave(context: "Removing file attachment").handleResult(
            context: "File attachment removal",
            onSuccess: {
                isProcessing = false
                NotificationCenter.default.post(
                    name: .fileAttachmentRemoved,
                    object: attachment
                )
            },
            onFailure: { error in
                isProcessing = false
                handleError("Failed to remove attachment: \(error.localizedDescription)")
            }
        )
    }

    private func handleError(_ message: String) {
        Logger.shared.error("File attachment error: \(message)", category: .fileAttachment)
        errorMessage = message

        // Auto-dismiss error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [errorMessage] in
            if self.errorMessage == errorMessage {
                self.errorMessage = nil
            }
        }
    }
}

// MARK: - Enhanced Attachment Row View (Renamed to avoid conflicts)

struct EnhancedAttachmentRowView: View {
    let attachment: EmbeddedFileAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var showingEditView = false
    @State private var showingQuickLook = false
    @State private var thumbnailImage: UIImage?

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
                        .foregroundColor(.brown)
                        .cornerRadius(4)

                    // File size
                    Text(attachment.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Creation date
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(attachment.createdDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
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
        .sheet(isPresented: $showingQuickLook) {
            CrossDeviceQuickLookView(attachment: attachment)
        }
        .sheet(isPresented: $showingEditView) {
            CrossDeviceEditFileAttachmentView(attachment: attachment)
        }
        .onAppear {
            loadThumbnail()
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        Group {
            if attachment.isImage, let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(attachment.fileIconColor.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: attachment.fileSystemIcon)
                        .font(.title2)
                        .foregroundColor(attachment.fileIconColor)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 16) {  // Increased spacing for better mobile UX
            // Preview button - works for all file types
            Button {
                showingQuickLook = true
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(minWidth: 44, minHeight: 44)  // Apple recommended minimum tap target size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview attachment")

            // Edit button - placeholder for now
            Button {
                showingEditView = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
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
                    .foregroundColor(.red)
                    .frame(minWidth: 44, minHeight: 44)  // Apple recommended minimum tap target size
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete attachment")
        }
    }

    private func loadThumbnail() {
        guard attachment.isImage, let data = attachment.fileData else { return }

        Task {
            // Load thumbnail on background thread using async/await
            let image = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = UIImage(data: data)
                    continuation.resume(returning: result)
                }
            }

            // Update UI on main thread
            await MainActor.run {
                thumbnailImage = image
            }
        }
    }
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

// MARK: - Notification Names

extension Notification.Name {
    static let fileAttachmentAdded = Notification.Name("FileAttachmentAdded")
    static let fileAttachmentRemoved = Notification.Name("FileAttachmentRemoved")
    static let fileAttachmentUpdated = Notification.Name("FileAttachmentUpdated")
}

// MARK: - Preview

#Preview {
    EmbeddedFileAttachmentListView(
        attachments: [],
        onAttachmentAdded: { _ in },
        onAttachmentRemoved: { _ in }
    )
    .padding()
}
