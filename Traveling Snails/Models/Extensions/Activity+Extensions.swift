//
//  Activity+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Activity: TripActivityProtocol {
    var confirmationField: String {
        get { reservation }
        set { reservation = newValue }
    }
    
    var confirmationLabel: String { "Reservation" }
    var supportsCustomLocation: Bool { true }
    var activityType: ActivityWrapper.ActivityType { .activity }
    var icon: String { "ticket.fill" }
    var color: Color { .purple }
    var scheduleTitle: String { "Schedule" }
    var startLabel: String { "Start" }
    var endLabel: String { "End" }
    var hasTypeSelector: Bool { false }
    
    // File attachment support - already declared in main model
    var supportsFileAttachments: Bool { true }

    var customAddress: Address? {
        get { customAddresss }
        set { customAddresss = newValue }
    }
    
    var transportationType: TransportationType? {
        get { nil }
        set { } // No-op for activity
    }
    
    func duration() -> TimeInterval {
        end.timeIntervalSince(start)
    }
    
    func copyForEditing() -> TripActivityEditData {
        TripActivityEditData(from: self)
    }
    
    func applyEdits(from data: TripActivityEditData) {
        #if DEBUG
        Logger.shared.debug("Activity.applyEdits called - cost field updated")
        #endif
        
        name = data.name
        start = data.start
        end = data.end
        startTZId = data.startTZId
        endTZId = data.endTZId
        cost = data.cost  // FIX: Ensure cost is set
        paid = data.paid
        reservation = data.confirmationField
        notes = data.notes
        organization = data.organization ?? organization
        customLocationName = data.customLocationName
        customAddresss = data.customAddress
        hideLocation = data.hideLocation
        
        #if DEBUG
        Logger.shared.debug("Activity cost field updated successfully")
        #endif
    }
}

extension Activity: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []
        
        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "Name", optionalValue: name, defaultValue: "Unnamed"),
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
                DetailRowData(label: "Start", value: startFormatted),
                DetailRowData(label: "Start Timezone", value: startTZId),
                DetailRowData(label: "End", value: endFormatted),
                DetailRowData(label: "End Timezone", value: endTZId),
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
        
        // Custom Location (conditional)
        if !customLocationName.isEmpty || customAddresss != nil {
            var locationRows: [DetailRowData] = []
            if !customLocationName.isEmpty {
                locationRows.append(DetailRowData(label: "Location Name", value: customLocationName))
            }
            if let address = customAddresss {
                locationRows.append(DetailRowData(label: "Custom Address", value: address.displayAddress))
            }
            locationRows.append(DetailRowData(label: "Hide Location", boolValue: hideLocation))
            
            sections.append(DetailSection(title: "Custom Location", rows: locationRows))
        }
        
        // Reservation (conditional)
        if !reservation.isEmpty {
            sections.append(DetailSection(
                title: "Reservation",
                rows: [DetailRowData(label: "Reservation Number", value: reservation)]
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
