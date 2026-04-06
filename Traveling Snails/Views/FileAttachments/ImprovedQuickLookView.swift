//
//  ImprovedQuickLookView.swift
//  Traveling Snails
//
//

import QuickLook
import SwiftUI

@available(iOS 18.0, macOS 14.0, *)
struct ImprovedQuickLookView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let error = loadError {
                    ContentUnavailableView(
                        "Cannot Preview File",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if isLoading {
                    ProgressView("Loading preview...")
                } else {
                    ModernQuickLookContainer(url: url) { error in
                        loadError = error
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

                ToolbarItem(placement: .platformTopTrailing) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .task {
            await validateFile()
        }
    }

    private func validateFile() async {
        do {
            // Use modern async file operations
            let resourceValues = try url.resourceValues(forKeys: [
                .isReadableKey,
                .fileSizeKey,
                .contentTypeKey,
            ])

            guard resourceValues.isReadable == true else {
                loadError = "File is not readable"
                return
            }

            guard let fileSize = resourceValues.fileSize, fileSize > 0 else {
                loadError = "File appears to be empty"
                return
            }

            // Check if QuickLook can handle this file type using the URL
            #if os(iOS)
            let canPreview = QLPreviewController.canPreview(url as QLPreviewItem)
            if !canPreview {
                loadError = "This file type cannot be previewed"
                return
            }
            #endif

            isLoading = false
        } catch {
            Logger.shared.error("Error accessing file: \(error.localizedDescription)", category: .fileAttachment)
            loadError = L(L10n.File.accessFailed)
        }
    }
}

#if os(iOS)
@available(iOS 18.0, *)
@MainActor
struct ModernQuickLookContainer: UIViewControllerRepresentable {
    let url: URL
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator

        // Modern iOS 18 configurations
        controller.modalPresentationStyle = .fullScreen
        controller.view.backgroundColor = .systemBackground

        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, onError: onError)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let onError: (String) -> Void

        init(url: URL, onError: @escaping (String) -> Void) {
            self.url = url
            self.onError = onError
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
@MainActor
struct ModernQuickLookContainer: View {
    let url: URL
    let onError: (String) -> Void

    var body: some View {
        Text("Preview not available on macOS. Use Quick Look from Finder.")
            .foregroundStyle(.secondary)
            .padding()
    }
}
#endif
