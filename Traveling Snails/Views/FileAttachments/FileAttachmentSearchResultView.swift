//
//  FileAttachmentSearchResultView.swift
//  Traveling Snails
//
//

import SwiftUI

struct FileAttachmentSearchResultView: View {
    let attachment: EmbeddedFileAttachment
    @State private var showingQuickLook = false
    @State private var thumbnailImage: UIImage?
    
    private var associatedActivity: String {
        if let activity = attachment.activity {
            return "Activity: \(activity.name)"
        } else if let lodging = attachment.lodging {
            return "Lodging: \(lodging.name)"
        } else if let transportation = attachment.transportation {
            return "Transportation: \(transportation.name)"
        }
        return "Unknown"
    }
    
    var body: some View {
        Button {
            showingQuickLook = true
        } label: {
            HStack(spacing: 12) {
                // File thumbnail/icon
                Group {
                    if attachment.isImage, let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: attachment.systemIcon)
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(associatedActivity)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text(attachment.fileExtension.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(attachment.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(attachment.createdDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
        .sheet(isPresented: $showingQuickLook) {
            CrossDeviceQuickLookView(attachment: attachment)
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
