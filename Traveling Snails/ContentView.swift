//
//  ContentView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

/// View shown while waiting for CloudKit sync
struct CloudKitSyncIndicatorView: View {
    @Binding var isVisible: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .repeating)

            VStack(spacing: 8) {
                Text("Syncing with iCloud")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Your trips and data are being synchronized from iCloud. This may take a moment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            ProgressView()
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Query-Based Navigation Wrappers

struct TripsNavigationView: View {
    let store: StoreOf<TripsFeature>
    @Binding var selectedTripID: Trip.ID?
    @Binding var tripPath: [TripRoute]
    let tripResetToken: Int
    let onClearTripSelection: () -> Void
    let onTripSelection: (Trip, Bool) -> Void

    var body: some View {
        let state = store.state
        TripsNavigationContainer(
            trips: state.trips,
            selectedTripID: $selectedTripID,
            tripPath: $tripPath,
            tripResetToken: tripResetToken,
            onClearTripSelection: onClearTripSelection,
            onTripSelection: onTripSelection
        )
    }
}

struct OrganizationsNavigationView: View {
    let store: StoreOf<OrganizationsFeature>
    @Binding var selectedOrganizationID: Organization.ID?
    let onOrganizationSelection: (Organization) -> Void
    let onOpenTrip: (Trip.ID) -> Void

    var body: some View {
        let state = store.state
        UnifiedNavigationView.organizations(
            organizations: state.organizations,
            selectedOrganizationID: $selectedOrganizationID,
            onOrganizationSelected: onOrganizationSelection,
            onOpenTrip: onOpenTrip
        )
    }
}
