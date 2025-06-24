//
//  CrossDeviceEditFileAttachmentView.swift
//  Traveling Snails
//
//

import SwiftUI

@available(iOS 18.0, *)
struct CrossDeviceEditFileAttachmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var attachment: EmbeddedFileAttachment
    @State private var editedDescription: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("File Information") {
                    LabeledContent("Original Name", value: attachment.originalFileName)
                    LabeledContent("Type", value: attachment.fileExtension.uppercased())
                    LabeledContent("Size", value: attachment.formattedFileSize)
                    LabeledContent("Created", value: attachment.createdDate.formatted(date: .abbreviated, time: .shortened))
                }
                
                Section("Description") {
                    TextField("Add a description", text: $editedDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .disabled(isSaving)
                }
                
                if attachment.isImage, let data = attachment.fileData, let image = UIImage(data: data) {
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
                
                if let saveError = saveError {
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
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                editedDescription = attachment.fileDescription
            }
        }
    }
    
    private func saveChanges() async {
        isSaving = true
        saveError = nil
        
        do {
            attachment.fileDescription = editedDescription
            try modelContext.save()
            dismiss()
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}
