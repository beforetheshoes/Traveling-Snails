//
//  Organization+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Organization: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []
        
        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "Name", optionalValue: name, defaultValue: "Unnamed"),
                DetailRowData(label: "ID", value: id.uuidString),
                DetailRowData(label: "Is System Organization", boolValue: isNone)
            ]
        ))
        
        // Contact Information
        sections.append(DetailSection(
            title: "Contact Information",
            rows: [
                DetailRowData(label: "Phone", optionalValue: phone, defaultValue: "Not provided"),
                DetailRowData(label: "Email", optionalValue: email, defaultValue: "Not provided"),
                DetailRowData(label: "Website", optionalValue: website, defaultValue: "Not provided"),
                DetailRowData(label: "Logo URL", optionalValue: logoURL, defaultValue: "Not provided")
            ]
        ))
        
        // Address (conditional)
        if let address = address, !address.isEmpty {
            var addressRows = [DetailRowData(label: "Address", value: address.displayAddress)]
            if let coordinate = address.coordinate {
                addressRows.append(DetailRowData(label: "Coordinates", value: "\(coordinate.latitude), \(coordinate.longitude)"))
            }
            sections.append(DetailSection(title: "Address", rows: addressRows))
        }
        
        // Usage Statistics
        let total = transportation.count + lodging.count + activity.count
        sections.append(DetailSection(
            title: "Usage Statistics",
            rows: [
                DetailRowData(label: "Transportation", value: "\(transportation.count)"),
                DetailRowData(label: "Lodging", value: "\(lodging.count)"),
                DetailRowData(label: "Activities", value: "\(activity.count)"),
                DetailRowData(label: "Total Usage", value: "\(total)")
            ]
        ))
        
        return sections
    }
}
