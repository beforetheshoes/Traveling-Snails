//
//  UnifiedFilePicker.swift
//  Traveling Snails
//
//

import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Unified file picker that handles both photos and documents with proper cleanup
struct UnifiedFilePicker: View {
    @Environment(\.modelContext) private var modelContext

    // Configuration
    let allowsPhotos: Bool
    let allowsDocuments: Bool
    let allowedContentTypes: [UTType]
    let onFileSelected: (EmbeddedFileAttachment) -> Void
    let onError: ((String) -> Void)?

    // State
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingDocumentPicker = false
    @State private var showingPhotosPicker = false
    @State private var isProcessing = false
    @State private var showingPermissionAlert = false

    // Cleanup tracking
    @State private var temporaryFiles: Set<URL> = []

    // Permission management
    private let permissionManager = PermissionStatusManager.shared

    init(
        allowsPhotos: Bool = true,
        allowsDocuments: Bool = true,
        allowedContentTypes: [UTType] = [.pdf, .plainText, .rtf, .jpeg, .png, .heic, .data, .item],
        onFileSelected: @escaping (EmbeddedFileAttachment) -> Void,
        onError: ((String) -> Void)? = nil
    ) {
        self.allowsPhotos = allowsPhotos
        self.allowsDocuments = allowsDocuments
        self.allowedContentTypes = allowedContentTypes
        self.onFileSelected = onFileSelected
        self.onError = onError
    }

    var body: some View {
        Menu {
            if allowsPhotos {
                Button {
                    Task {
                        await handlePhotoButtonTap()
                    }
                } label: {
                    Label("Choose Photo", systemImage: "photo")
                }
            }

            if allowsDocuments {
                Button {
                    showingDocumentPicker = true
                } label: {
                    Label("Choose Document", systemImage: "doc")
                }
            }
        } label: {
            HStack {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Label("Add Attachment", systemImage: "paperclip")
                }
            }
        }
        .disabled(isProcessing)
        .photosPicker(
            isPresented: $showingPhotosPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            if let newItem = newItem {
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleDocumentSelection(result)
        }
        .onDisappear {
            cleanupTemporaryFiles()
        }
        .permissionEducationAlert(
            isPresented: $showingPermissionAlert,
            permissionType: .photoLibrary
        )            {
                permissionManager.openAppSettings()
            }
    }

    // MARK: - Permission Handling

    @MainActor
    private func handlePhotoButtonTap() async {
        let permissionStatus = permissionManager.checkPhotoLibraryPermission()

        switch permissionStatus {
        case .granted, .limited:
            // Permission granted, show photo picker
            showingPhotosPicker = true

        case .denied:
            // Permission denied, show education alert
            showingPermissionAlert = true

        case .restricted:
            // Permission restricted, show error
            handleError(FilePickerError.permissionRestricted.localizedDescription)

        case .notDetermined:
            // Request permission
            let newStatus = await permissionManager.requestPhotoLibraryAccess()
            await handlePermissionResult(newStatus)

        case .unknown:
            // Handle unknown future cases
            handleError(FilePickerError.permissionNotDetermined.localizedDescription)
        }
    }

    @MainActor
    private func handlePermissionResult(_ status: PHAuthorizationStatus) async {
        switch status {
        case .authorized, .limited:
            showingPhotosPicker = true
        case .denied:
            handleError(FilePickerError.permissionDenied.localizedDescription)
        case .restricted:
            handleError(FilePickerError.permissionRestricted.localizedDescription)
        case .notDetermined:
            handleError(FilePickerError.permissionNotDetermined.localizedDescription)
        @unknown default:
            handleError(FilePickerError.permissionNotDetermined.localizedDescription)
        }
    }

    // MARK: - Photo Handling

    @MainActor
    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        print("📸 Photo selection started") // Temporary until Logger is available
        isProcessing = true

        defer {
            selectedPhotoItem = nil
            isProcessing = false
        }

        do {
            // Try to get the photo's original file extension/type
            var fileExtension = "jpg" // Default fallback
            var originalName = item.itemIdentifier ?? generatePhotoName()

            // Try to load as transferable to get type information
            if let supportedContentTypes = item.supportedContentTypes.first {
                if let preferredExtension = supportedContentTypes.preferredFilenameExtension {
                    fileExtension = preferredExtension
                    print("📸 Photo type detected: \(fileExtension)")
                }
            }

            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw FilePickerError.failedToLoadPhotoData
            }

            print("✅ Photo data loaded: \(data.count) bytes, extension: \(fileExtension)") // Temporary until Logger is available

            // Update original name to use correct extension
            if !originalName.contains(".") {
                originalName = "\(originalName).\(fileExtension)"
            }

            let tempURL = createTemporaryFile(extension: fileExtension)
            try data.write(to: tempURL)
            temporaryFiles.insert(tempURL)

            try await processFile(url: tempURL, originalName: originalName)
        } catch {
            print("❌ Photo selection failed: \(error)") // Temporary until Logger is available
            handleError("Failed to process photo: \(error.localizedDescription)")
        }
    }

    // MARK: - Document Handling

    private func handleDocumentSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                isProcessing = true
                defer { isProcessing = false }

                do {
                    let originalName = url.lastPathComponent
                    try await processFile(url: url, originalName: originalName)
                } catch {
                    print("❌ Document processing failed: \(error)") // Temporary until Logger is available
                    handleError("Failed to process document: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            print("❌ Document picker failed: \(error)") // Temporary until Logger is available
            handleError("Document selection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - File Processing

    private func processFile(url: URL, originalName: String) async throws {
        print("📁 Processing file: \(originalName)") // Temporary until Logger is available

        guard let attachment = EmbeddedFileAttachmentManager.shared.saveFile(
            from: url,
            originalName: originalName
        ) else {
            throw FilePickerError.failedToCreateAttachment
        }

        modelContext.insert(attachment)

        do {
            try modelContext.save()
            await MainActor.run {
                onFileSelected(attachment)
            }
            print("✅ File attachment saved successfully") // Temporary until Logger is available
        } catch {
            modelContext.delete(attachment)
            throw FilePickerError.failedToSaveToDatabase(error)
        }
    }

    // MARK: - Utility Methods

    private func createTemporaryFile(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
    }

    private func generatePhotoName() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Photo_\(formatter.string(from: Date())).jpg"
    }

    private func handleError(_ message: String) {
        onError?(message) ?? print("⚠️ Unhandled file picker error: \(message)") // Temporary until Logger is available
    }

    private func cleanupTemporaryFiles() {
        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                print("🧹 Cleaned up temporary file: \(url.lastPathComponent)") // Temporary until Logger is available
            } catch {
                print("⚠️ Failed to cleanup temporary file: \(error)") // Temporary until Logger is available
            }
        }
        temporaryFiles.removeAll()
    }
}

// MARK: - Error Types

enum FilePickerError: LocalizedError {
    case failedToLoadPhotoData
    case failedToCreateAttachment
    case failedToSaveToDatabase(Error)
    case permissionDenied
    case permissionRestricted
    case permissionNotDetermined

    var errorDescription: String? {
        switch self {
        case .failedToLoadPhotoData:
            return "Failed to load photo data"
        case .failedToCreateAttachment:
            return "Failed to create file attachment"
        case .failedToSaveToDatabase(let error):
            return "Failed to save to database: \(error.localizedDescription)"
        case .permissionDenied:
            return "Photo library access denied. Please enable photo access in Settings to add photos to your trips."
        case .permissionRestricted:
            return "Photo library access is restricted. Please check your device restrictions."
        case .permissionNotDetermined:
            return "Photo library permission is required to add photos to your trips."
        }
    }
}

// MARK: - Convenience Extensions

extension UnifiedFilePicker {
    /// Photo-only picker
    static func photos(onSelected: @escaping (EmbeddedFileAttachment) -> Void, onError: ((String) -> Void)? = nil) -> UnifiedFilePicker {
        UnifiedFilePicker(
            allowsPhotos: true,
            allowsDocuments: false,
            allowedContentTypes: [.jpeg, .png, .heic],
            onFileSelected: onSelected,
            onError: onError
        )
    }

    /// Document-only picker
    static func documents(onSelected: @escaping (EmbeddedFileAttachment) -> Void, onError: ((String) -> Void)? = nil) -> UnifiedFilePicker {
        UnifiedFilePicker(
            allowsPhotos: false,
            allowsDocuments: true,
            allowedContentTypes: [.pdf, .plainText, .rtf],
            onFileSelected: onSelected,
            onError: onError
        )
    }

    /// All files picker
    static func allFiles(onSelected: @escaping (EmbeddedFileAttachment) -> Void, onError: ((String) -> Void)? = nil) -> UnifiedFilePicker {
        UnifiedFilePicker(
            allowsPhotos: true,
            allowsDocuments: true,
            onFileSelected: onSelected,
            onError: onError
        )
    }
}
