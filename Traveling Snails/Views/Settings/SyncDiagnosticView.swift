//
//  SyncDiagnosticView.swift
//  Traveling Snails
//
//

import SwiftUI

struct SyncDiagnosticView: View {
    @Environment(SyncManager.self) private var syncManager
    @State private var showingAdvancedMetrics = false
    @State private var refreshTrigger = false

    var body: some View {
        Form {
            // Sync Status Section
            Section(header: Text("Sync Status")) {
                SyncStatusRow(title: "Status", value: syncManager.isSyncing ? "Syncing..." : "Idle")
                    .foregroundColor(syncManager.isSyncing ? .blue : .primary)

                SyncStatusRow(title: "Last Sync", value: lastSyncFormatted)

                SyncStatusRow(title: "Network Status", value: networkStatusText)
                    .foregroundColor(networkStatusColor)

                SyncStatusRow(title: "Pending Changes", value: "\(syncManager.pendingChangesCount)")

                if let error = syncManager.syncError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Manual Sync Controls
            Section(header: Text("Manual Controls")) {
                Button(action: triggerManualSync) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Trigger Sync Now")
                    }
                }
                .disabled(syncManager.isSyncing || syncManager.networkStatus == .offline)

                Button(action: triggerSyncWithRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle")
                        Text("Sync with Retry Logic")
                    }
                }
                .disabled(syncManager.isSyncing || syncManager.networkStatus == .offline)

                Button(action: { refreshTrigger.toggle() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Diagnostics")
                    }
                }
            }

            // Advanced Metrics Section
            Section(header: Text("Advanced Metrics")) {
                Button(action: { showingAdvancedMetrics.toggle() }) {
                    HStack {
                        Text("Advanced Metrics")
                        Spacer()
                        Image(systemName: showingAdvancedMetrics ? "chevron.down" : "chevron.right")
                    }
                }

                if showingAdvancedMetrics {
                    AdvancedMetricsView(syncManager: syncManager)
                }
            }

            // Protected Trip Settings
            Section(header: Text("Protected Trip Sync")) {
                Toggle(isOn: Binding(
                    get: { syncManager.syncProtectedTrips },
                    set: { syncManager.setSyncProtectedTrips($0) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Sync Protected Trips")
                            .font(.headline)
                        Text("Include biometrically protected trips in sync operations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Diagnostic Actions
            Section(header: Text("Diagnostic Actions")) {
                Button("Test Offline Scenario") {
                    syncManager.setNetworkStatus(.offline)
                }
                .foregroundColor(.orange)

                Button("Test Online Scenario") {
                    syncManager.setNetworkStatus(.online)
                }
                .foregroundColor(.green)

                Button("Simulate Network Error") {
                    Task {
                        await syncManager.simulateNetworkError()
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Sync Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTrigger) // Forces view refresh when refreshTrigger changes
    }

    // MARK: - Computed Properties

    private var lastSyncFormatted: String {
        guard let lastSync = syncManager.lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }

    private var networkStatusText: String {
        switch syncManager.networkStatus {
        case .online: return "Online"
        case .offline: return "Offline"
        }
    }

    private var networkStatusColor: Color {
        switch syncManager.networkStatus {
        case .online: return .green
        case .offline: return .red
        }
    }

    // MARK: - Actions

    private func triggerManualSync() {
        syncManager.triggerSync()
    }

    private func triggerSyncWithRetry() {
        Task {
            await syncManager.triggerSyncWithRetry()
        }
    }
}

// MARK: - Supporting Views

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
    let syncManager: SyncManager
    @State private var recordCounts: [String: Int] = [:]
    @State private var isLoadingCounts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingCounts {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading record counts...")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    Text(syncManager.syncProtectedTrips ? "Enabled" : "Disabled")
                        .font(.caption2)
                        .foregroundColor(syncManager.syncProtectedTrips ? .green : .orange)
                }

                HStack {
                    Text("Retry Attempts")
                        .font(.caption2)
                    Spacer()
                    Text("Max 3")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            loadRecordCounts()
        }
    }

    private func loadRecordCounts() {
        isLoadingCounts = true
        Task {
            // Simulate loading record counts
            try? await Task.sleep(for: .milliseconds(500))

            await MainActor.run {
                recordCounts = [
                    "Trips": Int.random(in: 5...50),
                    "Activities": Int.random(in: 10...100),
                    "Transportation": Int.random(in: 5...30),
                    "Lodging": Int.random(in: 3...20),
                    "Organizations": Int.random(in: 8...40),
                    "Addresses": Int.random(in: 5...25),
                ]
                isLoadingCounts = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SyncDiagnosticView()
            .environment(SyncManager.shared)
    }
}
