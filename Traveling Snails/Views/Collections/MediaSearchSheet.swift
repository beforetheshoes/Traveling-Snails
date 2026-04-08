//
//  MediaSearchSheet.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct MediaSearchSheet: View {
    @Bindable var store: StoreOf<MediaSearchFeature>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                let results = store.results
                let isSearching = store.isSearching
                let hasSearched = store.hasSearched
                let errorMessage = store.errorMessage

                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    ContentUnavailableView {
                        Label("Search Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") { store.send(.searchSubmitted) }
                    }
                    Spacer()
                } else if results.isEmpty && hasSearched {
                    Spacer()
                    ContentUnavailableView.search(text: store.searchText)
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    ContentUnavailableView {
                        Label(store.sheetTitle, systemImage: "magnifyingglass")
                    } description: {
                        Text(store.searchPlaceholder)
                    }
                    Spacer()
                } else {
                    List(results) { result in
                        Button {
                            store.send(.resultSelected(result))
                        } label: {
                            searchResultRow(result)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(store.sheetTitle)
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #endif
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(store.searchPlaceholder, text: $store.searchText.sending(\.searchTextChanged))
            #if os(iOS)
            .textFieldStyle(.plain)
            .submitLabel(.search)
            #else
            .textFieldStyle(.roundedBorder)
            #endif
            .onSubmit { store.send(.searchSubmitted) }

            if !store.searchText.isEmpty {
                Button {
                    store.send(.searchTextChanged(""))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .focusable(false)
            }

            Button("Search") {
                store.send(.searchSubmitted)
            }
            .focusable(false)
            .disabled(store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        #if os(iOS)
        .background(Color.systemGray6)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        #endif
        .padding()
    }

    @ViewBuilder
    private func searchResultRow(_ result: MediaSearchResultItem) -> some View {
        HStack(spacing: 12) {
            if case .restaurant = result {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.teal)
                    .frame(width: 50, height: 75)
                    .background(Color.teal.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                CoverArtView(
                    imageURL: result.thumbnailURL,
                    imageData: nil,
                    width: 50,
                    height: 75,
                    cornerRadius: 4
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !result.detail.isEmpty {
                    Text(result.detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
        }
    }
}
