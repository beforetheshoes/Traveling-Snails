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

    // Background context manager for save operations
    @State private var backgroundContextManager: BackgroundModelContextManager?

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
        editTripForm
    }

    private var tripDetailsSection: some View {
        Section("Trip Details") {
            TextField("Name", text: $name)
                .accessibilityIdentifier("TripNameField")
                .accessibilityLabel("Trip name")
                .accessibilityHint("Enter the name for your trip")
            TextField("Notes", text: $notes, axis: .vertical)
                .accessibilityIdentifier("TripNotesField")
                .accessibilityLabel("Trip notes")
                .accessibilityHint("Enter notes and details about your trip")
        }
        .accessibilityIdentifier("TripDetailsSection")
    }

    private var tripDatesSection: some View {
        Section("Trip Dates") {
            Toggle("Set start date", isOn: $hasStartDate)
                    .accessibilityIdentifier("StartDateToggle")
                    .accessibilityLabel("Set start date")
                    .accessibilityHint("Toggle to enable or disable trip start date")

                if hasStartDate {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .accessibilityIdentifier("StartDatePicker")
                        .accessibilityLabel("Trip start date")
                        .accessibilityHint("Select the date when your trip begins")
                        .onChange(of: startDate) { _, newValue in
                            // Ensure end date is after start date if both are set
                            if hasEndDate && endDate <= newValue {
                                endDate = Calendar.current.date(byAdding: .day, value: 1, to: newValue) ?? newValue
                            }
                        }
                }

                Toggle("Set end date", isOn: $hasEndDate)
                    .accessibilityIdentifier("EndDateToggle")
                    .accessibilityLabel("Set end date")
                    .accessibilityHint("Toggle to enable or disable trip end date")

                if hasEndDate {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                        .accessibilityIdentifier("EndDatePicker")
                        .accessibilityLabel("Trip end date")
                        .accessibilityHint("Select the date when your trip ends")
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
                    Text("\(trip.lodging.count) lodging")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(trip.lodging.count) lodging items")
                    Text("\(trip.transportation.count) transportation")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(trip.transportation.count) transportation items")
                    Text("\(trip.activity.count) activities")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(trip.activity.count) activities")
                    Text("Total cost: \(trip.totalCost, format: .currency(code: "USD"))")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Total trip cost: \(trip.totalCost, format: .currency(code: "USD"))")
                }
                .font(.caption)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("TripSummaryStats")
                .accessibilityLabel("Trip summary")
                .accessibilityValue("\(trip.lodging.count) lodging, \(trip.transportation.count) transportation, \(trip.activity.count) activities, total cost \(trip.totalCost, format: .currency(code: "USD"))")
        } header: {
            Text("Trip Summary")
        }
        .accessibilityIdentifier("TripSummarySection")
    }

    private var editTripForm: some View {
        Form {
            tripDetailsSection
            tripDatesSection
            tripSummarySection
        }
        .accessibilityIdentifier("EditTripForm")
        .navigationTitle("Edit Trip")
        .onAppear(perform: setupFormData)
        .toolbar(content: toolbarContent)
        .overlay(alignment: .top, content: statusOverlay)
        .safeAreaInset(edge: .bottom, content: deleteButtonArea)
        .confirmationDialog(
            "Are you sure you want to delete this trip? This will also delete all lodging, transportation, and activities. This action cannot be undone.",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible,
            actions: deleteConfirmationActions
        )
        .alert("Date Range Warning", isPresented: $showDateRangeWarning, actions: dateRangeWarningActions) {
            Text(dateRangeWarningMessage)
        }
        .alert("Error", isPresented: $showErrorAlert, actions: errorAlertActions) {
            if let errorState = errorState {
                Text(errorState.userMessage)
            }
        }
        .onAppear(perform: configureOperationQueue)
    }

    private func setupFormData() {
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
                saveTrip()
            }
            .disabled(isSaving)
            .accessibilityIdentifier("SaveTripButton")
            .accessibilityLabel(isSaving ? "Saving trip" : "Save trip")
            .accessibilityHint(isSaving ? "Trip is being saved" : "Save trip changes")
            .accessibilityAddTraits(isSaving ? [.updatesFrequently] : [])
        }
    }

    @ViewBuilder
    private func statusOverlay() -> some View {
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

    @ViewBuilder
    private func deleteButtonArea() -> some View {
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

    @ViewBuilder
    private func deleteConfirmationActions() -> some View {
        Button("Delete", role: .destructive) {
            deleteTrip()
        }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private func dateRangeWarningActions() -> some View {
        Button("Save Anyway") {
            performSave()
        }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private func errorAlertActions() -> some View {
        if let errorState = errorState {
            ForEach(errorState.suggestedActions, id: \.self) { action in
                Button(action.displayName) {
                    performAction(action)
                }
            }
        }
    }

    private func configureOperationQueue() {
        // Configure operation queue to prevent concurrent saves
        saveOperationQueue.maxConcurrentOperationCount = 1
        saveOperationQueue.qualityOfService = .userInitiated

        // Initialize background context manager for save operations
        backgroundContextManager = BackgroundModelContextManager(container: modelContext.container)

        // Monitor network status
        updateNetworkStatus()
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

        // Ensure background context manager is available
        guard let backgroundManager = backgroundContextManager else {
            // Fallback to main context save if background manager is not available
            #if DEBUG
            Logger.secure(category: .app).warning("EditTripView: Background context manager not available, using main context")
            #endif
            return await performMainContextSave()
        }

        // Capture values for background operation
        let tripId = trip.id
        let newName = name
        let newNotes = notes
        let newStartDate = hasStartDate ? startDate : nil
        let newEndDate = hasEndDate ? endDate : nil

        // Perform save operation in background context
        let saveResult = await backgroundManager.saveTripInBackground(tripId: tripId) { backgroundTrip in
            // Update trip properties in background context
            backgroundTrip.name = newName
            backgroundTrip.notes = newNotes

            if let startDate = newStartDate {
                backgroundTrip.setStartDate(startDate)
            } else {
                backgroundTrip.clearStartDate()
            }

            if let endDate = newEndDate {
                backgroundTrip.setEndDate(endDate)
            } else {
                backgroundTrip.clearEndDate()
            }
        }

        switch saveResult {
        case .success:
            #if DEBUG
            Logger.secure(category: .app).debug("EditTripView: Trip saved successfully using background context")
            #endif

            // Update local trip object on main thread to reflect changes
            await MainActor.run {
                trip.name = newName
                trip.notes = newNotes
                if let startDate = newStartDate {
                    trip.setStartDate(startDate)
                } else {
                    trip.clearStartDate()
                }
                if let endDate = newEndDate {
                    trip.setEndDate(endDate)
                } else {
                    trip.clearEndDate()
                }
            }

            // Trigger sync if network is available
            if syncManager.networkStatus == .online {
                syncManager.triggerSync()
            }

            return .success(())
        case .failure(let error):
            #if DEBUG
            Logger.secure(category: .app).error("EditTripView: Background save failed: \(error, privacy: .private)")
            #endif
            return .failure(error)
        }
    }

    /// Fallback method for saving using main context
    @MainActor
    private func performMainContextSave() async -> AppResult<Void> {
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
        let saveResult = modelContext.safeSave(context: "Trip save operation (main context fallback)")

        switch saveResult {
        case .success:
            #if DEBUG
            Logger.secure(category: .app).debug("EditTripView: Trip saved successfully using main context fallback")
            #endif

            // Trigger sync if network is available
            if syncManager.networkStatus == .online {
                syncManager.triggerSync()
            }

            return .success(())
        case .failure(let error):
            #if DEBUG
            Logger.secure(category: .app).error("EditTripView: Main context save failed: \(error, privacy: .private)")
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
        trip.optimizedCheckDateConflicts(
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
    @Previewable @State var trip = Trip(name: "Test Trip")
    NavigationStack {
        EditTripView(trip: trip)
    }
}
