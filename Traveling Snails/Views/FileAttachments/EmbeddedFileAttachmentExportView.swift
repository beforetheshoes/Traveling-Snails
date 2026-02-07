//
//  EmbeddedFileAttachmentExportView.swift
//  Traveling Snails
//
//

import SwiftUI

struct EmbeddedFileAttachmentExportView: View {
    private struct ShareSheetPayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    let attachments: [EmbeddedFileAttachment]
    @State private var activeSheet: ShareSheetPayload?

    var body: some View {
        VStack(spacing: 16) {
            if attachments.isEmpty {
                ContentUnavailableView(
                    "No Attachments",
                    systemImage: "paperclip",
                    description: Text("There are no attachments to export")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Options")
                        .font(.headline)

                    Button {
                        exportAllAttachments()
                    } label: {
                        Label("Share All Attachments", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Text("Individual Files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top)

                    LazyVStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            Button {
                                exportAttachment(attachment)
                            } label: {
                                HStack {
                                    Image(systemName: attachment.systemIcon)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.displayName)
                                            .font(.subheadline)
                                        Text(attachment.formattedFileSize)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "square.and.arrow.up")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray6))
                                .clipShape(.rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(item: $activeSheet) { payload in
            ShareSheet(items: payload.items)
        }
    }

    private func exportAllAttachments() {
        var items: [Any] = []

        for attachment in attachments {
            if let data = attachment.fileData {
                items.append(data)
            }
        }

        if !items.isEmpty {
            activeSheet = ShareSheetPayload(items: items)
        }
    }

    private func exportAttachment(_ attachment: EmbeddedFileAttachment) {
        guard let data = attachment.fileData else { return }
        activeSheet = ShareSheetPayload(items: [data])
    }
}

// Keep the existing ShareSheet since it still works
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
