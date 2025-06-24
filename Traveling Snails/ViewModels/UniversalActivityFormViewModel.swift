//
//  UniversalActivityFormViewModel.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import Observation

@Observable
class UniversalActivityFormViewModel {
    // MARK: - Properties
    
    let trip: Trip
    private let activitySaver: ActivitySaver
    private let modelContext: ModelContext
    
    // Form state
    var editData: TripActivityEditData
    var attachments: [EmbeddedFileAttachment] = []
    var isSaving = false
    var showingOrganizationPicker = false
    var saveError: Error? = nil
    
    // MARK: - Initialization
    
    init(trip: Trip, activityType: ActivityType, modelContext: ModelContext) {
        self.trip = trip
        self.activitySaver = ActivitySaverFactory.createSaver(for: activityType)
        self.modelContext = modelContext
        
        // Create template and initialize edit data
        let template = activitySaver.createTemplate(in: trip)
        self.editData = TripActivityEditData(from: template)
        
        // Set default organization to None
        self.editData.organization = Organization.ensureUniqueNoneOrganization(in: modelContext)
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
    
    @MainActor
    func save() async throws {
        guard !isSaving, isFormValid else { return }
        
        isSaving = true
        saveError = nil
        
        do {
            try activitySaver.save(
                editData: editData,
                attachments: attachments,
                trip: trip,
                in: modelContext
            )
        } catch {
            saveError = error
            isSaving = false
            throw error
        }
        
        isSaving = false
    }
    
    func resetForm() {
        let template = activitySaver.createTemplate(in: trip)
        editData = TripActivityEditData(from: template)
        attachments.removeAll()
        saveError = nil
        editData.organization = Organization.ensureUniqueNoneOrganization(in: modelContext)
    }
}
