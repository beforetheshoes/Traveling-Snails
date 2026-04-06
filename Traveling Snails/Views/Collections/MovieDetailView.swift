//
//  MovieDetailView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct MovieDetailView: View {
    @Bindable var store: StoreOf<MovieItemDetailFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let item = store.state.movieItem

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

                        if !item.director.isEmpty {
                            Text(item.director)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        StatusBadgeView(status: item.status)

                        RatingView(
                            rating: $store.movieItem.rating.sending(\.ratingChanged),
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

                // MARK: - Watched Date
                if item.hasWatchedDate {
                    watchedDateSection(item: item)
                }

                // MARK: - Overview
                if !item.overview.isEmpty {
                    overviewSection(item: item)
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
                    Label("Delete Movie", systemImage: "trash")
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
            ToolbarItem(placement: .platformTrailing) {
                Menu {
                    if !item.externalID.isEmpty {
                        Button {
                            store.send(.refreshFromAPI)
                        } label: {
                            Label("Refresh from TMDB", systemImage: "arrow.clockwise")
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
            "Delete Movie",
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
    private func statusSection(item: MovieItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MovieStatus.allCases, id: \.self) { status in
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
    private func metadataSection(item: MovieItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 0) {
                if !item.releaseDate.isEmpty {
                    metadataRow(label: "Release Date", value: item.releaseDate)
                }
                if item.runtime > 0 {
                    metadataRow(label: "Runtime", value: item.runtimeFormatted)
                }
                if !item.genres.isEmpty {
                    metadataRow(label: "Genres", value: item.genres)
                }
                if !item.originalLanguage.isEmpty {
                    metadataRow(label: "Language", value: item.originalLanguage.uppercased())
                }
                if item.voteAverage > 0 {
                    metadataRow(label: "TMDB Rating", value: String(format: "%.1f / 10", item.voteAverage))
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
    private func watchedDateSection(item: MovieItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Watch History")
                .font(.headline)

            VStack(spacing: 0) {
                if let watched = item.effectiveWatchedDate {
                    metadataRow(label: "Watched", value: watched.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func overviewSection(item: MovieItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)

            Text(item.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(8)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func notesSection(item: MovieItem) -> some View {
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
                TextEditor(text: $store.editedNotes.sending(\.editedNotesChanged))
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
    private func linksSection(item: MovieItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)

            Link(destination: URL(string: "https://www.themoviedb.org/movie/\(item.externalID)")!) {
                Label("View on TMDB", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private func hasMetadata(_ item: MovieItem) -> Bool {
        !item.releaseDate.isEmpty || item.runtime > 0 || !item.genres.isEmpty
            || !item.originalLanguage.isEmpty || item.voteAverage > 0
    }
}
