//
//  Lodging+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Lodging: TripActivityProtocol {
    var confirmationField: String {
        get { reservation }
        set { reservation = newValue }
    }
    
    var confirmationLabel: String { "Reservation" }
    var supportsCustomLocation: Bool { true }
    var activityType: ActivityWrapper.ActivityType { .lodging }
    var icon: String { "bed.double.fill" }
    var color: Color { .indigo }
    var scheduleTitle: String { "Stay Details" }
    var startLabel: String { "Check-in" }
    var endLabel: String { "Check-out" }
    var hasTypeSelector: Bool { false }
    
    // File attachment support - already declared in main model
    var supportsFileAttachments: Bool { true }

    var customAddress: Address? {
        get { customAddresss }
        set { customAddresss = newValue }
    }
    
    var transportationType: TransportationType? {
        get { nil }
        set { } // No-op for lodging
    }
    
    func duration() -> TimeInterval {
        end.timeIntervalSince(start)
    }
    
    func copyForEditing() -> TripActivityEditData {
        TripActivityEditData(from: self)
    }
    
    func applyEdits(from data: TripActivityEditData) {
        #if DEBUG
        Logger.shared.debug("Lodging.applyEdits called - Current cost: \(cost), New cost: \(data.cost)")
        #endif
        
        name = data.name
        start = data.start
        end = data.end
        checkInTZId = data.startTZId
        checkOutTZId = data.endTZId
        cost = data.cost  // FIX: Ensure cost is set
        paid = data.paid
        reservation = data.confirmationField
        notes = data.notes
        organization = data.organization ?? organization
        customLocationName = data.customLocationName
        customAddresss = data.customAddress
        hideLocation = data.hideLocation
        
        #if DEBUG
        Logger.shared.debug("Lodging cost updated to: \(cost)")
        #endif
    }
}

extension Lodging: DetailDisplayable {
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
        
        // Stay Details
        let nights = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        var stayRows = [
            DetailRowData(label: "Check-in", value: checkInDateFormatted),
            DetailRowData(label: "Check-in Timezone", value: checkInTZId),
            DetailRowData(label: "Check-out", value: checkOutDateFormatted),
            DetailRowData(label: "Check-out Timezone", value: checkOutTZId),
            DetailRowData(label: "Nights", value: "\(nights)")
        ]
        
        if cost > 0 && nights > 0 {
            let perNight = cost / Decimal(nights)
            stayRows.append(DetailRowData(label: "Cost per Night", value: perNight.formatted(.currency(code: "USD"))))
        }
        
        sections.append(DetailSection(title: "Stay Details", rows: stayRows))
        
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
