//
//  ImprovedQuickLookView.swift
//  Traveling Snails
//
//

import QuickLook
import SwiftUI

@available(iOS 18.0, *)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
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
            let canPreview = QLPreviewController.canPreview(url as QLPreviewItem)
            if !canPreview {
                loadError = "This file type cannot be previewed"
                return
            }

            isLoading = false
        } catch {
            loadError = "Error accessing file: \(error.localizedDescription)"
        }
    }
}

@available(iOS 18.0, *)
struct ModernQuickLookContainer: UIViewControllerRepresentable {
    let url: URL
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator

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

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
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

        func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
            .disabled
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            // Handle dismissal
        }
    }
}
