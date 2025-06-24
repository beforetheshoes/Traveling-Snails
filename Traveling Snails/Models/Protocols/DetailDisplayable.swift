//
//  DetailDisplayable.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

// MARK: - Generic Detail View System
protocol DetailDisplayable {
    var detailSections: [DetailSection] { get }
}

struct DetailSection {
    let title: String
    let rows: [DetailRowData]
    let content: AnyView?
    
    init(title: String, rows: [DetailRowData], content: AnyView? = nil) {
        self.title = title
        self.rows = rows
        self.content = content
    }
    
    // Convenience initializer for text content
    init(title: String, rows: [DetailRowData], textContent: String?) {
        self.title = title
        self.rows = rows
        if let textContent = textContent, !textContent.isEmpty {
            self.content = AnyView(
                Text(textContent)
                    .font(.body)
            )
        } else {
            self.content = nil
        }
    }
}

struct DetailRowData {
    let label: String
    let value: String
    let isConditional: Bool
    
    init(label: String, value: String, isConditional: Bool = false) {
        self.label = label
        self.value = value
        self.isConditional = isConditional
    }
    
    // Convenience for optional values
    init(label: String, optionalValue: String?, defaultValue: String = "Not set") {
        self.label = label
        self.value = optionalValue?.isEmpty == false ? optionalValue! : defaultValue
        self.isConditional = false
    }
    
    // Convenience for boolean values
    init(label: String, boolValue: Bool) {
        self.label = label
        self.value = boolValue ? "Yes" : "No"
        self.isConditional = false
    }
}

// MARK: - Generic Detail View
struct GenericDetailView: View {
    let item: DetailDisplayable
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(item.detailSections.enumerated()), id: \.offset) { index, section in
                        DetailCard(title: section.title) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(section.rows.enumerated()), id: \.offset) { rowIndex, rowData in
                                    DetailRow(label: rowData.label, value: rowData.value)
                                }
                                
                                if let content = section.content {
                                    content
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
