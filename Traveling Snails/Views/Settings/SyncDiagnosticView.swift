//
//  SyncDiagnosticView.swift
//  Traveling Snails
//

import ComposableArchitecture
import Dependencies
import SwiftUI

struct SyncDiagnosticView: View {
    @Bindable var store: StoreOf<SyncDiagnosticFeature>

    var body: some View {
        List {
            // MARK: - Overview
            Section("Sync Status") {
                HStack {
                    Label(
                        store.status.isSyncing ? "Syncing" : "Idle",
                        systemImage: store.status.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle"
                    )
                    .foregroundStyle(store.status.isSyncing ? .blue : .green)
                    .font(.subheadline)
                    Spacer()
                    if let lastSync = store.status.lastSyncDate {
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.status.hasSyncError {
                    Label("Sync error occurred", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }

                HStack(spacing: 12) {
                    Button("Sync Now", systemImage: "arrow.clockwise") {
                        store.send(.triggerSyncTapped)
                    }
                    Button("Retry Sync", systemImage: "arrow.clockwise.circle") {
                        store.send(.triggerSyncWithRetryTapped)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.status.isSyncing || store.isRefreshing)
            }

            // MARK: - Database Counts
            Section("Database") {
                recordCountGrid
                DisclosureGroup("Trip Data") {
                    tripCountGrid
                }
                .font(.subheadline)
            }

            // MARK: - Deletion Log
            if !store.deletionLogEntries.isEmpty {
                Section {
                    ForEach(store.deletionLogEntries.prefix(10)) { entry in
                        deletionRow(entry)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Recent Deletions")
                        Text("\(store.deletionLogEntries.count)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
            }

            // MARK: - Sync Events
            if !store.syncEventLogEntries.isEmpty {
                Section("Sync Events") {
                    ForEach(store.syncEventLogEntries.prefix(10)) { entry in
                        syncEventRow(entry)
                    }
                }
            }

            // MARK: - Troubleshooting
            Section("Troubleshooting") {
                DisclosureGroup("CloudKit Schema Probe") {
                    Text("Saves a test record to verify each collection type is accepted by CloudKit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    Button(store.isRunningProbe ? "Probing..." : "Run Probe", systemImage: "antenna.radiowaves.left.and.right") {
                        store.send(.runRecordTypeProbe)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isRunningProbe)

                    if !store.recordTypeProbeResults.isEmpty {
                        probeResultsGrid
                    }
                }
                .font(.subheadline)

                HStack {
                    Text("CloudKit Environment")
                        .font(.subheadline)
                    Spacer()
                    let env = cloudKitEnvironment
                    Text(env)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(env == "Production" ? .green : .orange)
                }

                Toggle(isOn: Binding(
                    get: { store.status.syncProtectedTrips },
                    set: { store.send(.syncProtectedTripsChanged($0)) }
                )) {
                    Text("Sync Protected Trips")
                        .font(.subheadline)
                }
            }

            // MARK: - Force Re-sync
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clears CloudKit server state and re-queues all local records for push. Use this after switching CloudKit environments (e.g. Development → Production).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(role: .destructive) {
                        store.send(.forceResyncTapped)
                    } label: {
                        Label(
                            store.isForceResyncing ? "Re-syncing..." : "Force Re-sync All Records",
                            systemImage: "arrow.triangle.2.circlepath.circle.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(store.isForceResyncing)

                    if let result = store.forceResyncResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("Error") ? .red : .green)
                            .padding(.top, 2)
                    }
                }
            } header: {
                Text("Re-sync")
            }

            // MARK: - Actions
            Section("Actions") {
                HStack(spacing: 12) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        store.send(.refreshTapped)
                        store.send(.loadRecordCounts)
                        store.send(.loadDeletionLog)
                        store.send(.loadSyncEventLog)
                    }
                    .disabled(store.isRefreshing)

                    Button("Copy Logs", systemImage: "doc.on.clipboard") {
                        store.send(.copyLogsTapped)
                    }

                    Button("Clear Logs", systemImage: "trash", role: .destructive) {
                        store.send(.clearLogsTapped)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .navigationTitle("Sync Diagnostics")
        .inlineNavigationBarTitle()
        .onAppear {
            store.send(.onAppear)
            store.send(.loadRecordCounts)
            store.send(.loadDeletionLog)
            store.send(.loadSyncEventLog)
        }
    }

    // MARK: - Record Count Grids

    private var recordCountGrid: some View {
        Grid(alignment: .leading, verticalSpacing: 4) {
            ForEach(["Collections", "Book Items", "Movie Items", "TV Show Items", "Restaurant Items"], id: \.self) { entity in
                if let count = store.recordCounts[entity] {
                    GridRow {
                        Text(entity)
                            .font(.subheadline)
                        Spacer()
                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                            .foregroundStyle(count == 0 ? .orange : .primary)
                    }
                }
            }
        }
    }

    private var tripCountGrid: some View {
        Grid(alignment: .leading, verticalSpacing: 4) {
            ForEach(["Trips", "Activities", "Transportation", "Lodging", "Organizations", "Addresses"], id: \.self) { entity in
                if let count = store.recordCounts[entity] {
                    GridRow {
                        Text(entity)
                            .font(.caption)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private var probeResultsGrid: some View {
        Grid(alignment: .leading, verticalSpacing: 4) {
            ForEach(store.recordTypeProbeResults.sorted(by: { $0.key < $1.key }), id: \.key) { recordType, result in
                GridRow {
                    Text(friendlyTableName(recordType))
                        .font(.caption)
                    Spacer()
                    switch result {
                    case .success:
                        Label("OK", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .failed(let error):
                        Label(error, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption2)
                            .lineLimit(1)
                    case .pending:
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - Row Views

    private func deletionRow(_ entry: DeletionLogEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.red)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.recordTitle.isEmpty ? "Unknown" : entry.recordTitle)
                    .font(.subheadline)
                Text(friendlyTableName(entry.tableName))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatTimestamp(entry.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func syncEventRow(_ entry: SyncEventEntry) -> some View {
        HStack(spacing: 8) {
            Image(systemName: syncEventIcon(for: entry.eventType))
                .font(.caption)
                .foregroundStyle(syncEventColor(for: entry.eventType))
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(friendlyEventType(entry.eventType))
                    .font(.subheadline)
                    .foregroundStyle(syncEventColor(for: entry.eventType))
                if !entry.details.isEmpty {
                    Text(entry.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(formatTimestamp(entry.timestamp))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Helpers

    private var cloudKitEnvironment: String {
        // Read from embedded provisioning profile's entitlements, or fall back
        // to checking the entitlements plist directly
        if let url = Bundle.main.url(forResource: "Traveling_Snails", withExtension: "entitlements"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let env = plist["com.apple.developer.icloud-container-environment"] as? String
        {
            return env.capitalized
        }
        // Entitlements aren't readable at runtime in most builds.
        // Check the codesign entitlements embedded in the binary.
        #if DEBUG
        // In debug builds, CloudKit defaults to Development unless overridden
        // by the com.apple.developer.icloud-container-environment entitlement.
        // If you set it to Production in your entitlements, you ARE using Production.
        return "Set by entitlement"
        #else
        return "Production"
        #endif
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        if let spaceIndex = timestamp.firstIndex(of: " ") {
            let timeStr = String(timestamp[timestamp.index(after: spaceIndex)...])
            return String(timeStr.prefix(8))
        }
        return timestamp
    }

    private func friendlyTableName(_ name: String) -> String {
        switch name {
        case "bookItems": return "Book"
        case "movieItems": return "Movie"
        case "tVShowItems": return "TV Show"
        case "restaurantItems": return "Restaurant"
        case "collections": return "Collection"
        default: return name
        }
    }

    private func friendlyEventType(_ type: String) -> String {
        switch type {
        case "syncStarted": return "Sync started"
        case "syncCompleted": return "Sync completed"
        case "syncFailed": return "Sync failed"
        case "syncWithRetryStarted": return "Retry sync started"
        case "syncWithRetryCompleted": return "Retry sync completed"
        case "syncRetryAttempt": return "Retry attempt"
        case "ITEMS_LOST_DURING_SYNC": return "Items lost!"
        case "ITEMS_RECOVERED": return "Items recovered"
        case "ITEM_GUARD_RECOVERED": return "Item re-inserted"
        default: return type
        }
    }

    private func syncEventIcon(for eventType: String) -> String {
        if eventType.contains("LOST") || eventType.contains("Failed") || eventType.contains("failed") {
            return "exclamationmark.triangle.fill"
        } else if eventType.contains("RECOVERED") || eventType.contains("recovered") {
            return "arrow.uturn.backward.circle.fill"
        } else if eventType.contains("Completed") || eventType.contains("completed") {
            return "checkmark.circle.fill"
        } else {
            return "arrow.triangle.2.circlepath"
        }
    }

    private func syncEventColor(for eventType: String) -> Color {
        if eventType.contains("LOST") || eventType.contains("Failed") || eventType.contains("failed") {
            return .red
        } else if eventType.contains("RECOVERED") || eventType.contains("recovered") {
            return .orange
        } else if eventType.contains("Completed") || eventType.contains("completed") {
            return .green
        } else {
            return .blue
        }
    }
}

struct SyncStatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        SyncDiagnosticView(
            store: StoreOf<SyncDiagnosticFeature>.init(initialState: SyncDiagnosticFeature.State()) {
                SyncDiagnosticFeature()
            }
        )
    }
}
