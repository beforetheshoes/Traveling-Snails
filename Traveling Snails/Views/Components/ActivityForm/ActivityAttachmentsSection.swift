//
//  ActivityAttachmentsSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and managing activity file attachments
struct ActivityAttachmentsSection: View {
    @Binding var attachments: [EmbeddedFileAttachment]
    let isEditing: Bool
    let color: Color
    let onAttachmentAdded: (EmbeddedFileAttachment) -> Void
    let onAttachmentRemoved: (EmbeddedFileAttachment) -> Void

    init(
        attachments: Binding<[EmbeddedFileAttachment]>,
        isEditing: Bool,
        color: Color,
        onAttachmentAdded: @escaping (EmbeddedFileAttachment) -> Void = { _ in },
        onAttachmentRemoved: @escaping (EmbeddedFileAttachment) -> Void = { _ in }
    ) {
        self._attachments = attachments
        self.isEditing = isEditing
        self.color = color
        self.onAttachmentAdded = onAttachmentAdded
        self.onAttachmentRemoved = onAttachmentRemoved
    }

    var body: some View {
        ActivitySectionCard(
            headerIcon: "paperclip",
            headerTitle: attachmentTitle,
            headerColor: color
        ) {
            VStack(spacing: 12) {
                if isEditing {
                    editModeContent
                } else {
                    viewModeContent
                }
            }
        }
    }

    // MARK: - Edit Mode Content

    private var editModeContent: some View {
        VStack(spacing: 12) {
            if attachments.isEmpty {
                emptyAttachmentsMessage
            } else {
                attachmentsList
            }

            // Add attachment button
            addAttachmentButton
        }
    }

    private var emptyAttachmentsMessage: some View {
        Text("No attachments")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.vertical, 16)
    }

    private var attachmentsList: some View {
        ForEach(attachments) { attachment in
            attachmentRow(attachment)
        }
    }

    private func attachmentRow(_ attachment: EmbeddedFileAttachment) -> some View {
        HStack {
            Image(systemName: attachment.fileSystemIcon)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.displayName)
                    .font(.body)
                    .lineLimit(1)

                Text(attachment.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                removeAttachment(attachment)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .frame(minWidth: 24, minHeight: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private var addAttachmentButton: some View {
        UnifiedFilePicker.allFiles(
            onSelected: { attachment in
                addAttachment(attachment)
            },
            onError: { error in
                Logger.shared.error("Attachment error in edit mode: \(error)", category: .fileAttachment)
            }
        )
        .buttonStyle(.bordered)
        .tint(color)
    }

    // MARK: - View Mode Content

    private var viewModeContent: some View {
        EmbeddedFileAttachmentListView(
            attachments: attachments,
            onAttachmentAdded: { attachment in
                addAttachment(attachment)
            },
            onAttachmentRemoved: { attachment in
                removeAttachment(attachment)
            }
        )
    }

    // MARK: - Actions

    private func addAttachment(_ attachment: EmbeddedFileAttachment) {
        attachments.append(attachment)
        onAttachmentAdded(attachment)
    }

    private func removeAttachment(_ attachment: EmbeddedFileAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        onAttachmentRemoved(attachment)
    }

    // MARK: - Computed Properties

    private var attachmentTitle: String {
        if attachments.isEmpty {
            return "Attachments"
        }
        return "Attachments (\(attachments.count))"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode with attachments
        ActivityAttachmentsSection(
            attachments: .constant([
                EmbeddedFileAttachment(fileName: "boarding-pass.pdf", fileSize: 1024),
                EmbeddedFileAttachment(fileName: "hotel-confirmation.jpg", fileSize: 2048),
            ]),
            isEditing: true,
            color: .orange
        )

        // View mode empty
        ActivityAttachmentsSection(
            attachments: .constant([]),
            isEditing: false,
            color: .blue
        )
    }
    .padding()
}
