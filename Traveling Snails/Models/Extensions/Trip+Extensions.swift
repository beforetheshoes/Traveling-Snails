//
//  Trip+Extensions.swift
//  Traveling Snails
//
//

import SwiftUI

extension Trip: DetailDisplayable {
    var detailSections: [DetailSection] {
        var sections: [DetailSection] = []

        // Basic Information
        sections.append(DetailSection(
            title: "Basic Information",
            rows: [
                DetailRowData(label: "Name", optionalValue: name, defaultValue: "Unnamed"),
                DetailRowData(label: "ID", value: id.uuidString),
                DetailRowData(label: "Created", value: createdDate.formatted(date: .abbreviated, time: .shortened)),
                DetailRowData(label: "Total Cost", value: totalCost.formatted(.currency(code: "USD"))),
                DetailRowData(label: "Total Activities", value: "\(totalActivities)"),
            ]
        ))

        // Trip Dates (conditional)
        if hasStartDate || hasEndDate {
            var dateRows: [DetailRowData] = []
            dateRows.append(DetailRowData(label: "Has Start Date", boolValue: hasStartDate))
            if hasStartDate {
                dateRows.append(DetailRowData(label: "Start Date", value: startDate.formatted(date: .abbreviated, time: .omitted)))
            }
            dateRows.append(DetailRowData(label: "Has End Date", boolValue: hasEndDate))
            if hasEndDate {
                dateRows.append(DetailRowData(label: "End Date", value: endDate.formatted(date: .abbreviated, time: .omitted)))
            }

            sections.append(DetailSection(title: "Trip Dates", rows: dateRows))
        }

        // Notes (conditional)
        if !notes.isEmpty {
            sections.append(DetailSection(
                title: "Notes",
                rows: [],
                textContent: notes
            ))
        }

        // Activities Breakdown
        sections.append(DetailSection(
            title: "Activities Breakdown",
            rows: [
                DetailRowData(label: "Transportation", value: "\(transportation.count)"),
                DetailRowData(label: "Lodging", value: "\(lodging.count)"),
                DetailRowData(label: "Activities", value: "\(activity.count)"),
            ]
        ))

        return sections
    }
}
