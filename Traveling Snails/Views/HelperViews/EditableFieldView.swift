//
//  EditableFieldView.swift
//  Traveling Snails
//
//

import SwiftUI

struct EditableFieldView<Content: View, EditContent: View>: View {
    let label: String
    let systemImage: String
    let isEditing: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let editContent: () -> EditContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)

                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        editContent()
                    }
                } else {
                    content()
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditableSection: View {
    let title: String
    let isEditing: Bool
    let content: () -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.horizontal)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// Animated transition wrapper
struct EditTransition: ViewModifier {
    let isEditing: Bool

    func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}
