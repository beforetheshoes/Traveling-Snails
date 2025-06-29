//
//  UnifiedSearchBar.swift
//  Traveling Snails
//
//

import SwiftUI

struct UnifiedSearchBar: View {
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
                .foregroundColor(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            if showsClearButton && !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Convenience Extensions
extension UnifiedSearchBar {
    /// For organization search (matches current OrganizationPicker usage)
    static func organizations(text: Binding<String>) -> UnifiedSearchBar {
        UnifiedSearchBar(text: text, placeholder: "Search organizations...")
    }

    /// For file attachment search (matches current FilePickerSearchBar usage)
    static func files(text: Binding<String>) -> UnifiedSearchBar {
        UnifiedSearchBar(text: text, placeholder: "Search files...")
    }

    /// For general search with custom placeholder
    static func general(text: Binding<String>, placeholder: String) -> UnifiedSearchBar {
        UnifiedSearchBar(text: text, placeholder: placeholder)
    }
}

#Preview {
    VStack(spacing: 20) {
        UnifiedSearchBar.organizations(text: .constant(""))
        UnifiedSearchBar.files(text: .constant("test"))
        UnifiedSearchBar.general(text: .constant(""), placeholder: "Custom search...")
    }
    .padding()
}
