//
//  UnifiedTripActivityDetailView.swift
//  Traveling Snails
//
//

import SwiftUI

struct UnifiedTripActivityDetailView<T: TripActivityProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let activity: T

    @State private var isEditing = false
    @State private var editData = TripActivityEditData(from: Activity())
    @State private var showDeleteConfirmation = false
    @State private var showingOrganizationPicker = false
    @State private var showMap = false

    init(activity: T) {
        self.activity = activity
    }

    // Use @State for attachments since we need to mutate it
    @State private var attachments: [EmbeddedFileAttachment] = []

    private var displayAddress: Address? {
        if isEditing {
            return editData.customAddress ?? editData.organization?.address
        } else {
            return activity.displayAddress
        }
    }

    /// Dynamic icon that updates based on current transportation type selection in edit mode
    private var currentIcon: String {
        // In edit mode for transportation activities, use the selected transportation type icon
        if isEditing,
           case .transportation = activity.activityType,
           let transportationType = editData.transportationType {
            return transportationType.systemImage
        }
        // Otherwise, use the activity's default icon
        return activity.icon
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Basic Info Section (replaces headerSection)
                ActivityBasicInfoSection(
                    activity: activity,
                    editData: $editData,
                    isEditing: isEditing,
                    color: activity.color,
                    icon: currentIcon,
                    attachmentCount: attachments.count
                )

                // Location Section (if applicable)
                if !activity.supportsCustomLocation || (!editData.hideLocation || isEditing) {
                    ActivityLocationSection(
                        activity: activity,
                        editData: $editData,
                        isEditing: isEditing,
                        color: activity.color,
                        supportsCustomLocation: activity.supportsCustomLocation,
                        showingOrganizationPicker: { showingOrganizationPicker = true },
                        showMap: { showMap = true }
                    )
                }

                // Schedule Section
                ActivityScheduleSection(
                    activity: activity,
                    editData: $editData,
                    isEditing: isEditing,
                    color: activity.color,
                    trip: activity.trip
                )

                // Cost & Payment Section
                ActivityCostSection(
                    activity: activity,
                    editData: $editData,
                    isEditing: isEditing,
                    color: activity.color
                )

                // Details Section
                ActivityDetailsSection(
                    activity: activity,
                    editData: $editData,
                    isEditing: isEditing,
                    color: activity.color,
                    supportsCustomLocation: activity.supportsCustomLocation
                )

                // File Attachments Section (always visible)
                ActivityAttachmentsSection(
                    attachments: $attachments,
                    isEditing: isEditing,
                    color: activity.color,
                    onAttachmentAdded: addAttachmentToActivity,
                    onAttachmentRemoved: removeAttachmentFromActivity
                )

                // Delete Button (only in edit mode)
                if isEditing {
                    deleteButton
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(isEditing ? "Edit \(activity.activityType.rawValue)" : "\(activity.activityType.rawValue) Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
        }
        .sheet(isPresented: $showingOrganizationPicker) {
            NavigationStack {
                OrganizationPicker(selectedOrganization: $editData.organization)
            }
        }
        .sheet(isPresented: $showMap) {
            if let address = displayAddress {
                NavigationStack {
                    AddressMapView(address: address)
                        .navigationTitle(activity.displayLocation)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showMap = false }
                            }
                        }
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this \(activity.activityType.rawValue.lowercased())?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        }
        .onAppear {
            // Initialize edit data and attachments from activity
            editData = TripActivityEditData(from: activity)
            attachments = activity.fileAttachments
        }
        // Smooth transition animations for edit mode
    }

    // MARK: - View Components (Replaced with Reusable Section Components)

    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete \(activity.activityType.rawValue)", systemImage: "trash.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.bottom)
    }

    // MARK: - Actions

    private func startEditing() {
        editData = TripActivityEditData(from: activity)
        attachments = activity.fileAttachments
        withAnimation {
            isEditing = true
        }
    }

    private func cancelEditing() {
        editData = TripActivityEditData(from: activity)
        attachments = activity.fileAttachments
        withAnimation {
            isEditing = false
        }
    }

    private func saveChanges() {
        #if DEBUG
        Logger.shared.debug("Activity edit data updated", category: .ui)
        #endif

        // Update the activity with the edit data
        updateActivityFromEditData()

        do {
            try modelContext.save()
            Logger.shared.info("Changes saved successfully")

            withAnimation {
                isEditing = false
            }
        } catch {
            Logger.shared.error("Failed to save changes in UnifiedTripActivityDetailView: \(error.localizedDescription)", category: .ui)
        }
    }

    private func updateActivityFromEditData() {
        switch activity.activityType {
        case .activity:
            if let activityItem = activity as? Activity {
                updateActivity(activityItem)
            }
        case .lodging:
            if let lodging = activity as? Lodging {
                updateLodging(lodging)
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                updateTransportation(transportation)
            }
        }
    }

    private func updateActivity(_ activityItem: Activity) {
        activityItem.name = editData.name
        activityItem.start = editData.start
        activityItem.end = editData.end
        activityItem.startTZId = editData.startTZId
        activityItem.endTZId = editData.endTZId
        activityItem.cost = editData.cost
        activityItem.paid = editData.paid
        activityItem.reservation = editData.confirmationField
        activityItem.notes = editData.notes
        activityItem.organization = editData.organization
        activityItem.customLocationName = editData.customLocationName
        activityItem.customAddresss = editData.customAddress
        activityItem.hideLocation = editData.hideLocation
        activityItem.fileAttachments = attachments
    }

    private func updateLodging(_ lodging: Lodging) {
        lodging.name = editData.name
        lodging.start = editData.start
        lodging.end = editData.end
        lodging.checkInTZId = editData.startTZId
        lodging.checkOutTZId = editData.endTZId
        lodging.cost = editData.cost
        lodging.paid = editData.paid
        lodging.reservation = editData.confirmationField
        lodging.notes = editData.notes
        lodging.organization = editData.organization
        lodging.customLocationName = editData.customLocationName
        lodging.customAddresss = editData.customAddress
        lodging.hideLocation = editData.hideLocation
        lodging.fileAttachments = attachments
    }

    private func updateTransportation(_ transportation: Transportation) {
        transportation.name = editData.name
        transportation.start = editData.start
        transportation.end = editData.end
        transportation.startTZId = editData.startTZId
        transportation.endTZId = editData.endTZId
        transportation.cost = editData.cost
        transportation.paid = editData.paid
        transportation.confirmation = editData.confirmationField
        transportation.notes = editData.notes
        transportation.organization = editData.organization
        transportation.type = editData.transportationType ?? .plane
        transportation.fileAttachments = attachments
    }

    private func deleteActivity() {
        // Type-safe deletion based on activity type
        switch activity.activityType {
        case .activity:
            if let activityItem = activity as? Activity {
                modelContext.delete(activityItem)
            }
        case .lodging:
            if let lodging = activity as? Lodging {
                modelContext.delete(lodging)
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                modelContext.delete(transportation)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            Logger.shared.error("Failed to delete activity", category: .database)
        }
    }

    // MARK: - Helper Methods

    private func formatDateInTimezone(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    // MARK: - File Attachment Management

    private func addAttachmentToActivity(_ attachment: EmbeddedFileAttachment) {
        switch activity.activityType {
        case .activity:
            if let activityItem = activity as? Activity {
                attachment.activity = activityItem
                activityItem.fileAttachments.append(attachment)
            }
        case .lodging:
            if let lodging = activity as? Lodging {
                attachment.lodging = lodging
                lodging.fileAttachments.append(attachment)
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                attachment.transportation = transportation
                transportation.fileAttachments.append(attachment)
            }
        }

        attachments.append(attachment)

        do {
            try modelContext.save()
        } catch {
            Logger.shared.error("Failed to save attachment relationship in UnifiedTripActivityDetailView: \(error.localizedDescription)", category: .database)
        }
    }

    private func removeAttachmentFromActivity(_ attachment: EmbeddedFileAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
}

// All old section implementations have been removed and replaced with reusable components
// This results in ~700+ lines of code reduction while maintaining all functionality
