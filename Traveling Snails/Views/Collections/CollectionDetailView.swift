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
    @FetchAll var restaurantItems: [RestaurantItem]

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
        _restaurantItems = FetchAll(
            RestaurantItem.where { $0.collectionID.eq(collectionID) }
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
                store.send(.pathChanged(newPath))
            }
        )) {
            Group {
                if isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .overlay {
                            ContentUnavailableView {
                                Label("No Items", systemImage: collection.type.systemImage)
                            } description: {
                                Text("Use + or right-click to search and add \(collection.type.displayName.lowercased()).")
                            }
                        }
                        .contextMenu {
                            Button {
                                store.send(.addItemTapped)
                            } label: {
                                Label("Add \(collection.type.singularName)…", systemImage: "plus")
                            }
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
                    .contextMenu {
                        Button {
                            store.send(.addItemTapped)
                        } label: {
                            Label("Add \(collection.type.singularName)…", systemImage: "plus")
                        }
                    }
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

                        if collectionType == .restaurant {
                            Menu {
                                Picker("Group By", selection: Binding(
                                    get: { store.state.groupBy },
                                    set: { store.send(.groupByChanged($0)) }
                                )) {
                                    ForEach(CollectionDetailFeature.GroupBy.allCases, id: \.self) { group in
                                        Text(group.displayName).tag(group)
                                    }
                                }
                            } label: {
                                Image(systemName: store.state.groupBy == .none
                                    ? "rectangle.3.group"
                                    : "rectangle.3.group.fill")
                            }
                        }

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
        .onChange(of: restaurantItems) { _, items in
            let missing = items.filter { $0.coverImageData == nil }
            if !missing.isEmpty {
                store.send(.regenerateMissingCovers(missing))
            }
        }
    }

    // MARK: - Helpers

    private var isEmpty: Bool {
        switch collectionType {
        case .book: return bookItems.isEmpty
        case .movie: return movieItems.isEmpty
        case .tvShow: return tvShowItems.isEmpty
        case .restaurant: return restaurantItems.isEmpty
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
        case .restaurant:
            groupedRestaurantGrid
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
            case .restaurant:
                groupedRestaurantList
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
        case .restaurantItem(let id):
            if let item = restaurantItems.first(where: { $0.id == id }) {
                RestaurantDetailView(
                    store: Store(initialState: RestaurantItemDetailFeature.State(restaurantItem: item)) {
                        RestaurantItemDetailFeature()
                    }
                )
            }
        }
    }

    // MARK: - Restaurant Grouping

    private typealias GroupBy = CollectionDetailFeature.GroupBy

    private func restaurantGroupKey(for item: RestaurantItem) -> String {
        switch store.state.groupBy {
        case .none: return ""
        case .city: return item.city ?? ""
        case .state: return item.state ?? ""
        case .country: return item.country ?? ""
        }
    }

    private var groupedRestaurants: [(key: String, items: [RestaurantItem])] {
        let groupBy = store.state.groupBy
        guard groupBy != .none else { return [("", restaurantItems)] }

        var groups: [String: [RestaurantItem]] = [:]
        for item in restaurantItems {
            let key = restaurantGroupKey(for: item)
            groups[key.isEmpty ? "Unknown" : key, default: []].append(item)
        }
        return groups.sorted { $0.key < $1.key }.map { (key: $0.key, items: $0.value) }
    }

    @ViewBuilder
    private var groupedRestaurantGrid: some View {
        let groups = groupedRestaurants
        ForEach(groups, id: \.key) { group in
            if store.state.groupBy != .none {
                Section {
                    RestaurantGridView(items: group.items) { id in
                        store.send(.itemSelected(.restaurantItem(id)))
                    } onDelete: { item in
                        store.send(.deleteRestaurantItem(item))
                    }
                } header: {
                    HStack {
                        Text(group.key)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, group.key == groups.first?.key ? 0 : 12)
                }
            } else {
                RestaurantGridView(items: group.items) { id in
                    store.send(.itemSelected(.restaurantItem(id)))
                } onDelete: { item in
                    store.send(.deleteRestaurantItem(item))
                }
            }
        }
    }

    @ViewBuilder
    private var groupedRestaurantList: some View {
        let groups = groupedRestaurants
        ForEach(groups, id: \.key) { group in
            if store.state.groupBy != .none {
                HStack {
                    Text(group.key)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(group.items.count)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }

            ForEach(group.items) { item in
                MediaItemListRow(title: item.title, subtitle: item.displaySubtitle, coverImageURL: "", coverImageData: item.coverImageData, statusText: item.status.displayName, statusColor: item.status.color, rating: item.rating, placeholderIcon: "fork.knife")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        store.send(.itemSelected(.restaurantItem(item.id)))
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.send(.deleteRestaurantItem(item))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                Divider().padding(.leading, 74)
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
    var placeholderIcon: String = "book.closed"

    var body: some View {
        HStack(spacing: 12) {
            CoverArtView(
                imageURL: coverImageURL,
                imageData: coverImageData,
                width: 50,
                height: 75,
                cornerRadius: 4,
                placeholderIcon: placeholderIcon
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

// MARK: - Restaurant Grid with Context Menu

struct RestaurantGridView: View {
    let items: [RestaurantItem]
    let onItemSelected: (UUID) -> Void
    let onDelete: (RestaurantItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    CoverArtView(
                        imageURL: "",
                        imageData: item.coverImageData,
                        width: 140,
                        height: 140,
                        cornerRadius: 24,
                        placeholderIcon: "fork.knife",
                        imageContentMode: item.isBrandImage ? .fit : .fill
                    )

                    Text(item.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(item.displaySubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if item.rating > 0 {
                        StaticRatingView(rating: item.rating, starSize: 10)
                    }
                }
                .frame(width: 140)
                .onTapGesture { onItemSelected(item.id) }
                .contextMenu {
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}
