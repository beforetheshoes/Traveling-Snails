//
//  CrossDeviceFileAttachmentRowView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@available(iOS 18.0, macOS 14.0, *)
struct CrossDeviceFileAttachmentRowView: View {
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
            Button {
                activeSheet = .quickLook
            } label: {
                HStack(spacing: 12) {
                    // File icon with thumbnail for images
                    fileIcon

                    // File info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.displayName)
                            .font(.headline)
                            .lineLimit(2)

                        HStack {
                            Text(attachment.fileExtension.uppercased())
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2))
                                .clipShape(.rect(cornerRadius: 4))

                            Text(attachment.formattedFileSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(attachment.createdDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Actions menu
            Menu {
                Button {
                    activeSheet = .quickLook
                } label: {
                    Label("View", systemImage: "eye")
                }

                Button {
                    activeSheet = .edit
                } label: {
                    Label("Edit Info", systemImage: "pencil")
                }

                if let data = attachment.fileData {
                    ShareLink(item: data, preview: SharePreview(attachment.originalFileName)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
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
        .confirmationDialog(
            "Delete \(attachment.displayName)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This action cannot be undone.")
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
                Image(systemName: attachment.systemIcon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
            }
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
