//
//  EditTripView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI


struct EditTripView: View {
    @Bindable var trip: Trip
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.navigationRouter)
    private var navigationRouter
    @Environment(ModernSyncManager.self)
    private var syncManager

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

    // Enhanced error handling state
    @State private var errorState: TripEditErrorState?
    @State private var showErrorAlert = false
    @State private var isSaving = false
    @State private var saveRetryCount = 0
    @State private var isOffline = false

    // Operation queuing to prevent race conditions
    @State private var saveOperationQueue = OperationQueue()
    @State private var currentSaveTask: Task<Void, Never>?

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
                .disabled(isSaving)
            }
        }
        .overlay(alignment: .top) {
            // Network status indicator
            if isOffline {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(.orange)
                        .accessibilityLabel(L(L10n.Errors.networkOfflineLabel))
                    Text("Working offline")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 8)
            } else if isSaving {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Saving...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 8)
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
        .alert("Error", isPresented: $showErrorAlert) {
            if let errorState = errorState {
                ForEach(errorState.suggestedActions, id: \.self) { action in
                    Button(action.displayName) {
                        performAction(action)
                    }
                }
            }
        } message: {
            if let errorState = errorState {
                Text(errorState.userMessage)
            }
        }
        .onAppear {
            // Configure operation queue to prevent concurrent saves
            saveOperationQueue.maxConcurrentOperationCount = 1
            saveOperationQueue.qualityOfService = .userInitiated

            // Monitor network status
            updateNetworkStatus()
        }
        .onDisappear {
            // Cancel any pending save operations to prevent crashes
            currentSaveTask?.cancel()
            currentSaveTask = nil
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
        // Cancel any existing save operation to prevent race conditions
        currentSaveTask?.cancel()

        // Create new save task with proper queuing
        currentSaveTask = Task { @MainActor in
            // Ensure only one save operation runs at a time
            guard !isSaving else {
                #if DEBUG
                Logger.secure(category: .app).debug("EditTripView: Save operation already in progress, ignoring request")
                #endif
                return
            }

            await performSaveWithRetry()
        }
    }

    @MainActor
    private func performSaveWithRetry() async {
        isSaving = true
        errorState = nil

        let result = await performActualSave()

        switch result {
        case .success:
            // Save successful - dismiss view
            isSaving = false
            dismiss()
        case .failure(let error):
            isSaving = false
            await handleSaveError(error)
        }
    }

    @MainActor
    private func performActualSave() async -> AppResult<Void> {
        #if DEBUG
        Logger.secure(category: .app).debug("EditTripView: Starting save operation for trip: \(trip.id, privacy: .public)")
        #endif

        // Validate input first
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.missingRequiredField("Trip name"))
        }

        // Update trip properties
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

        // Attempt to save with error handling
        let saveResult = modelContext.safeSave(context: "Trip save operation")

        switch saveResult {
        case .success:
            #if DEBUG
            Logger.secure(category: .app).debug("EditTripView: Trip saved successfully")
            #endif

            // Trigger sync if network is available
            if syncManager.networkStatus == .online {
                syncManager.triggerSync()
            }

            return .success(())
        case .failure(let error):
            #if DEBUG
            Logger.secure(category: .app).error("EditTripView: Save failed: \(error, privacy: .private)")
            #endif
            return .failure(error)
        }
    }

    @MainActor
    private func handleSaveError(_ error: AppError) async {
        saveRetryCount += 1

        // Create error state based on error type and retry count
        let maxRetries = AppConfiguration.networkRetry.maxAttempts
        if error.isRecoverable && saveRetryCount < maxRetries {
            errorState = TripEditErrorState(
                error: error,
                retryCount: saveRetryCount,
                canRetry: true,
                userMessage: generateUserMessage(for: error),
                suggestedActions: generateSuggestedActions(for: error)
            )
        } else {
            errorState = TripEditErrorState(
                error: error,
                retryCount: saveRetryCount,
                canRetry: false,
                userMessage: generateUserMessage(for: error),
                suggestedActions: generateSuggestedActions(for: error)
            )
        }

        showErrorAlert = true

        // For network errors, check if we should attempt automatic retry
        let config = AppConfiguration.networkRetry
        if error.isRecoverable && saveRetryCount < config.maxAttempts {
            switch error {
            case .networkUnavailable, .timeoutError:
                // Automatic retry with configured delay
                let delay = config.delay(for: saveRetryCount)

                #if DEBUG
                Logger.secure(category: .app).debug("EditTripView: Scheduling automatic retry (\(saveRetryCount)/\(config.maxAttempts)) after \(delay)s delay")
                #endif

                // Cancel any existing save task before scheduling retry
                currentSaveTask?.cancel()

                // Schedule retry with proper queuing to prevent race conditions
                currentSaveTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    // Double-check we're still in a valid state for retry
                    guard !Task.isCancelled, !isSaving else {
                        #if DEBUG
                        Logger.secure(category: .app).debug("EditTripView: Automatic retry cancelled or save already in progress")
                        #endif
                        return
                    }

                    await performSaveWithRetry()
                }
            default:
                break
            }
        }
    }

    private func generateUserMessage(for error: AppError) -> String {
        switch error {
        case .networkUnavailable:
            return "No internet connection. Your changes are saved locally and will sync when connected."
        case .timeoutError:
            return "Save operation timed out. Please try again."
        case .databaseSaveFailed:
            return "Unable to save trip changes. Please try again."
        case .missingRequiredField(let field):
            return "Please enter a \(field.lowercased()) before saving."
        case .cloudKitQuotaExceeded:
            return "Your iCloud storage is full. Please free up space or upgrade your storage plan."
        default:
            return "An unexpected error occurred. Please try again."
        }
    }

    private func generateSuggestedActions(for error: AppError) -> [TripEditAction] {
        switch error {
        case .networkUnavailable:
            return [.workOffline, .retry, .cancel]
        case .timeoutError, .databaseSaveFailed:
            return [.retry, .saveAsDraft, .cancel]
        case .missingRequiredField:
            return [.fixInput, .cancel]
        case .cloudKitQuotaExceeded:
            return [.manageStorage, .upgradeStorage, .cancel]
        default:
            return [.retry, .cancel]
        }
    }

    private func performAction(_ action: TripEditAction) {
        switch action {
        case .retry:
            saveRetryCount = 0 // Reset retry count for manual retry
            performSave() // This already has race condition protection
        case .workOffline:
            // Continue working offline - save locally with race condition protection
            currentSaveTask?.cancel()
            currentSaveTask = Task { @MainActor in
                guard !isSaving else {
                    #if DEBUG
                    Logger.secure(category: .app).debug("EditTripView: Offline save already in progress, ignoring request")
                    #endif
                    return
                }

                let result = await performActualSave()
                if case .success = result {
                    dismiss()
                }
            }
        case .saveAsDraft:
            // Save as draft (just close without syncing)
            dismiss()
        case .fixInput:
            // Close error dialog to allow user to fix input
            showErrorAlert = false
            errorState = nil
        case .manageStorage:
            // Open Settings app to manage storage
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .upgradeStorage:
            // Open iCloud settings (best we can do on iOS)
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
        case .cancel:
            showErrorAlert = false
            errorState = nil
        }
    }

    private func updateNetworkStatus() {
        // Use the sync manager's network status
        isOffline = syncManager.networkStatus == .offline
    }

    private func checkDateConflicts() -> String? {
        // PERFORMANCE OPTIMIZATION: Use cached date range from Trip model
        // This replaces the O(n) computation with cached O(1) access for subsequent calls
        return trip.optimizedCheckDateConflicts(
            hasStartDate: hasStartDate, 
            startDate: startDate, 
            hasEndDate: hasEndDate, 
            endDate: endDate
        )
    }

    func deleteTrip() {
        #if DEBUG
        Logger.secure(category: .dataImport).debug("EditTripView: Starting trip deletion for ID: \(trip.id, privacy: .public)")
        #endif

        // Store trip ID for logging
        let tripId = trip.id

        // CRITICAL: Delete and save FIRST to ensure CloudKit sync happens
        modelContext.delete(trip)

        do {
            try modelContext.save()
            #if DEBUG
            Logger.secure(category: .dataImport).debug("EditTripView: Trip (ID: \(tripId, privacy: .public)) deleted and saved successfully")
            #endif

            // CRITICAL: Wait a moment for the deletion to be committed before triggering sync
            Task {
                // Wait for the deletion to be fully processed
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                // THEN trigger sync to ensure deletion propagates properly
                await MainActor.run {
                    syncManager.triggerSync()
                    #if DEBUG
                    Logger.secure(category: .sync).debug("EditTripView: Triggered explicit sync for trip deletion after delay")
                    #endif
                }

                // Additional wait for CloudKit to process the deletion
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 more seconds
                #if DEBUG
                Logger.secure(category: .sync).debug("EditTripView: CloudKit deletion processing delay completed for trip ID: \(tripId, privacy: .public)")
                #endif
            }

            // ONLY AFTER successful save: trigger navigation (immediate)
            navigationRouter.navigate(.navigateToTripList)
            dismiss()
        } catch {
            Logger.secure(category: .dataImport).error("EditTripView: Failed to save after trip deletion: \(error.localizedDescription, privacy: .public)")
            // If save failed, don't navigate - stay on the edit view
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, configurations: config)
        let trip = Trip(name: "Test Trip")
        return NavigationStack {
            EditTripView(trip: trip)
        }
        .modelContainer(container)
    } catch {
        return Text(L(L10n.Errors.unknown))
    }
}
