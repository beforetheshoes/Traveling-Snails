//
//  ActivityFormField.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/21/25.
//

import SwiftUI

/// Reusable form field component with consistent styling
struct ActivityFormField: View {
    let label: String
    let content: AnyView
    
    init<Content: View>(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            content
        }
    }
}

/// Convenience initializer for text fields
extension ActivityFormField {
    init(label: String, text: Binding<String>, placeholder: String = "") {
        self.label = label
        self.content = AnyView(
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        )
    }
    
    init(label: String, text: Binding<String>, placeholder: String = "", axis: Axis) {
        self.label = label
        self.content = AnyView(
            TextField(placeholder.isEmpty ? label : placeholder, text: text, axis: axis)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        )
    }
}

/// Reusable button field for pickers
struct ActivityFormButton: View {
    let label: String
    let value: String
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: action) {
                HStack {
                    Text(value)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ActivityFormField(
            label: "Activity Name",
            text: .constant("Test Activity"),
            placeholder: "Enter activity name"
        )
        
        ActivityFormField(label: "Notes") {
            TextField("Add notes here", text: .constant("Test notes"), axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
        
        ActivityFormButton(
            label: "Organization",
            value: "Select Organization",
            action: {}
        )
    }
    .padding()
}