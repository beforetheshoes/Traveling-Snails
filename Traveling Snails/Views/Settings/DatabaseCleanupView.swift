//
//  DatabaseCleanupView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

struct DatabaseCleanupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var trips: [Trip]
    @Query private var organizations: [Organization]
    @Query private var addresses: [Address]

    @State private var showingDeleteConfirmation = false
    @State private var showingTestDataConfirmation = false
    @State private var isDeleting = false
    @State private var deleteResult: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Database Statistics")
                            .font(.headline)

                        Label("\(trips.count) Trips", systemImage: "airplane")
                        Label("\(organizations.count) Organizations", systemImage: "building.2")
                        Label("\(addresses.count) Addresses", systemImage: "location")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Current Data")
                }

                Section {
                    Button("Remove Test Data") {
                        showingTestDataConfirmation = true
                    }
                    .foregroundColor(.orange)
                    .disabled(isDeleting)

                    Button("Reset All Data") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                    .disabled(isDeleting)
                } header: {
                    Text("Cleanup Options")
                } footer: {
                    Text("Remove Test Data removes trips and organizations with test-like names. Reset All Data removes everything.")
                }

                if !deleteResult.isEmpty {
                    Section {
                        Text(deleteResult)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Last Operation")
                    }
                }
            }
            .navigationTitle("Database Cleanup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Remove Test Data", isPresented: $showingTestDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    removeTestData()
                }
            } message: {
                Text("This will remove trips and organizations that appear to be test data. This action cannot be undone.")
            }
            .alert("Reset All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all trips, organizations, and related data. This action cannot be undone.")
            }
        }
    }

    private func removeTestData() {
        isDeleting = true
        deleteResult = ""

        Task {
            do {
                var deletedTrips = 0
                var deletedOrganizations = 0

                // Remove trips that look like test data (more conservative patterns)
                let testTripPatterns = [
                    "test trip", "debug", "sample", "demo", "example",
                    "Trip 0", "Trip 1", "Trip 2", "Trip 3", "Trip 4", "Trip 5",
                    "Performance Test", "Query Trip", "Infinite Recreation",
                    "Relationship Test", "Complex Trip", "Large Trip",
                    "Sync Test", "Pattern Test", "Environment Test",
                    "Activity \\d+", "Hotel \\d+", "Flight \\d+",
                ]

                for trip in trips {
                    let tripName = trip.name.lowercased()
                    // Check for exact matches for obvious test data
                    let exactTestNames = ["unprotected trip", "protected trip"]
                    let isExactTestMatch = exactTestNames.contains(tripName)

                    // Check for pattern matches
                    let isPatternMatch = testTripPatterns.contains { pattern in
                        if pattern.contains("\\d+") {
                            // Handle regex patterns
                            return tripName.range(of: pattern, options: .regularExpression) != nil
                        } else {
                            return tripName.contains(pattern.lowercased())
                        }
                    }

                    if isExactTestMatch || isPatternMatch {
                        modelContext.delete(trip)
                        deletedTrips += 1
                    }
                }

                // Remove organizations that look like test data
                let testOrgPatterns = [
                    "test", "debug", "sample", "demo", "example",
                    "Org 0", "Org 1", "Org 2", "Org 3", "Org 4", "Org 5",
                    "Performance", "Large Org", "Sync Test", "Hotel", "Airline",
                ]

                for org in organizations {
                    let orgName = org.name.lowercased()
                    if testOrgPatterns.contains(where: { orgName.contains($0.lowercased()) }) && !org.isNone {
                        modelContext.delete(org)
                        deletedOrganizations += 1
                    }
                }

                try modelContext.save()

                await MainActor.run {
                    deleteResult = "Removed \(deletedTrips) test trips and \(deletedOrganizations) test organizations"
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    deleteResult = "Error removing test data: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        }
    }

    private func resetAllData() {
        isDeleting = true
        deleteResult = ""

        Task {
            do {
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
                    deleteResult = "Reset complete: Removed \(tripCount) trips, \(orgCount) organizations, \(addressCount) addresses"
                    isDeleting = false
                }
            } catch {
                await MainActor.run {
                    deleteResult = "Error resetting data: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        }
    }
}

#Preview {
    DatabaseCleanupView()
        .modelContainer(for: [Trip.self, Organization.self, Address.self])
}
