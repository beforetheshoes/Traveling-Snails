//
//  FileAttachmentSearchResultView.swift
//  Traveling Snails
//
//

import SwiftUI

struct FileAttachmentSearchResultView: View {
    private enum ActiveSheet: Identifiable {
        case quickLook
        var id: Int { 0 }
    }

    let attachment: EmbeddedFileAttachment
    @State private var activeSheet: ActiveSheet?
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
            activeSheet = .quickLook
        } label: {
            HStack(spacing: 12) {
                // File thumbnail/icon
                Group {
                    if attachment.isImage, let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(.rect(cornerRadius: 8))
                    } else {
                        Image(systemName: attachment.systemIcon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }

                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(associatedActivity)
                        .font(.subheadline)
                        .foregroundStyle(.blue)

                    HStack {
                        Text(attachment.fileExtension.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
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

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            loadThumbnail()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quickLook:
                CrossDeviceQuickLookView(attachment: attachment)
            }
        }
    }

    private func loadThumbnail() {
        guard attachment.isImage, let data = attachment.fileData else { return }

        Task.detached(priority: .userInitiated) {
            if let image = UIImage(data: data) {
                await MainActor.run {
                    thumbnailImage = image
                }
            }
        }
    }
}
