//
//  SyncDiagnosticView.swift
//  Traveling Snails
//
//

import Dependencies
import ComposableArchitecture
import SwiftUI

struct SyncDiagnosticView: View {
    @Bindable var store: StoreOf<SyncDiagnosticFeature>

    var body: some View {
        Form {
            Section(header: Text("Sync Status")) {
                SyncStatusRow(title: "Status", value: store.status.isSyncing ? "Syncing..." : "Idle")
                    .foregroundStyle(store.status.isSyncing ? .blue : .primary)

                SyncStatusRow(title: "Last Sync", value: lastSyncFormatted)

                SyncStatusRow(title: "Network Status", value: networkStatusText)
                    .foregroundStyle(networkStatusColor)

                SyncStatusRow(title: "Pending Changes", value: "\(store.status.pendingChangesCount)")

                if store.status.hasSyncError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(L(L10n.Errors.unknown))
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Manual Controls")) {
                Button {
                    store.send(.triggerSyncTapped)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Trigger Sync Now")
                    }
                }
                .disabled(store.status.isSyncing || store.status.networkStatus == .offline || store.isRefreshing)

                Button {
                    store.send(.triggerSyncWithRetryTapped)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Sync with Retry Logic")
                    }
                }
                .disabled(store.status.isSyncing || store.status.networkStatus == .offline || store.isRefreshing)

                Button {
                    store.send(.refreshTapped)
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(store.isRefreshing ? "Refreshing..." : "Refresh Diagnostics")
                    }
                }
                .disabled(store.isRefreshing)
            }

            Section(header: Text("Advanced Metrics")) {
                Button {
                    store.send(.advancedMetricsToggled)
                } label: {
                    HStack {
                        Text("Advanced Metrics")
                        Spacer()
                        Image(systemName: store.showingAdvancedMetrics ? "chevron.down" : "chevron.right")
                    }
                }

                if store.showingAdvancedMetrics {
                    AdvancedMetricsView(
                        syncProtectedTrips: store.status.syncProtectedTrips,
                        recordCounts: store.recordCounts,
                        isLoadingCounts: store.isLoadingRecordCounts
                    )
                }
            }

            Section(header: Text("Protected Trip Sync")) {
                Toggle(isOn: Binding(
                    get: { store.status.syncProtectedTrips },
                    set: { newValue in
                        store.send(.syncProtectedTripsChanged(newValue))
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Sync Protected Trips")
                            .font(.headline)
                        Text("Include biometrically protected trips in sync operations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(header: Text("Diagnostic Actions")) {
                Button("Test Offline Scenario") {
                    store.send(.testOfflineTapped)
                }
                .foregroundStyle(.orange)

                Button("Test Online Scenario") {
                    store.send(.testOnlineTapped)
                }
                .foregroundStyle(.green)

                Button("Simulate Network Error") {
                    store.send(.simulateNetworkErrorTapped)
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Sync Diagnostics")
        .inlineNavigationBarTitle()
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var lastSyncFormatted: String {
        guard let lastSync = store.status.lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }

    private var networkStatusText: String {
        switch store.status.networkStatus {
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }

    private var networkStatusColor: Color {
        switch store.status.networkStatus {
        case .online: return .green
        case .offline: return .red
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

struct AdvancedMetricsView: View {
    let syncProtectedTrips: Bool
    let recordCounts: [String: Int]
    let isLoadingCounts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingCounts {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading record counts...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(recordCounts.sorted { $0.key < $1.key }, id: \.key) { entity, count in
                    HStack {
                        Text(entity)
                            .font(.caption)
                        Spacer()
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Sync Performance")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack {
                    Text("Protected Trip Sync")
                        .font(.caption2)
                    Spacer()
                    Text(syncProtectedTrips ? "Enabled" : "Disabled")
                        .font(.caption2)
                        .foregroundStyle(syncProtectedTrips ? .green : .orange)
                }

                HStack {
                    Text("Retry Attempts")
                        .font(.caption2)
                    Spacer()
                    Text("Max 3")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
