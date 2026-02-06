//
//  DatabaseCleanupView.swift
//  Traveling Snails
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct DatabaseCleanupView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database

    @FetchAll private var trips: [Trip]
    @FetchAll private var organizations: [Organization]
    @FetchAll private var addresses: [Address]

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
                        deletedOrganizations += 1
                    }
                }

                let tripIDsToDelete = trips.filter { trip in
                    let tripName = trip.name.lowercased()
                    let exactTestNames = ["unprotected trip", "protected trip"]
                    let isExactTestMatch = exactTestNames.contains(tripName)
                    let isPatternMatch = testTripPatterns.contains { pattern in
                        if pattern.contains("\\d+") {
                            return tripName.range(of: pattern, options: .regularExpression) != nil
                        } else {
                            return tripName.contains(pattern.lowercased())
                        }
                    }
                    return isExactTestMatch || isPatternMatch
                }.map(\.id)

                let orgIDsToDelete = organizations.filter { org in
                    let orgName = org.name.lowercased()
                    return testOrgPatterns.contains(where: { orgName.contains($0.lowercased()) }) && !org.isNone
                }.map(\.id)

                try await database.write { db in
                    if !tripIDsToDelete.isEmpty {
                        try Trip.where { $0.id.in(tripIDsToDelete) }.delete().execute(db)
                    }
                    if !orgIDsToDelete.isEmpty {
                        try Organization.where { $0.id.in(orgIDsToDelete) }.delete().execute(db)
                    }
                }

                await MainActor.run {
                    deleteResult = "Removed \(deletedTrips) test trips and \(deletedOrganizations) test organizations"
                    isDeleting = false
                }
            } catch {
                Logger.shared.error("Failed to remove test data: \(error.localizedDescription)", category: .database)
                await MainActor.run {
                    deleteResult = L(L10n.Database.Operations.cleanupFailed)
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

                let tripIDs = trips.map(\.id)
                let addressIDs = addresses.map(\.id)

                try await database.write { db in
                    if !tripIDs.isEmpty {
                        try Trip.where { $0.id.in(tripIDs) }.delete().execute(db)
                    }
                    try Organization.where { $0.name.neq("None") }.delete().execute(db)
                    if !addressIDs.isEmpty {
                        try Address.where { $0.id.in(addressIDs) }.delete().execute(db)
                    }
                }

                await MainActor.run {
                    deleteResult = "Reset complete: Removed \(tripCount) trips, \(orgCount) organizations, \(addressCount) addresses"
                    isDeleting = false
                }
            } catch {
                Logger.shared.error("Failed to reset data: \(error.localizedDescription)", category: .database)
                await MainActor.run {
                    deleteResult = L(L10n.Database.Operations.resetFailed)
                    isDeleting = false
                }
            }
        }
    }
}

#Preview {
    DatabaseCleanupView()
}
