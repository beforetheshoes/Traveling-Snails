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
        #if DEBUG
        Logger.shared.debug("Photo selection started", category: .filePicker)
        #endif
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
                    #if DEBUG
                    Logger.shared.debug("Photo type detected: \(fileExtension)", category: .filePicker)
                    #endif
                }
            }

            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw FilePickerError.failedToLoadPhotoData
            }

            #if DEBUG
            Logger.shared.debug("Photo data loaded: \(data.count) bytes, extension: \(fileExtension)", category: .filePicker)
            #endif

            // Update original name to use correct extension
            if !originalName.contains(".") {
                originalName = "\(originalName).\(fileExtension)"
            }

            let tempURL = createTemporaryFile(extension: fileExtension)
            try data.write(to: tempURL)
            temporaryFiles.insert(tempURL)

            try await processFile(url: tempURL, originalName: originalName)
        } catch {
            Logger.shared.error("Photo selection failed: \(error.localizedDescription)", category: .filePicker)
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
                    Logger.shared.error("Document processing failed: \(error.localizedDescription)", category: .filePicker)
                    handleError("Failed to process document: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            Logger.shared.error("Document picker failed: \(error.localizedDescription)", category: .filePicker)
            handleError("Document selection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - File Processing

    private func processFile(url: URL, originalName: String) async throws {
        #if DEBUG
        Logger.shared.debug("Processing file: \(originalName)", category: .filePicker)
        #endif

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
            #if DEBUG
            Logger.shared.debug("File attachment saved successfully", category: .filePicker)
            #endif
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
        onError?(message) ?? Logger.shared.error("Unhandled file picker error: \(message)", category: .filePicker)
    }

    private func cleanupTemporaryFiles() {
        for url in temporaryFiles {
            do {
                try FileManager.default.removeItem(at: url)
                #if DEBUG
                Logger.shared.debug("Cleaned up temporary file: \(url.lastPathComponent)", category: .filePicker)
                #endif
            } catch {
                Logger.shared.warning("Failed to cleanup temporary file: \(error.localizedDescription)", category: .filePicker)
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
