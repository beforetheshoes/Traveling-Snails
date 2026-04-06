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

    init(store: StoreOf<CollectionDetailFeature>) {
        self.store = store
        let collectionID = store.state.collection.id
        _bookItems = FetchAll(
            BookItem.where { $0.collectionID.eq(collectionID) }
                .order { $0.createdDate.desc() }
        )
    }

    var body: some View {
        let collection = store.state.collection
        let viewMode = store.state.viewMode

        NavigationStack(path: Binding(
            get: { store.state.path },
            set: { newPath in
                // Sync path changes back — handle pop
                if newPath.count < store.state.path.count {
                    // User popped; we just accept the new path
                }
            }
        )) {
            Group {
                if bookItems.isEmpty {
                    ContentUnavailableView {
                        Label("No Items", systemImage: collection.type.systemImage)
                    } description: {
                        Text("Tap + to search and add \(collection.type.displayName.lowercased()).")
                    }
                } else {
                    ScrollView {
                        switch viewMode {
                        case .grid:
                            CollectionItemGridView(bookItems: bookItems) { item in
                                store.send(.itemSelected(.bookItem(item.id)))
                            }
                        case .list:
                            LazyVStack(spacing: 0) {
                                ForEach(bookItems) { item in
                                    BookItemListRow(item: item)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .onTapGesture {
                                            store.send(.itemSelected(.bookItem(item.id)))
                                        }
                                    Divider()
                                        .padding(.leading, 74)
                                }
                            }
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
                switch route {
                case .bookItem(let id):
                    if let item = bookItems.first(where: { $0.id == id }) {
                        BookDetailView(
                            store: Store(
                                initialState: BookItemDetailFeature.State(bookItem: item)
                            ) {
                                BookItemDetailFeature()
                            }
                        )
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { store.state.showingAddSheet },
            set: { if !$0 { store.send(.addSheetDismissed) } }
        )) {
            MediaSearchSheet(
                store: Store(
                    initialState: MediaSearchFeature.State(
                        collectionID: store.state.collection.id
                    )
                ) {
                    MediaSearchFeature()
                }
            )
        }
        .onAppear { store.send(.onAppear) }
    }
}
