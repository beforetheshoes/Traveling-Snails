//
//  Transportation+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Transportation: TripActivityProtocol {
    var confirmationField: String {
        get { confirmation }
        set { confirmation = newValue }
    }
    
    var confirmationLabel: String { "Confirmation" }
    var supportsCustomLocation: Bool { false }
    var activityType: ActivityWrapper.ActivityType { .transportation }
    var icon: String { type.systemImage }
    var color: Color { .blue }
    var scheduleTitle: String { "Schedule" }
    var startLabel: String { "Departure" }
    var endLabel: String { "Arrival" }
    var hasTypeSelector: Bool { true }
    
    // File attachment support - already declared in main model
    var supportsFileAttachments: Bool { true }

    var customLocationName: String {
        get { "" }
        set { } // No-op
    }
    
    var customAddress: Address? {
        get { nil }
        set { } // No-op
    }
    
    var hideLocation: Bool {
        get { false }
        set { } // No-op
    }
    
    var displayLocation: String {
        guard let organization = organization else { return "No organization specified" }
        return organization.name == "None" ? "No organization specified" : organization.name
    }
      
    var displayAddress: Address? {
        guard let organization = organization else { return nil }
        return organization.name == "None" ? nil : organization.address
    }
      
    var hasLocation: Bool {
        guard let organization = organization else { return false }
        return organization.name != "None" && organization.address?.isEmpty == false
    }
    
    var transportationType: TransportationType? {
        get { type }
        set { if let newValue = newValue { type = newValue } }
    }
    
    func duration() -> TimeInterval {
        end.timeIntervalSince(start)
    }
    
    func copyForEditing() -> TripActivityEditData {
        TripActivityEditData(from: self)
    }
    
    func applyEdits(from data: TripActivityEditData) {
        #if DEBUG
        Logger.shared.debug("Transportation.applyEdits called - Current cost: \(cost), New cost: \(data.cost)")
        #endif
        
        name = data.name
        start = data.start
        end = data.end
        startTZId = data.startTZId
        endTZId = data.endTZId
        cost = data.cost  // FIX: Ensure cost is set
        paid = data.paid
        confirmation = data.confirmationField
        notes = data.notes
        organization = data.organization ?? organization
        if let newType = data.transportationType {
            type = newType
        }
        
        #if DEBUG
        Logger.shared.debug("Transportation cost updated to: \(cost)")
        #endif
    }
}

extension Transportation: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []
        
        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "Name", optionalValue: name, defaultValue: "Unnamed"),
                DetailRowData(label: "Type", value: type.displayName),
                DetailRowData(label: "ID", value: id.uuidString),
                DetailRowData(label: "Cost", value: cost.formatted(.currency(code: "USD"))),
                DetailRowData(label: "Payment Status", value: paid.displayName)
            ]
        ))
        
        // Schedule
        let duration = self.duration()
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        sections.append(DetailSection(
            title: "Schedule",
            rows: [
                DetailRowData(label: "Departure", value: departureFormatted),
                DetailRowData(label: "Departure Timezone", value: startTZId),
                DetailRowData(label: "Arrival", value: arrivalFormatted),
                DetailRowData(label: "Arrival Timezone", value: endTZId),
                DetailRowData(label: "Duration", value: "\(hours)h \(minutes)m")
            ]
        ))
        
        // Relationships
        sections.append(DetailSection(
            title: "Relationships",
            rows: [
                DetailRowData(label: "Trip", optionalValue: trip?.name, defaultValue: "None (Orphaned)"),
                DetailRowData(label: "Organization", optionalValue: organization?.name, defaultValue: "None")
            ]
        ))
        
        // Confirmation (conditional)
        if !confirmation.isEmpty {
            sections.append(DetailSection(
                title: "Confirmation",
                rows: [DetailRowData(label: "Confirmation Number", value: confirmation)]
            ))
        }
        
        // Notes (conditional)
        if !notes.isEmpty {
            sections.append(DetailSection(title: "Notes", rows: [], textContent: notes))
        }
        
        // File Attachments
        sections.append(DetailSection(
            title: "File Attachments",
            rows: [
                DetailRowData(label: "Attachment Count", value: "\(attachmentCount)"),
                DetailRowData(label: "Has Attachments", boolValue: hasAttachments)
            ]
        ))
        
        return sections
    }
}
