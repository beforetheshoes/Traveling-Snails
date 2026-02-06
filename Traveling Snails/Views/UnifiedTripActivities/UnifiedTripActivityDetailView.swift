//
//  UnifiedTripActivityDetailView.swift
//  Traveling Snails
//
//

import Dependencies
import SQLiteData
import SwiftUI

struct UnifiedTripActivityDetailView<T: TripActivityProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.defaultDatabase) private var database
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
                    onAttachmentAdded: { attachment in
                        Task {
                            await addAttachmentToActivity(attachment)
                        }
                    },
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
                        Task {
                            await saveChanges()
                        }
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
                Task {
                    await deleteActivity()
                }
            }
        }
        .onAppear {
            // Initialize edit data and attachments from activity
            editData = TripActivityEditData(from: activity)
            refreshAttachments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importCompleted)) { _ in
            // Refresh attachments when import completes to show newly imported files
            refreshAttachments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileAttachmentAdded)) { _ in
            // Refresh attachments when new files are added
            refreshAttachments()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileAttachmentRemoved)) { _ in
            // Refresh attachments when files are removed
            refreshAttachments()
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
        refreshAttachments()
        withAnimation {
            isEditing = true
        }
    }

    private func cancelEditing() {
        editData = TripActivityEditData(from: activity)
        refreshAttachments()
        withAnimation {
            isEditing = false
        }
    }

    private func saveChanges() async {
        #if DEBUG
        Logger.shared.debug("Activity edit data updated", category: .ui)
        #endif

        do {
            try await persistActivityChanges()
            Logger.shared.info("Changes saved successfully")

            withAnimation {
                isEditing = false
            }
        } catch {
            Logger.shared.error("Failed to save changes in UnifiedTripActivityDetailView: \(error.localizedDescription)", category: .ui)
        }
    }

    private func persistActivityChanges() async throws {
        switch activity.activityType {
        case .activity:
            guard var activityItem = activity as? Activity else { return }
            updateActivity(&activityItem)
            let activityToSave = activityItem
            let attachmentsToSave = attachments
            try await database.write { db in
                try Activity.upsert { activityToSave }.execute(db)
                try EmbeddedFileAttachment.where { $0.activityID.eq(activityToSave.id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in attachmentsToSave {
                        EmbeddedFileAttachment.Draft(
                            id: attachment.id,
                            fileName: attachment.fileName,
                            originalFileName: attachment.originalFileName,
                            fileSize: attachment.fileSize,
                            mimeType: attachment.mimeType,
                            fileExtension: attachment.fileExtension,
                            createdDate: attachment.createdDate,
                            fileDescription: attachment.fileDescription,
                            fileData: attachment.fileData,
                            activityID: activityToSave.id,
                            lodgingID: nil,
                            transportationID: nil
                        )
                    }
                }.execute(db)
            }
        case .lodging:
            guard var lodging = activity as? Lodging else { return }
            updateLodging(&lodging)
            let lodgingToSave = lodging
            let attachmentsToSave = attachments
            try await database.write { db in
                try Lodging.upsert { lodgingToSave }.execute(db)
                try EmbeddedFileAttachment.where { $0.lodgingID.eq(lodgingToSave.id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in attachmentsToSave {
                        EmbeddedFileAttachment.Draft(
                            id: attachment.id,
                            fileName: attachment.fileName,
                            originalFileName: attachment.originalFileName,
                            fileSize: attachment.fileSize,
                            mimeType: attachment.mimeType,
                            fileExtension: attachment.fileExtension,
                            createdDate: attachment.createdDate,
                            fileDescription: attachment.fileDescription,
                            fileData: attachment.fileData,
                            activityID: nil,
                            lodgingID: lodgingToSave.id,
                            transportationID: nil
                        )
                    }
                }.execute(db)
            }
        case .transportation:
            guard var transportation = activity as? Transportation else { return }
            updateTransportation(&transportation)
            let transportationToSave = transportation
            let attachmentsToSave = attachments
            try await database.write { db in
                try Transportation.upsert { transportationToSave }.execute(db)
                try EmbeddedFileAttachment.where { $0.transportationID.eq(transportationToSave.id) }.delete().execute(db)
                try EmbeddedFileAttachment.insert {
                    for attachment in attachmentsToSave {
                        EmbeddedFileAttachment.Draft(
                            id: attachment.id,
                            fileName: attachment.fileName,
                            originalFileName: attachment.originalFileName,
                            fileSize: attachment.fileSize,
                            mimeType: attachment.mimeType,
                            fileExtension: attachment.fileExtension,
                            createdDate: attachment.createdDate,
                            fileDescription: attachment.fileDescription,
                            fileData: attachment.fileData,
                            activityID: nil,
                            lodgingID: nil,
                            transportationID: transportationToSave.id
                        )
                    }
                }.execute(db)
            }
        }
    }

    private func updateActivity(_ activityItem: inout Activity) {
        activityItem.name = editData.name
        activityItem.start = editData.start
        activityItem.end = editData.end
        activityItem.startTZId = editData.startTZId
        activityItem.endTZId = editData.endTZId
        activityItem.cost = editData.cost
        activityItem.paid = editData.paid
        activityItem.reservation = editData.confirmationField
        activityItem.notes = editData.notes
        activityItem.organizationID = editData.organization?.id
        activityItem.customLocationName = editData.customLocationName
        activityItem.addressID = editData.customAddress?.id
        activityItem.hideLocation = editData.hideLocation
    }

    private func updateLodging(_ lodging: inout Lodging) {
        lodging.name = editData.name
        lodging.start = editData.start
        lodging.end = editData.end
        lodging.checkInTZId = editData.startTZId
        lodging.checkOutTZId = editData.endTZId
        lodging.cost = editData.cost
        lodging.paid = editData.paid
        lodging.reservation = editData.confirmationField
        lodging.notes = editData.notes
        lodging.organizationID = editData.organization?.id
        lodging.customLocationName = editData.customLocationName
        lodging.addressID = editData.customAddress?.id
        lodging.hideLocation = editData.hideLocation
    }

    private func updateTransportation(_ transportation: inout Transportation) {
        transportation.name = editData.name
        transportation.start = editData.start
        transportation.end = editData.end
        transportation.startTZId = editData.startTZId
        transportation.endTZId = editData.endTZId
        transportation.cost = editData.cost
        transportation.paid = editData.paid
        transportation.confirmation = editData.confirmationField
        transportation.notes = editData.notes
        transportation.organizationID = editData.organization?.id
        transportation.type = editData.transportationType ?? .plane
    }

    private func deleteActivity() async {
        // Type-safe deletion based on activity type
        let deleteTarget: (ActivityType, UUID)?
        switch activity.activityType {
        case .activity:
            if let id = (activity as? Activity)?.id {
                deleteTarget = (.activity, id)
            } else {
                deleteTarget = nil
            }
        case .lodging:
            if let id = (activity as? Lodging)?.id {
                deleteTarget = (.lodging, id)
            } else {
                deleteTarget = nil
            }
        case .transportation:
            if let id = (activity as? Transportation)?.id {
                deleteTarget = (.transportation, id)
            } else {
                deleteTarget = nil
            }
        }
        guard let deleteTarget else { return }

        do {
            try await database.write { db in
                switch deleteTarget.0 {
                case .activity:
                    try Activity.find(deleteTarget.1).delete().execute(db)
                case .lodging:
                    try Lodging.find(deleteTarget.1).delete().execute(db)
                case .transportation:
                    try Transportation.find(deleteTarget.1).delete().execute(db)
                }
            }
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

    /// Refreshes the attachments array from the activity's current fileAttachments
    /// This ensures the UI shows the latest attachment state after imports or other changes
    private func refreshAttachments() {
        attachments = activity.fileAttachments
    }

    private func addAttachmentToActivity(_ attachment: EmbeddedFileAttachment) async {
        do {
            var updated = attachment
            let activityType = activity.activityType
            switch activityType {
            case .activity:
                if let activityItem = activity as? Activity {
                    updated.activityID = activityItem.id
                    updated.lodgingID = nil
                    updated.transportationID = nil
                }
            case .lodging:
                if let lodging = activity as? Lodging {
                    updated.activityID = nil
                    updated.lodgingID = lodging.id
                    updated.transportationID = nil
                }
            case .transportation:
                if let transportation = activity as? Transportation {
                    updated.activityID = nil
                    updated.lodgingID = nil
                    updated.transportationID = transportation.id
                }
            }
            let attachmentToSave = updated

            try await database.write { db in
                try EmbeddedFileAttachment.upsert { attachmentToSave }.execute(db)
            }

            refreshAttachments()
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
