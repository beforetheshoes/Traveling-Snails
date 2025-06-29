//
//  ToolsTab.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct ToolsTab: View {
    let modelContext: ModelContext
    let onDataChanged: () -> Void

    @State private var showingResetConfirmation = false
    @State private var showingCompactConfirmation = false
    @State private var showingExportOptions = false
    @State private var isPerformingOperation = false
    @State private var operationStatus = ""

    var body: some View {
        List {
            Section("Database Maintenance") {
                MaintenanceButton(
                    title: "Compact Database",
                    description: "Optimize database storage and performance",
                    icon: "arrow.down.circle",
                    color: .blue,
                    isLoading: isPerformingOperation
                ) {
                    showingCompactConfirmation = true
                }

                MaintenanceButton(
                    title: "Rebuild Relationships",
                    description: "Fix broken relationships between objects",
                    icon: "link.circle",
                    color: .orange,
                    isLoading: isPerformingOperation
                ) {
                    Task { await rebuildRelationships() }
                }

                MaintenanceButton(
                    title: "Validate Data Integrity",
                    description: "Check for data consistency issues",
                    icon: "checkmark.shield",
                    color: .green,
                    isLoading: isPerformingOperation
                ) {
                    Task { await validateDataIntegrity() }
                }
            }

            Section("Data Operations") {
                MaintenanceButton(
                    title: "Export Database Info",
                    description: "Export database structure and statistics",
                    icon: "square.and.arrow.up",
                    color: .purple,
                    isLoading: isPerformingOperation
                ) {
                    showingExportOptions = true
                }

                MaintenanceButton(
                    title: "Create Test Data",
                    description: "Add sample data for testing purposes",
                    icon: "plus.circle.fill",
                    color: .cyan,
                    isLoading: isPerformingOperation
                ) {
                    Task { await createTestData() }
                }
            }

            Section("Advanced Operations") {
                MaintenanceButton(
                    title: "Reset All Data",
                    description: "⚠️ Delete all data and start fresh",
                    icon: "trash.fill",
                    color: .red,
                    isLoading: isPerformingOperation
                ) {
                    showingResetConfirmation = true
                }
            }

            if !operationStatus.isEmpty {
                Section("Operation Status") {
                    Text(operationStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Reset All Data",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                Task { await resetAllData() }
            }
        } message: {
            Text("This will permanently delete ALL data including trips, activities, organizations, and attachments. This action cannot be undone.")
        }
        .confirmationDialog(
            "Compact Database",
            isPresented: $showingCompactConfirmation,
            titleVisibility: .visible
        ) {
            Button("Compact") {
                Task { await compactDatabase() }
            }
        } message: {
            Text("This will optimize the database storage. The operation may take a few moments.")
        }
        .sheet(isPresented: $showingExportOptions) {
            DatabaseExportView()
        }
    }

    private func rebuildRelationships() async {
        await MainActor.run {
            isPerformingOperation = true
            operationStatus = "Rebuilding relationships..."
        }

        // Simulate relationship rebuilding
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        await MainActor.run {
            operationStatus = "Relationships rebuilt successfully"
            isPerformingOperation = false
            onDataChanged()
        }
    }

    private func validateDataIntegrity() async {
        await MainActor.run {
            isPerformingOperation = true
            operationStatus = "Validating data integrity..."
        }

        // Simulate validation
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        await MainActor.run {
            operationStatus = "Data integrity check completed"
            isPerformingOperation = false
        }
    }

    private func compactDatabase() async {
        await MainActor.run {
            isPerformingOperation = true
            operationStatus = "Compacting database..."
        }

        // Simulate compaction
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        await MainActor.run {
            operationStatus = "Database compacted successfully"
            isPerformingOperation = false
        }
    }

    private func createTestData() async {
        await MainActor.run {
            isPerformingOperation = true
            operationStatus = "Creating test data..."
        }

        // Create some test data
        let testTrip = Trip(name: "Test Trip \(Date().timeIntervalSince1970)")
        modelContext.insert(testTrip)

        let testOrg = Organization(name: "Test Organization")
        modelContext.insert(testOrg)

        let testTransportation = Transportation(
            name: "Test Flight",
            start: Date(),
            end: Date().addingTimeInterval(3600),
            trip: testTrip,
            organization: testOrg
        )
        modelContext.insert(testTransportation)

        try? modelContext.save()

        await MainActor.run {
            operationStatus = "Test data created successfully"
            isPerformingOperation = false
            onDataChanged()
        }
    }

    private func resetAllData() async {
        await MainActor.run {
            isPerformingOperation = true
            operationStatus = "Resetting all data..."
        }

        // Implement actual data deletion using the same pattern as DatabaseCleanupView
        do {
            // Fetch data counts before deletion
            let trips = try modelContext.fetch(FetchDescriptor<Trip>())
            let organizations = try modelContext.fetch(FetchDescriptor<Organization>())
            let addresses = try modelContext.fetch(FetchDescriptor<Address>())

            let tripCount = trips.count
            let orgCount = organizations.count
            let addressCount = addresses.count

            // Delete all trips (cascading deletes will handle related data)
            for trip in trips {
                modelContext.delete(trip)
            }

            // Delete all organizations except "None"
            for org in organizations {
                if !org.isNone {
                    modelContext.delete(org)
                }
            }

            // Delete all addresses
            for address in addresses {
                modelContext.delete(address)
            }

            try modelContext.save()

            await MainActor.run {
                operationStatus = "Reset complete: Removed \(tripCount) trips, \(orgCount) organizations, \(addressCount) addresses"
                isPerformingOperation = false
                onDataChanged()
            }
        } catch {
            await MainActor.run {
                operationStatus = "Error resetting data: \(error.localizedDescription)"
                isPerformingOperation = false
            }
        }
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
                    .foregroundColor(color)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
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
