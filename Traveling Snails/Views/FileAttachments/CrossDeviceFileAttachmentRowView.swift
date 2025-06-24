//
//  CrossDeviceFileAttachmentRowView.swift
//  Traveling Snails
//
//

import SwiftUI

@available(iOS 18.0, *)
struct CrossDeviceFileAttachmentRowView: View {
    let attachment: EmbeddedFileAttachment
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    @State private var showingQuickLook = false
    @State private var showingEditSheet = false
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
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
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Text(attachment.formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(attachment.createdDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Actions menu
            Menu {
                Button {
                    showingQuickLook = true
                } label: {
                    Label("View", systemImage: "eye")
                }
                
                Button {
                    showingEditSheet = true
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
        .onTapGesture {
            showingQuickLook = true
        }
        .sheet(isPresented: $showingQuickLook) {
            CrossDeviceQuickLookView(attachment: attachment)
        }
        .sheet(isPresented: $showingEditSheet) {
            CrossDeviceEditFileAttachmentView(attachment: attachment)
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
                Image(systemName: attachment.systemIcon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private func loadThumbnail() {
        guard attachment.isImage, let data = attachment.fileData else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    thumbnailImage = image
                }
            }
        }
    }
}
