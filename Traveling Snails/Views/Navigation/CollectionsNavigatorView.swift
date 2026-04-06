//
//  CollectionsNavigatorView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct CollectionsNavigationView: View {
    let store: StoreOf<CollectionsFeature>
    @Binding var selectedCollectionID: Collection.ID?
    let onCollectionSelected: (Collection) -> Void

    var body: some View {
        let collections = store.state.collections

        #if os(macOS)
        HStack(spacing: 0) {
            CollectionsListView(
                store: store,
                selectedCollectionID: $selectedCollectionID,
                onCollectionSelected: onCollectionSelected
            )
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 300)

            Divider()

            detailContent(collections: collections)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #else
        NavigationSplitView {
            CollectionsListView(
                store: store,
                selectedCollectionID: $selectedCollectionID,
                onCollectionSelected: onCollectionSelected
            )
        } detail: {
            detailContent(collections: collections)
        }
        #endif
    }

    @ViewBuilder
    private func detailContent(collections: [Collection]) -> some View {
        if let selectedID = selectedCollectionID,
           let collection = collections.first(where: { $0.id == selectedID }) {
            CollectionDetailWrapper(collection: collection)
                .id(selectedID)
        } else {
            ContentUnavailableView {
                Label("Select a Collection", systemImage: "square.stack")
            } description: {
                Text("Choose a collection from the sidebar to view its items.")
            }
        }
    }
}

// MARK: - Wrapper that holds a stable Store in @State

private struct CollectionDetailWrapper: View {
    let collection: Collection

    @State private var store: StoreOf<CollectionDetailFeature>

    init(collection: Collection) {
        self.collection = collection
        self._store = State(initialValue: Store(
            initialState: CollectionDetailFeature.State(collection: collection)
        ) {
            CollectionDetailFeature()
        })
    }

    var body: some View {
        CollectionDetailView(store: store)
    }
}
