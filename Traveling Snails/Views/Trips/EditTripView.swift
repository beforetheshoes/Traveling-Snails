//
//  EditTripView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct EditTripView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<EditTripFeature>

    init(store: StoreOf<EditTripFeature>) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = self.store

        Form {
            tripDetailsSection
            tripDatesSection
            tripSummarySection
        }
        .accessibilityIdentifier("EditTripForm")
        .navigationTitle("Edit Trip")
        .onAppear { store.send(.onAppear) }
        .toolbar(content: toolbarContent)
        .overlay(alignment: .top, content: statusOverlay)
        .safeAreaInset(edge: .bottom, content: deleteButtonArea)
        .confirmationDialog(
            "Are you sure you want to delete this trip? This will also delete all lodging, transportation, and activities. This action cannot be undone.",
            isPresented: $store.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Date Range Warning", isPresented: $store.showDateRangeWarning) {
            Button("Save Anyway") {
                store.send(.confirmSaveDespiteDateConflict)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(store.dateRangeWarningMessage)
        }
        .alert("Error", isPresented: $store.showErrorAlert) {
            Button("OK") {
                store.send(.dismissErrorAlert)
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
    }

    private var tripDetailsSection: some View {
        Section("Trip Details") {
            TextField("Name", text: $store.name)
                .accessibilityIdentifier("TripNameField")
                .accessibilityLabel("Trip name")
                .accessibilityHint("Enter the name for your trip")
            TextField("Notes", text: $store.notes, axis: .vertical)
                .accessibilityIdentifier("TripNotesField")
                .accessibilityLabel("Trip notes")
                .accessibilityHint("Enter notes and details about your trip")
        }
        .accessibilityIdentifier("TripDetailsSection")
    }

    private var tripDatesSection: some View {
        Section("Trip Dates") {
            Toggle("Set start date", isOn: $store.hasStartDate)
                .accessibilityIdentifier("StartDateToggle")
                .accessibilityLabel("Set start date")
                .accessibilityHint("Toggle to enable or disable trip start date")

            if store.hasStartDate {
                DatePicker("Start Date", selection: $store.startDate, displayedComponents: .date)
                    .accessibilityIdentifier("StartDatePicker")
                    .accessibilityLabel("Trip start date")
                    .accessibilityHint("Select the date when your trip begins")
                    .onChange(of: store.startDate) { _, newValue in
                        store.send(.startDateChanged(newValue))
                    }
            }

            Toggle("Set end date", isOn: $store.hasEndDate)
                .accessibilityIdentifier("EndDateToggle")
                .accessibilityLabel("Set end date")
                .accessibilityHint("Toggle to enable or disable trip end date")

            if store.hasEndDate {
                DatePicker("End Date", selection: $store.endDate, displayedComponents: .date)
                    .accessibilityIdentifier("EndDatePicker")
                    .accessibilityLabel("Trip end date")
                    .accessibilityHint("Select the date when your trip ends")
                    .onChange(of: store.endDate) { _, newValue in
                        store.send(.endDateChanged(newValue))
                    }
            }

            if (store.hasStartDate || store.hasEndDate) && store.trip.totalActivities > 0 {
                Text("Note: Changing trip dates may affect date picker ranges for existing activities.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("DateConflictWarning")
                    .accessibilityLabel("Date change warning")
                    .accessibilityValue("Changing trip dates may affect existing activities")
            }
        }
        .accessibilityIdentifier("TripDatesSection")
    }

    private var tripSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.trip.lodging.count) lodging")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(store.trip.lodging.count) lodging items")
                Text("\(store.trip.transportation.count) transportation")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(store.trip.transportation.count) transportation items")
                Text("\(store.trip.activity.count) activities")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(store.trip.activity.count) activities")
                Text("Total cost: \(store.trip.totalCost, format: .currency(code: "USD"))")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Total trip cost: \(store.trip.totalCost, format: .currency(code: "USD"))")
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("TripSummaryStats")
            .accessibilityLabel("Trip summary")
            .accessibilityValue("\(store.trip.lodging.count) lodging, \(store.trip.transportation.count) transportation, \(store.trip.activity.count) activities, total cost \(store.trip.totalCost, format: .currency(code: "USD"))")
        } header: {
            Text("Trip Summary")
        }
        .accessibilityIdentifier("TripSummarySection")
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .accessibilityIdentifier("CancelTripEditButton")
                .accessibilityLabel("Cancel")
                .accessibilityHint("Cancel editing and discard changes")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
                store.send(.saveTapped)
            }
            .disabled(store.saveDisabled)
            .accessibilityIdentifier("SaveTripButton")
            .accessibilityLabel(store.isSaving ? "Saving trip" : "Save trip")
            .accessibilityHint(store.isSaving ? "Trip is being saved" : "Save trip changes")
            .accessibilityAddTraits(store.isSaving ? [.updatesFrequently] : [])
        }
    }

    @ViewBuilder
    private func statusOverlay() -> some View {
        if store.isOffline {
            HStack {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.orange)
                    .accessibilityLabel(L(L10n.Errors.networkOfflineLabel))
                Text("Working offline")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
            .padding(.top, 8)
        } else if store.isSaving {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Saving...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .clipShape(.rect(cornerRadius: 8))
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func deleteButtonArea() -> some View {
        VStack(spacing: 8) {
            Button(role: .destructive) {
                store.send(.deleteTapped)
            } label: {
                Label("Delete Trip", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    @Previewable @State var trip = Trip(name: "Test Trip")
    NavigationStack {
        EditTripView(
            store: StoreOf<EditTripFeature>.init(initialState: EditTripFeature.State(trip: trip)) {
                EditTripFeature()
            }
        )
    }
}
