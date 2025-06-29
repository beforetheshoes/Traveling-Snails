//
//  EditTripView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI


struct EditTripView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.navigationRouter) private var navigationRouter
    @Environment(SyncManager.self) private var syncManager

    // Local state for editing
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 3600) // Default to 1 week later
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var didAppear = false
    @State private var showDeleteConfirmation = false
    @State private var showDateRangeWarning = false
    @State private var dateRangeWarningMessage = ""

    var body: some View {
        Form {
            Section("Trip Details") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Trip Dates") {
                Toggle("Set start date", isOn: $hasStartDate)

                if hasStartDate {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newValue in
                            // Ensure end date is after start date if both are set
                            if hasEndDate && endDate <= newValue {
                                endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                            }
                        }
                }

                Toggle("Set end date", isOn: $hasEndDate)

                if hasEndDate {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .onChange(of: endDate) { _, newValue in
                            // Ensure start date is before end date if both are set
                            if hasStartDate && startDate >= newValue {
                                startDate = Calendar.current.date(byAdding: .day, value: -1, to: newValue) ?? newValue
                            }
                        }
                }

                // Show warning if dates would conflict with existing activities
                if (hasStartDate || hasEndDate) && trip.totalActivities > 0 {
                    Text("Note: Changing trip dates may affect date picker ranges for existing activities.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trip.lodging.count) lodging")
                        .foregroundStyle(.secondary)
                    Text("\(trip.transportation.count) transportation")
                        .foregroundStyle(.secondary)
                    Text("\(trip.activity.count) activities")
                        .foregroundStyle(.secondary)
                    Text("Total cost: \(trip.totalCost, format: .currency(code: "USD"))")
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            } header: {
                Text("Trip Summary")
            }
        }
        .navigationTitle("Edit Trip")
        .onAppear {
            if !didAppear {
                name = trip.name
                notes = trip.notes

                hasStartDate = trip.hasStartDate
                if hasStartDate {
                    startDate = trip.startDate
                }

                hasEndDate = trip.hasEndDate
                if hasEndDate {
                    endDate = trip.endDate
                }

                didAppear = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    saveTrip()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Trip", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .confirmationDialog(
            "Are you sure you want to delete this trip? This will also delete all lodging, transportation, and activities. This action cannot be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteTrip()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Date Range Warning", isPresented: $showDateRangeWarning) {
            Button("Save Anyway") {
                performSave()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(dateRangeWarningMessage)
        }
    }

    func saveTrip() {
        // Check if new date range would conflict with existing activities
        if let conflictMessage = checkDateConflicts() {
            dateRangeWarningMessage = conflictMessage
            showDateRangeWarning = true
        } else {
            performSave()
        }
    }

    private func performSave() {
        trip.name = name
        trip.notes = notes

        if hasStartDate {
            trip.setStartDate(startDate)
        } else {
            trip.clearStartDate()
        }

        if hasEndDate {
            trip.setEndDate(endDate)
        } else {
            trip.clearEndDate()
        }

        dismiss()
    }

    private func checkDateConflicts() -> String? {
        guard trip.totalActivities > 0 else { return nil }

        // Get all activity dates and convert them to the local calendar day
        let calendar = Calendar.current
        var allActivityDates: [Date] = []

        // For each activity, convert the start/end times to local date components
        // This ensures we're comparing actual calendar days rather than timezone-specific moments
        for lodging in trip.lodging {
            let startDay = calendar.startOfDay(for: lodging.start)
            let endDay = calendar.startOfDay(for: lodging.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }

        for transportation in trip.transportation {
            let startDay = calendar.startOfDay(for: transportation.start)
            let endDay = calendar.startOfDay(for: transportation.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }

        for activity in trip.activity {
            let startDay = calendar.startOfDay(for: activity.start)
            let endDay = calendar.startOfDay(for: activity.end)
            allActivityDates.append(contentsOf: [startDay, endDay])
        }

        guard let earliestActivityDay = allActivityDates.min(),
              let latestActivityDay = allActivityDates.max() else { return nil }

        var conflicts: [String] = []

        // Convert trip dates to start of day for fair comparison
        let tripStartDay = hasStartDate ? calendar.startOfDay(for: startDate) : nil
        let tripEndDay = hasEndDate ? calendar.startOfDay(for: endDate) : nil

        if let tripStart = tripStartDay, tripStart > earliestActivityDay {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            conflicts.append("Trip start date (\(formatter.string(from: tripStart))) is after activities starting on \(formatter.string(from: earliestActivityDay))")
        }

        if let tripEnd = tripEndDay, tripEnd < latestActivityDay {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            conflicts.append("Trip end date (\(formatter.string(from: tripEnd))) is before activities ending on \(formatter.string(from: latestActivityDay))")
        }

        if !conflicts.isEmpty {
            return conflicts.joined(separator: ". ") + ". Activities outside the trip date range may not be selectable when editing."
        }

        return nil
    }

    func deleteTrip() {
        #if DEBUG
        Logger.shared.debug("EditTripView: Starting trip deletion for ID: \(trip.id)", category: .dataImport)
        #endif
        
        // Store trip ID for logging
        let tripId = trip.id

        // CRITICAL: Delete and save FIRST to ensure CloudKit sync happens
        modelContext.delete(trip)

        do {
            try modelContext.save()
            #if DEBUG
            Logger.shared.debug("EditTripView: Trip (ID: \(tripId)) deleted and saved successfully", category: .dataImport)
            #endif
            
            // CRITICAL: Wait a moment for the deletion to be committed before triggering sync
            Task {
                // Wait for the deletion to be fully processed
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // THEN trigger sync to ensure deletion propagates properly
                await MainActor.run {
                    syncManager.triggerSync()
                    #if DEBUG
                    Logger.shared.debug("EditTripView: Triggered explicit sync for trip deletion after delay", category: .sync)
                    #endif
                }

                // Additional wait for CloudKit to process the deletion
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 more seconds
                #if DEBUG
                Logger.shared.debug("EditTripView: CloudKit deletion processing delay completed for trip ID: \(tripId)", category: .sync)
                #endif
            }

            // ONLY AFTER successful save: trigger navigation (immediate)
            navigationRouter.navigate(.navigateToTripList)
            dismiss()
        } catch {
            Logger.shared.error("EditTripView: Failed to save after trip deletion: \(error.localizedDescription)", category: .dataImport)
            // If save failed, don't navigate - stay on the edit view
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Trip.self, configurations: config)
    let trip = Trip(name: "Test Trip")
    return NavigationStack {
        EditTripView(trip: trip)
    }
    .modelContainer(container)
}
