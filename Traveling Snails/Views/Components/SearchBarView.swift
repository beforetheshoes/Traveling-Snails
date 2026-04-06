//
//  SearchBarView.swift
//  Traveling Snails
//
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    let placeholder: String
    let showsClearButton: Bool

    init(text: Binding<String>, placeholder: String = "Search...", showsClearButton: Bool = true) {
        self._text = text
        self.placeholder = placeholder
        self.showsClearButton = showsClearButton
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if showsClearButton && !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Convenience Extensions
extension SearchBarView {
    /// For organization search (matches current OrganizationPicker usage)
    static func organizations(text: Binding<String>) -> SearchBarView {
        SearchBarView(text: text, placeholder: "Search organizations...")
    }

    /// For file attachment search (matches current FilePickerSearchBar usage)
    static func files(text: Binding<String>) -> SearchBarView {
        SearchBarView(text: text, placeholder: "Search files...")
    }

    /// For general search with custom placeholder
    static func general(text: Binding<String>, placeholder: String) -> SearchBarView {
        SearchBarView(text: text, placeholder: placeholder)
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchBarView.organizations(text: .constant(""))
        SearchBarView.files(text: .constant("test"))
        SearchBarView.general(text: .constant(""), placeholder: "Custom search...")
    }
    .padding()
}
