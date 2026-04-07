//
//  CollectionsListView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct CollectionsListView: View {
    let store: StoreOf<CollectionsFeature>
    @Binding var selectedCollectionID: Collection.ID?
    let onCollectionSelected: (Collection) -> Void

    @State private var showingAddSheet = false
    @State private var addCollectionType: CollectionType = .book
    @State private var addCollectionName = ""
    @State private var renamingCollection: Collection?
    @State private var renameText = ""

    var body: some View {
        let rows = store.state.collectionRows

        List(selection: $selectedCollectionID) {
            collectionsContent(rows: rows)
        }
        .contextMenu {
            newCollectionMenu
        }
        .navigationTitle("Collections")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                newCollectionMenuButton
            }
        }
        #endif
        .sheet(isPresented: $showingAddSheet) {
            addCollectionSheet
        }
        .alert("Rename Collection", isPresented: Binding(
            get: { renamingCollection != nil },
            set: { if !$0 { renamingCollection = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingCollection = nil }
            Button("Rename") {
                if let collection = renamingCollection {
                    store.send(.renameCollection(collection, newName: renameText))
                }
                renamingCollection = nil
            }
        } message: {
            Text("Enter a new name for this collection.")
        }
    }

    @ViewBuilder
    private func collectionsContent(rows: [CollectionRow]) -> some View {
        ForEach(CollectionType.allCases, id: \.self) { type in
            collectionSection(type: type, rows: rows)
        }

        if rows.isEmpty {
            ContentUnavailableView {
                Label("No Collections", systemImage: "square.stack")
            } description: {
                Text("Right-click or use the + button to create your first collection.")
            }
        }

        #if os(macOS)
        Section {
            Menu {
                ForEach(CollectionType.allCases, id: \.self) { type in
                    Button {
                        addCollectionType = type
                        addCollectionName = ""
                        showingAddSheet = true
                    } label: {
                        Label(type.displayName, systemImage: type.systemImage)
                    }
                }
            } label: {
                Label("New Collection…", systemImage: "plus")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        #endif
    }

    @ViewBuilder
    private func collectionSection(type: CollectionType, rows: [CollectionRow]) -> some View {
        let filtered = rows.filter { $0.collection.type == type }
        if !filtered.isEmpty {
            Section(type.displayName) {
                ForEach(filtered) { row in
                    collectionRowView(row: row)
                }
            }
        }
    }

    @ViewBuilder
    private func collectionRowView(row: CollectionRow) -> some View {
        let collection = row.collection
        CollectionRowView(collection: collection, isShared: row.isShared, shareMessage: row.shareMessage)
            .tag(collection.id)
            .onTapGesture {
                onCollectionSelected(collection)
            }
            .contextMenu {
                Button {
                    renameText = collection.name
                    renamingCollection = collection
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Divider()
                newCollectionMenu
                Divider()
                Button(role: .destructive) {
                    store.send(.deleteCollection(collection))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    store.send(.deleteCollection(collection))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Button {
                    renameText = collection.name
                    renamingCollection = collection
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
    }

    // MARK: - New Collection Menu

    @ViewBuilder
    private var newCollectionMenu: some View {
        Menu("New Collection") {
            ForEach(CollectionType.allCases, id: \.self) { type in
                Button {
                    addCollectionType = type
                    addCollectionName = ""
                    showingAddSheet = true
                } label: {
                    Label(type.displayName, systemImage: type.systemImage)
                }
            }
        }
    }

    private var newCollectionMenuButton: some View {
        Menu {
            ForEach(CollectionType.allCases, id: \.self) { type in
                Button {
                    addCollectionType = type
                    addCollectionName = ""
                    showingAddSheet = true
                } label: {
                    Label(type.displayName, systemImage: type.systemImage)
                }
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private var addCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Collection Name") {
                    TextField("Name", text: $addCollectionName)
                }
            }
            .navigationTitle("New \(addCollectionType.singularName) Collection")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.send(.createCollection(
                            name: addCollectionName,
                            type: addCollectionType
                        ))
                        showingAddSheet = false
                    }
                    .disabled(addCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Collection Row

struct CollectionRowView: View {
    let collection: Collection
    var isShared: Bool = false
    var shareMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: collection.type.systemImage)
                .font(.title3)
                .foregroundStyle(collection.type.color)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name.isEmpty ? collection.type.singularName : collection.name)
                    .font(.body)
                    .fontWeight(.medium)

                if let shareMessage {
                    Text(shareMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isShared {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
