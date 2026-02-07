//
//  CrossDeviceEditFileAttachmentView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

@available(iOS 18.0, *)
struct CrossDeviceEditFileAttachmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<CrossDeviceEditFileAttachmentFeature>

    init(
        attachment: EmbeddedFileAttachment,
        store: StoreOf<CrossDeviceEditFileAttachmentFeature>? = nil
    ) {
        let resolvedStore = store ?? Store(
            initialState: CrossDeviceEditFileAttachmentFeature.State(attachment: attachment)
        ) {
            CrossDeviceEditFileAttachmentFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        @Bindable var store = self.store

        NavigationStack {
            Form {
                Section("File Information") {
                    LabeledContent("Original Name", value: store.attachment.originalFileName)
                    LabeledContent("Type", value: store.attachment.fileExtension.uppercased())
                    LabeledContent("Size", value: store.attachment.formattedFileSize)
                    LabeledContent("Created", value: store.attachment.createdDate.formatted(date: .abbreviated, time: .shortened))
                }

                Section("Description") {
                    TextField("Add a description", text: $store.editedDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(store.isSaving)
                }

                if store.attachment.isImage, let data = store.attachment.fileData, let image = UIImage(data: data) {
                    Section("Preview") {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .containerRelativeFrame(.horizontal) { width, _ in
                                min(width - 32, 300)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                if let saveError = store.saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.send(.saveTapped)
                    }
                    .disabled(store.isSaving)
                }
            }
            .onChange(of: store.shouldDismiss) { _, shouldDismiss in
                guard shouldDismiss else { return }
                dismiss()
                store.send(.dismissHandled)
            }
        }
    }
}
