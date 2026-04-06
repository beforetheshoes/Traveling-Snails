//
//  BookDetailView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct BookDetailView: View {
    let store: StoreOf<BookItemDetailFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let item = store.state.bookItem

        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Hero Header
                HStack(alignment: .top, spacing: 16) {
                    CoverArtView(
                        imageURL: item.coverImageURL,
                        imageData: item.coverImageData,
                        width: 140,
                        height: 210,
                        cornerRadius: 10
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)

                        if !item.author.isEmpty {
                            Text(item.author)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        StatusBadgeView(status: item.status)

                        RatingView(
                            rating: Binding(
                                get: { store.state.bookItem.rating },
                                set: { store.send(.ratingChanged($0)) }
                            ),
                            starSize: 22
                        )

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // MARK: - Status Picker
                statusSection(item: item)

                // MARK: - Metadata
                if hasMetadata(item) {
                    metadataSection(item: item)
                }

                // MARK: - Dates
                if item.hasStartedDate || item.hasFinishedDate {
                    datesSection(item: item)
                }

                // MARK: - Description
                if !item.description.isEmpty {
                    descriptionSection(item: item)
                }

                // MARK: - Notes
                notesSection(item: item)

                // MARK: - Links
                if !item.externalID.isEmpty {
                    linksSection(item: item)
                }

                // MARK: - Delete
                Button(role: .destructive) {
                    store.send(.deleteTapped)
                } label: {
                    Label("Delete Book", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top)
        }
        .navigationTitle(item.title)
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !item.externalID.isEmpty {
                        Button {
                            store.send(.refreshFromAPI)
                        } label: {
                            Label("Refresh from Google Books", systemImage: "arrow.clockwise")
                        }
                    }
                    if !item.coverImageURL.isEmpty && item.coverImageData == nil {
                        Button {
                            store.send(.downloadCoverImage)
                        } label: {
                            Label("Download Cover Image", systemImage: "arrow.down.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete Book",
            isPresented: Binding(
                get: { store.state.showingDeleteConfirmation },
                set: { if !$0 { store.send(.deleteCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
        } message: {
            Text("Are you sure you want to delete \"\(item.title)\"?")
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func statusSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BookStatus.allCases, id: \.self) { status in
                        Button {
                            store.send(.statusChanged(status))
                        } label: {
                            Label(status.displayName, systemImage: status.systemImage)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    item.status == status
                                        ? status.color.opacity(0.2)
                                        : Color.systemGray6
                                )
                                .foregroundStyle(
                                    item.status == status
                                        ? status.color
                                        : .secondary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func metadataSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 0) {
                if !item.publisher.isEmpty {
                    metadataRow(label: "Publisher", value: item.publisher)
                }
                if !item.isbn.isEmpty {
                    metadataRow(label: "ISBN", value: item.isbn)
                }
                if item.pageCount > 0 {
                    metadataRow(label: "Pages", value: "\(item.pageCount)")
                }
                if !item.publishedDate.isEmpty {
                    metadataRow(label: "Published", value: item.publishedDate)
                }
            }
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func datesSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reading Progress")
                .font(.headline)

            VStack(spacing: 0) {
                if let started = item.effectiveStartedDate {
                    metadataRow(label: "Started", value: started.formatted(date: .abbreviated, time: .omitted))
                }
                if let finished = item.effectiveFinishedDate {
                    metadataRow(label: "Finished", value: finished.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func descriptionSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)

            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(8)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func notesSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button {
                    store.send(.editNotesTapped)
                } label: {
                    Image(systemName: "pencil")
                }
            }

            if store.state.isEditing {
                TextEditor(text: Binding(
                    get: { store.state.editedNotes },
                    set: { store.send(.editedNotesChanged($0)) }
                ))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.systemGray6)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Cancel") { store.send(.cancelEditNotes) }
                        .buttonStyle(.bordered)
                    Button("Save") { store.send(.saveNotesTapped) }
                        .buttonStyle(.borderedProminent)
                }
            } else if item.notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text(item.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func linksSection(item: BookItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)

            Link(destination: URL(string: "https://books.google.com/books?id=\(item.externalID)")!) {
                Label("View on Google Books", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private func hasMetadata(_ item: BookItem) -> Bool {
        !item.publisher.isEmpty || !item.isbn.isEmpty || item.pageCount > 0 || !item.publishedDate.isEmpty
    }
}
