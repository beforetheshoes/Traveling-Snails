//
//  UniversalActivityFormViewModel.swift
//  Traveling Snails
//
//

import Foundation
import Observation
import SwiftData

@Observable
class UniversalActivityFormViewModel {
    // MARK: - Properties

    let trip: Trip
    private let activitySaver: ActivitySaver
    private let modelContext: ModelContext

    // Edit mode support
    private let existingActivity: (any TripActivityProtocol)?
    let isEditMode: Bool

    // Form state
    var editData: TripActivityEditData
    var attachments: [EmbeddedFileAttachment] = []
    var isSaving = false
    var showingOrganizationPicker = false
    var saveError: Error?

    // MARK: - Initialization

    /// Initialize for creating a new activity
    init(trip: Trip, activityType: ActivityType, modelContext: ModelContext) {
        self.trip = trip
        self.activitySaver = ActivitySaverFactory.createSaver(for: activityType)
        self.modelContext = modelContext
        self.existingActivity = nil
        self.isEditMode = false

        // Create template and initialize edit data
        let template = activitySaver.createTemplate(in: trip)
        self.editData = TripActivityEditData(from: template)

        // Set default organization to None
        self.editData.organization = Organization.ensureUniqueNoneOrganization(in: modelContext)
    }

    /// Initialize for editing an existing activity
    init<T: TripActivityProtocol>(existingActivity: T, modelContext: ModelContext) {
        self.trip = existingActivity.trip!
        self.existingActivity = existingActivity
        self.isEditMode = true
        self.modelContext = modelContext

        // Map from ActivityWrapper.ActivityType to ActivityType
        let serviceActivityType: ActivityType = {
            switch existingActivity.activityType {
            case .activity:
                return .activity
            case .lodging:
                return .lodging
            case .transportation:
                return .transportation
            }
        }()

        self.activitySaver = ActivitySaverFactory.createSaver(for: serviceActivityType)

        // Initialize edit data from existing activity
        self.editData = TripActivityEditData(from: existingActivity)

        // Initialize attachments from existing activity
        self.attachments = existingActivity.fileAttachments
    }

    // MARK: - Computed Properties

    var template: any TripActivityProtocol {
        activitySaver.createTemplate(in: trip)
    }

    var locationAddress: Address? {
        editData.customAddress ?? editData.organization?.address
    }

    var isFormValid: Bool {
        editData.organization != nil && !editData.name.isEmpty
    }

    // Activity configuration from saver
    var activityType: ActivityType { activitySaver.activityType }
    var icon: String { activitySaver.icon }
    var color: String { activitySaver.color }

    /// Dynamic icon that updates based on current transportation type selection
    var currentIcon: String {
        // For transportation activities, use the selected transportation type icon
        if case .transportation = activityType,
           let transportationType = editData.transportationType {
            return transportationType.systemImage
        }
        // For other activity types, use the default icon
        return icon
    }
    var startLabel: String { activitySaver.startLabel }
    var endLabel: String { activitySaver.endLabel }
    var confirmationLabel: String { activitySaver.confirmationLabel }
    var supportsCustomLocation: Bool { activitySaver.supportsCustomLocation }
    var hasTypeSelector: Bool { activitySaver.hasTypeSelector }

    // MARK: - Actions

    func addAttachment(_ attachment: EmbeddedFileAttachment) {
        attachments.append(attachment)
    }

    func removeAttachment(_ attachment: EmbeddedFileAttachment) {
        attachments.removeAll { $0.id == attachment.id }
        modelContext.delete(attachment)
        try? modelContext.save()
    }

    func handleAttachmentError(_ error: String) {
        // Store the error for UI display
        saveError = NSError(domain: "AttachmentError", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        Logger.shared.error("Attachment error: \(error)", category: .fileAttachment)
    }

    @MainActor
    func save() async throws {
        guard !isSaving, isFormValid else { return }

        isSaving = true
        saveError = nil

        do {
            if isEditMode {
                try updateExistingActivity()
            } else {
                try activitySaver.save(
                    editData: editData,
                    attachments: attachments,
                    trip: trip,
                    in: modelContext
                )
            }
        } catch {
            saveError = error
            isSaving = false
            throw error
        }

        isSaving = false
    }

    private func updateExistingActivity() throws {
        guard let existingActivity = existingActivity else {
            throw ActivitySaveError.saveFailed(NSError(domain: "UniversalActivityFormViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No existing activity to update"]))
        }

        // Update the existing activity with new data
        updateActivityProperties(existingActivity)

        // Update attachments
        updateActivityAttachments(existingActivity)

        // Save changes
        try modelContext.save()
    }

    private func updateActivityProperties(_ activity: any TripActivityProtocol) {
        // Update based on specific activity type
        switch activity.activityType {
        case .activity:
            if let activityInstance = activity as? Activity {
                updateActivity(activityInstance)
            }
        case .lodging:
            if let lodgingInstance = activity as? Lodging {
                updateLodging(lodgingInstance)
            }
        case .transportation:
            if let transportationInstance = activity as? Transportation {
                updateTransportation(transportationInstance)
            }
        }

        // Handle custom address insertion if needed
        if let customAddress = editData.customAddress {
            // Only insert if it's not already in the context
            if customAddress.modelContext == nil {
                modelContext.insert(customAddress)
            }
        }
    }

    private func updateActivity(_ activity: Activity) {
        activity.name = editData.name
        activity.start = editData.start
        activity.end = editData.end
        activity.startTZId = editData.startTZId
        activity.endTZId = editData.endTZId
        activity.cost = editData.cost
        activity.paid = editData.paid
        activity.reservation = editData.confirmationField
        activity.notes = editData.notes
        activity.organization = editData.organization
        activity.customLocationName = editData.customLocationName
        activity.customAddresss = editData.customAddress  // Note: typo in model property name
        activity.hideLocation = editData.hideLocation
    }

    private func updateLodging(_ lodging: Lodging) {
        lodging.name = editData.name
        lodging.start = editData.start
        lodging.end = editData.end
        lodging.checkInTZId = editData.startTZId
        lodging.checkOutTZId = editData.endTZId
        lodging.cost = editData.cost
        lodging.paid = editData.paid
        lodging.reservation = editData.confirmationField  // Lodging uses 'reservation'
        lodging.notes = editData.notes
        lodging.organization = editData.organization
        lodging.customLocationName = editData.customLocationName
        lodging.customAddresss = editData.customAddress  // Note: typo in model property name
        lodging.hideLocation = editData.hideLocation
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
    }

    private func updateActivityAttachments(_ activity: any TripActivityProtocol) {
        // Update file attachments based on activity type
        switch activity.activityType {
        case .activity:
            if let activityInstance = activity as? Activity {
                activityInstance.fileAttachments = attachments
                for attachment in attachments {
                    if attachment.modelContext == nil {
                        modelContext.insert(attachment)
                    }
                    attachment.activity = activityInstance
                }
            }
        case .lodging:
            if let lodgingInstance = activity as? Lodging {
                lodgingInstance.fileAttachments = attachments
                for attachment in attachments {
                    if attachment.modelContext == nil {
                        modelContext.insert(attachment)
                    }
                    attachment.lodging = lodgingInstance
                }
            }
        case .transportation:
            if let transportationInstance = activity as? Transportation {
                transportationInstance.fileAttachments = attachments
                for attachment in attachments {
                    if attachment.modelContext == nil {
                        modelContext.insert(attachment)
                    }
                    attachment.transportation = transportationInstance
                }
            }
        }
    }

    func resetForm() {
        let template = activitySaver.createTemplate(in: trip)
        editData = TripActivityEditData(from: template)
        attachments.removeAll()
        saveError = nil
        editData.organization = Organization.ensureUniqueNoneOrganization(in: modelContext)
    }
}
