//
//  ToolsTab.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

struct ToolsTab: View {
    private enum ActiveSheet: Identifiable {
        case exportOptions

        var id: Int { 0 }
    }

    let onDataChanged: () -> Void
    @State private var store: StoreOf<ToolsFeature>
    @State private var exportStore: StoreOf<DatabaseExportFeature>

    init(
        onDataChanged: @escaping () -> Void = {},
        store: StoreOf<ToolsFeature>,
        exportStore: StoreOf<DatabaseExportFeature>
    ) {
        self.onDataChanged = onDataChanged
        self._store = State(initialValue: store)
        self._exportStore = State(initialValue: exportStore)
    }

    var body: some View {
        List {
            Section("Database Maintenance") {
                MaintenanceButton(
                    title: "Compact Database",
                    description: "Optimize database storage and performance",
                    icon: "arrow.down.circle",
                    color: .blue,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.compactDatabaseTapped)
                }

                MaintenanceButton(
                    title: "Rebuild Relationships",
                    description: "Fix broken relationships between objects",
                    icon: "link.circle",
                    color: .orange,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.rebuildRelationshipsTapped)
                }

                MaintenanceButton(
                    title: "Validate Data Integrity",
                    description: "Check for data consistency issues",
                    icon: "checkmark.shield",
                    color: .green,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.validateDataIntegrityTapped)
                }
            }

            Section("Data Operations") {
                MaintenanceButton(
                    title: "Export Database Info",
                    description: "Export database structure and statistics",
                    icon: "square.and.arrow.up",
                    color: .purple,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.exportOptionsTapped)
                }

                MaintenanceButton(
                    title: "Create Test Data",
                    description: "Add sample data for testing purposes",
                    icon: "plus.circle.fill",
                    color: .cyan,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.createTestDataTapped)
                }
            }

            Section("Advanced Operations") {
                MaintenanceButton(
                    title: "Reset All Data",
                    description: "⚠️ Delete all data and start fresh",
                    icon: "trash.fill",
                    color: .red,
                    isLoading: store.isPerformingOperation
                ) {
                    store.send(.resetAllDataTapped)
                }
            }

            if !store.operationStatus.isEmpty {
                Section("Operation Status") {
                    Text(store.operationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Reset All Data",
            isPresented: Binding(
                get: { store.showingResetConfirmation },
                set: { store.send(.resetDialogChanged($0)) }
            ),
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                store.send(.confirmReset)
            }
        } message: {
            Text("This will permanently delete ALL data including trips, activities, organizations, and attachments. This action cannot be undone.")
        }
        .confirmationDialog(
            "Compact Database",
            isPresented: Binding(
                get: { store.showingCompactConfirmation },
                set: { store.send(.compactDialogChanged($0)) }
            ),
            titleVisibility: .visible
        ) {
            Button("Compact") {
                store.send(.confirmCompact)
            }
        } message: {
            Text("This will optimize the database storage. The operation may take a few moments.")
        }
        .sheet(item: exportSheet) { sheet in
            switch sheet {
            case .exportOptions:
                DatabaseExportView(store: exportStore)
            }
        }
        .onChange(of: store.operationStatus) { _, _ in
            if !store.isPerformingOperation {
                onDataChanged()
            }
        }
    }

    private var exportSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                store.showingExportOptions ? .exportOptions : nil
            },
            set: { newValue in
                store.send(.exportSheetChanged(newValue != nil))
            }
        )
    }
}

private struct MaintenanceButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}
