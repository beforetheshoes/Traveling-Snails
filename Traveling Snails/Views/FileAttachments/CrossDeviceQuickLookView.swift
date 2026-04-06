//
//  CrossDeviceQuickLookView.swift
//  Traveling Snails
//
//

import QuickLook
import SwiftUI

@available(iOS 18.0, macOS 14.0, *)
struct CrossDeviceQuickLookView: View {
    let attachment: EmbeddedFileAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var diagnosticInfo: String = "Initializing..."
    @State private var canProceed = false
    @State private var tempFileURL: URL?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if canProceed, let url = tempFileURL {
                    // Show QuickLook
                    CrossDeviceQuickLookContainer(url: url)
                } else {
                    // Show diagnostics
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("File Diagnostics")
                                .font(.headline)

                            Text(diagnosticInfo)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            if let data = attachment.fileData {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Alternative Actions:")
                                        .font(.headline)

                                    ShareLink(item: data, preview: SharePreview(attachment.originalFileName)) {
                                        Label("Share File Data", systemImage: "square.and.arrow.up")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                            .background(.blue.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Preview")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformTopLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if canProceed, let url = tempFileURL {
                    ToolbarItem(placement: .platformTopTrailing) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task {
            await runDiagnostics()
        }
        .onDisappear {
            // Clean up temporary file
            if let url = tempFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func runDiagnostics() async {
        var info = "🔍 Running cross-device file diagnostics...\n\n"

        // Check attachment info
        info += "📁 File: \(attachment.fileName)\n"
        info += "📄 Original: \(attachment.originalFileName)\n"
        info += "💾 Size: \(attachment.formattedFileSize)\n"
        info += "🏷️ Type: \(attachment.fileExtension)\n\n"

        // Check if we have file data
        guard let data = attachment.fileData else {
            info += "❌ No file data stored in database\n"
            info += "💡 This file may need to be re-attached\n"
            diagnosticInfo = info
            return
        }

        info += "✅ File data found in database: \(data.count) bytes\n"

        if data.isEmpty {
            info += "❌ File data is empty\n"
            diagnosticInfo = info
            return
        }

        info += "✅ File data is not empty\n"

        // Create temporary file
        guard let tempURL = attachment.temporaryFileURL else {
            info += "❌ Cannot create temporary file\n"
            diagnosticInfo = info
            return
        }

        info += "✅ Created temporary file: \(tempURL.path)\n"
        tempFileURL = tempURL

        // Check if temporary file exists and is readable
        let exists = FileManager.default.fileExists(atPath: tempURL.path)
        info += exists ? "✅ Temporary file exists\n" : "❌ Temporary file does not exist\n"

        let readable = FileManager.default.isReadableFile(atPath: tempURL.path)
        info += readable ? "✅ Temporary file is readable\n" : "❌ Temporary file is not readable\n"

        // Check QuickLook compatibility
        #if os(iOS)
        let canPreview = QLPreviewController.canPreview(tempURL as QLPreviewItem)
        info += canPreview ? "✅ QuickLook can preview this file\n" : "❌ QuickLook cannot preview this file type\n"
        #else
        let canPreview = true
        info += "QuickLook preview availability not checked on macOS\n"
        #endif

        // Final verdict
        if exists && readable && canPreview {
            info += "\n✅ All checks passed - attempting QuickLook preview\n"
            canProceed = true
        } else {
            info += "\n❌ Cannot proceed with QuickLook preview\n"
            info += "💡 Try using alternative actions below\n"
        }

        diagnosticInfo = info
    }
}

#if os(iOS)
@available(iOS 18.0, *)
struct CrossDeviceQuickLookContainer: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let url: URL

        init(url: URL) {
            self.url = url
            super.init()
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}
#elseif os(macOS)
@available(macOS 14.0, *)
struct CrossDeviceQuickLookContainer: View {
    let url: URL

    var body: some View {
        Text("Preview not available on macOS. Use Quick Look from Finder.")
            .foregroundStyle(.secondary)
            .padding()
    }
}
#endif
