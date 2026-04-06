//
//  CollectionDetailView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct CollectionDetailView: View {
    let store: StoreOf<CollectionDetailFeature>

    @FetchAll var bookItems: [BookItem]
    @FetchAll var movieItems: [MovieItem]
    @FetchAll var tvShowItems: [TVShowItem]

    init(store: StoreOf<CollectionDetailFeature>) {
        self.store = store
        let collectionID = store.state.collection.id
        _bookItems = FetchAll(
            BookItem.where { $0.collectionID.eq(collectionID) }
                .order { $0.createdDate.desc() }
        )
        _movieItems = FetchAll(
            MovieItem.where { $0.collectionID.eq(collectionID) }
                .order { $0.createdDate.desc() }
        )
        _tvShowItems = FetchAll(
            TVShowItem.where { $0.collectionID.eq(collectionID) }
                .order { $0.createdDate.desc() }
        )
    }

    private var collectionType: CollectionType {
        store.state.collection.type
    }

    var body: some View {
        let collection = store.state.collection
        let viewMode = store.state.viewMode

        NavigationStack(path: Binding(
            get: { store.state.path },
            set: { newPath in
                if newPath.count < store.state.path.count {
                    // User popped
                }
            }
        )) {
            Group {
                if isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: collection.type.systemImage)
                    } description: {
                        Text("Use + or right-click to search and add \(collection.type.displayName.lowercased()).")
                    }
                } else {
                    ScrollView {
                        switch viewMode {
                        case .grid:
                            gridContent
                        case .list:
                            listContent
                        }
                    }
                }
            }
            .contextMenu {
                Button {
                    store.send(.addItemTapped)
                } label: {
                    Label("Add \(collection.type.singularName)…", systemImage: "plus")
                }
            }
            .navigationTitle(collection.name.isEmpty ? collection.type.singularName : collection.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Picker("View", selection: Binding(
                            get: { store.state.viewMode },
                            set: { store.send(.viewModeChanged($0)) }
                        )) {
                            ForEach(CollectionDetailFeature.ViewMode.allCases, id: \.self) { mode in
                                Image(systemName: mode.icon)
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)

                        Button {
                            store.send(.addItemTapped)
                        } label: {
                            Image(systemName: "plus")
                        }

                        Button {
                            store.send(.shareTapped)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationDestination(for: CollectionRoute.self) { route in
                destinationView(for: route)
            }
        }
        .sheet(isPresented: Binding(
            get: { store.state.showingAddSheet },
            set: { if !$0 { store.send(.addSheetDismissed) } }
        )) {
            MediaSearchSheet(
                store: Store(
                    initialState: MediaSearchFeature.State(
                        collectionID: store.state.collection.id,
                        collectionType: store.state.collection.type
                    )
                ) {
                    MediaSearchFeature()
                }
            )
        }
        .onAppear { store.send(.onAppear) }
    }

    // MARK: - Helpers

    private var isEmpty: Bool {
        switch collectionType {
        case .book: return bookItems.isEmpty
        case .movie: return movieItems.isEmpty
        case .tvShow: return tvShowItems.isEmpty
        default: return true
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        switch collectionType {
        case .book:
            CollectionItemGridView(bookItems: bookItems) { item in
                store.send(.itemSelected(.bookItem(item.id)))
            }
        case .movie:
            MediaItemGridView(items: movieItems.map { MediaGridItem(id: $0.id, title: $0.title, subtitle: $0.displaySubtitle, coverImageURL: $0.posterURL, coverImageData: $0.coverImageData, rating: $0.rating) }) { id in
                store.send(.itemSelected(.movieItem(id)))
            }
        case .tvShow:
            MediaItemGridView(items: tvShowItems.map { MediaGridItem(id: $0.id, title: $0.title, subtitle: $0.displaySubtitle, coverImageURL: $0.posterURL, coverImageData: $0.coverImageData, rating: $0.rating) }) { id in
                store.send(.itemSelected(.tvShowItem(id)))
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var listContent: some View {
        LazyVStack(spacing: 0) {
            switch collectionType {
            case .book:
                ForEach(bookItems) { item in
                    BookItemListRow(item: item)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            store.send(.itemSelected(.bookItem(item.id)))
                        }
                    Divider().padding(.leading, 74)
                }
            case .movie:
                ForEach(movieItems) { item in
                    MediaItemListRow(title: item.title, subtitle: item.displaySubtitle, coverImageURL: item.posterURL, coverImageData: item.coverImageData, statusText: item.status.displayName, statusColor: item.status.color, rating: item.rating)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            store.send(.itemSelected(.movieItem(item.id)))
                        }
                    Divider().padding(.leading, 74)
                }
            case .tvShow:
                ForEach(tvShowItems) { item in
                    MediaItemListRow(title: item.title, subtitle: item.displaySubtitle, coverImageURL: item.posterURL, coverImageData: item.coverImageData, statusText: item.status.displayName, statusColor: item.status.color, rating: item.rating)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .onTapGesture {
                            store.send(.itemSelected(.tvShowItem(item.id)))
                        }
                    Divider().padding(.leading, 74)
                }
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: CollectionRoute) -> some View {
        switch route {
        case .bookItem(let id):
            if let item = bookItems.first(where: { $0.id == id }) {
                BookDetailView(
                    store: Store(initialState: BookItemDetailFeature.State(bookItem: item)) {
                        BookItemDetailFeature()
                    }
                )
            }
        case .movieItem(let id):
            if let item = movieItems.first(where: { $0.id == id }) {
                MovieDetailView(
                    store: Store(initialState: MovieItemDetailFeature.State(movieItem: item)) {
                        MovieItemDetailFeature()
                    }
                )
            }
        case .tvShowItem(let id):
            if let item = tvShowItems.first(where: { $0.id == id }) {
                TVShowDetailView(
                    store: Store(initialState: TVShowItemDetailFeature.State(tvShowItem: item)) {
                        TVShowItemDetailFeature()
                    }
                )
            }
        }
    }
}

// MARK: - Generic Media Grid/List Components

struct MediaGridItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let coverImageURL: String
    let coverImageData: Data?
    let rating: Int
}

struct MediaItemGridView: View {
    let items: [MediaGridItem]
    let onItemSelected: (UUID) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    CoverArtView(
                        imageURL: item.coverImageURL,
                        imageData: item.coverImageData,
                        width: 120,
                        height: 180
                    )

                    Text(item.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if item.rating > 0 {
                        StaticRatingView(rating: item.rating, starSize: 10)
                    }
                }
                .frame(width: 120)
                .onTapGesture { onItemSelected(item.id) }
            }
        }
        .padding(.horizontal)
    }
}

struct MediaItemListRow: View {
    let title: String
    let subtitle: String
    let coverImageURL: String
    let coverImageData: Data?
    let statusText: String
    let statusColor: Color
    let rating: Int

    var body: some View {
        HStack(spacing: 12) {
            CoverArtView(
                imageURL: coverImageURL,
                imageData: coverImageData,
                width: 50,
                height: 75,
                cornerRadius: 4
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(statusText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.15))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())

                    if rating > 0 {
                        StaticRatingView(rating: rating, starSize: 10)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
