//
//  DatabaseCleanupView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

struct DatabaseCleanupView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<DatabaseCleanupFeature>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Database Statistics")
                            .font(.headline)

                        Label("\(store.tripCount) Trips", systemImage: "airplane")
                        Label("\(store.organizationCount) Organizations", systemImage: "building.2")
                        Label("\(store.addressCount) Addresses", systemImage: "location")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Current Data")
                }

                Section {
                    Button("Remove Test Data") {
                        store.send(.removeTestDataTapped)
                    }
                    .foregroundStyle(.orange)
                    .disabled(store.isDeleting)

                    Button("Reset All Data") {
                        store.send(.resetAllDataTapped)
                    }
                    .foregroundStyle(.red)
                    .disabled(store.isDeleting)
                } header: {
                    Text("Cleanup Options")
                } footer: {
                    Text("Remove Test Data removes trips and organizations with test-like names. Reset All Data removes everything.")
                }

                if !store.deleteResult.isEmpty {
                    Section {
                        Text(store.deleteResult)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Last Operation")
                    }
                }
            }
            .navigationTitle("Database Cleanup")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(
                "Remove Test Data",
                isPresented: Binding(
                    get: { store.showingTestDataConfirmation },
                    set: { store.send(.testDataDialogChanged($0)) }
                )
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    store.send(.testDataConfirmed)
                }
            } message: {
                Text("This will remove trips and organizations that appear to be test data. This action cannot be undone.")
            }
            .alert(
                "Reset All Data",
                isPresented: Binding(
                    get: { store.showingDeleteConfirmation },
                    set: { store.send(.deleteDialogChanged($0)) }
                )
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    store.send(.resetAllConfirmed)
                }
            } message: {
                Text("This will permanently delete all trips, organizations, and related data. This action cannot be undone.")
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    DatabaseCleanupView(
        store: StoreOf<DatabaseCleanupFeature>.init(initialState: DatabaseCleanupFeature.State()) {
            DatabaseCleanupFeature()
        }
    )
}
