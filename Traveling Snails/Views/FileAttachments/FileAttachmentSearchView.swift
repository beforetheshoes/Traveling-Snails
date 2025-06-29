//
//  FileAttachmentSearchView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct FileAttachmentSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allAttachments: [EmbeddedFileAttachment]

    @State private var searchText = ""
    @State private var selectedFileType: FileType = .all
    @State private var showingExportView = false

    enum FileType: String, CaseIterable {
        case all = "All"
        case images = "Images"
        case documents = "Documents"
        case pdfs = "PDFs"
        case other = "Other"

        var icon: String {
            switch self {
            case .all: return "doc.on.doc"
            case .images: return "photo"
            case .documents: return "doc.text"
            case .pdfs: return "doc.richtext"
            case .other: return "doc"
            }
        }
    }

    var filteredAttachments: [EmbeddedFileAttachment] {
        var filtered = allAttachments

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { attachment in
                attachment.displayName.localizedCaseInsensitiveContains(searchText) ||
                attachment.originalFileName.localizedCaseInsensitiveContains(searchText) ||
                attachment.fileDescription.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by file type
        switch selectedFileType {
        case .all:
            break
        case .images:
            filtered = filtered.filter { $0.isImage }
        case .documents:
            filtered = filtered.filter { $0.isDocument }
        case .pdfs:
            filtered = filtered.filter { $0.isPDF }
        case .other:
            filtered = filtered.filter { !$0.isImage && !$0.isDocument && !$0.isPDF }
        }

        return filtered.sorted { $0.createdDate > $1.createdDate }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    UnifiedSearchBar(text: $searchText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(FileType.allCases, id: \.self) { type in
                                FilterChip(
                                    title: type.rawValue,
                                    icon: type.icon,
                                    isSelected: selectedFileType == type
                                ) {
                                    selectedFileType = type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGroupedBackground))

                // Results
                if filteredAttachments.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Attachments" : "No Results",
                        systemImage: searchText.isEmpty ? "paperclip" : "magnifyingglass",
                        description: Text(searchText.isEmpty ?
                            "Attachments you add to activities will appear here" :
                            "Try adjusting your search terms or filters"
                        )
                    )
                } else {
                    List {
                        ForEach(filteredAttachments) { attachment in
                            FileAttachmentSearchResultView(attachment: attachment)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("All Attachments")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingExportView = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(filteredAttachments.isEmpty)
                }
            }
            .sheet(isPresented: $showingExportView) {
                NavigationStack {
                    EmbeddedFileAttachmentExportView(attachments: filteredAttachments)
                        .navigationTitle("Export Attachments")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingExportView = false }
                            }
                        }
                }
            }
        }
    }
}
