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
            CollectionDetailView(
                store: Store(
                    initialState: CollectionDetailFeature.State(collection: collection)
                ) {
                    CollectionDetailFeature()
                }
            )
        } else {
            ContentUnavailableView {
                Label("Select a Collection", systemImage: "square.stack")
            } description: {
                Text("Choose a collection from the sidebar to view its items.")
            }
        }
    }
}
