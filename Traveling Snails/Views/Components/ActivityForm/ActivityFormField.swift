//
//  ActivityFormField.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable form field component with consistent styling
struct ActivityFormField<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            content
        }
    }
}

struct SingleLineTextInput: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(RoundedBorderTextFieldStyle())
    }
}

struct MultiLineTextInput: View {
    let placeholder: String
    @Binding var text: String
    let axis: Axis

    var body: some View {
        TextField(placeholder, text: $text, axis: axis)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .lineLimit(3...6)
    }
}

extension ActivityFormField where Content == SingleLineTextInput {
    init(label: String, text: Binding<String>, placeholder: String = "") {
        self.init(label: label) {
            SingleLineTextInput(
                placeholder: placeholder.isEmpty ? label : placeholder,
                text: text
            )
        }
    }
}

extension ActivityFormField where Content == MultiLineTextInput {
    init(label: String, text: Binding<String>, placeholder: String = "", axis: Axis) {
        self.init(label: label) {
            MultiLineTextInput(
                placeholder: placeholder.isEmpty ? label : placeholder,
                text: text,
                axis: axis
            )
        }
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
                .foregroundStyle(.secondary)

            Button(action: action) {
                HStack {
                    Text(value)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color.systemGray6)
                .clipShape(.rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ActivityFormField(label: "Activity Name") {
            TextField("Enter activity name", text: .constant("Test Activity"))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        ActivityFormField(label: "Notes") {
            TextField("Add notes here", text: .constant("Test notes"), axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }

        ActivityFormButton(
            label: "Organization",
            value: "Select Organization"
        ) {}
    }
    .padding()
}
