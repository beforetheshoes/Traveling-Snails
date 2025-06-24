//
//  Address+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Address: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []
        
        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "ID", value: id.uuidString),
                DetailRowData(label: "Display Address", optionalValue: displayAddress, defaultValue: "Empty"),
                DetailRowData(label: "Formatted Address", optionalValue: formattedAddress, defaultValue: "Not set")
            ]
        ))
        
        // Address Components
        sections.append(DetailSection(
            title: "Address Components",
            rows: [
                DetailRowData(label: "Street", optionalValue: street, defaultValue: "Not set"),
                DetailRowData(label: "City", optionalValue: city, defaultValue: "Not set"),
                DetailRowData(label: "State", optionalValue: state, defaultValue: "Not set"),
                DetailRowData(label: "Country", optionalValue: country, defaultValue: "Not set"),
                DetailRowData(label: "Postal Code", optionalValue: postalCode, defaultValue: "Not set")
            ]
        ))
        
        // Coordinates
        sections.append(DetailSection(
            title: "Coordinates",
            rows: [
                DetailRowData(label: "Latitude", value: "\(latitude)"),
                DetailRowData(label: "Longitude", value: "\(longitude)"),
                DetailRowData(label: "Has Valid Coordinates", boolValue: coordinate != nil)
            ]
        ))
        
        // Usage
        let total = (organizations?.count ?? 0) + (activities?.count ?? 0) + (lodgings?.count ?? 0)
        sections.append(DetailSection(
            title: "Usage",
            rows: [
                DetailRowData(label: "Organizations", value: "\(organizations?.count ?? 0)"),
                DetailRowData(label: "Activities", value: "\(activities?.count ?? 0)"),
                DetailRowData(label: "Lodging", value: "\(lodgings?.count ?? 0)"),
                DetailRowData(label: "Total Usage", value: "\(total)")
            ]
        ))
        
        return sections
    }
}
