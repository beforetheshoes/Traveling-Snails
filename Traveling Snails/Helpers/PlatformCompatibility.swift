//
//  PlatformCompatibility.swift
//  Traveling Snails
//
//  Cross-platform compatibility helpers for iOS and macOS.
//

import SwiftUI

// MARK: - Navigation Bar Title Display Mode

extension View {
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Keyboard Type

#if os(macOS)
enum UIKeyboardType {
    case `default`
    case decimalPad
    case numberPad
    case emailAddress
    case URL
    case phonePad
    case asciiCapable
    case numbersAndPunctuation
    case twitter
    case webSearch
    case namePhonePad
    case asciiCapableNumberPad
}
#endif

extension View {
    @ViewBuilder
    nonisolated func platformKeyboardType(_ type: UIKeyboardType) -> some View {
        #if os(iOS)
        self.keyboardType(type)
        #else
        self
        #endif
    }
}

// MARK: - System Colors

#if os(iOS)
extension Color {
    static let systemGray5 = Color(UIColor.systemGray5)
    static let systemGray6 = Color(UIColor.systemGray6)
    static let systemBackground = Color(UIColor.systemBackground)
    static let systemGroupedBackground = Color(UIColor.systemGroupedBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let secondarySystemGroupedBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let separator = Color(UIColor.separator)
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
}
#elseif os(macOS)
extension Color {
    static let systemGray5 = Color(nsColor: .windowBackgroundColor)
    static let systemGray6 = Color(nsColor: .controlBackgroundColor)
    static let systemBackground = Color(nsColor: .windowBackgroundColor)
    static let systemGroupedBackground = Color(nsColor: .windowBackgroundColor)
    static let secondarySystemBackground = Color(nsColor: .controlBackgroundColor)
    static let secondarySystemGroupedBackground = Color(nsColor: .controlBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)
    static let label = Color(nsColor: .labelColor)
    static let secondaryLabel = Color(nsColor: .secondaryLabelColor)
}
#endif

// MARK: - Text Input Autocapitalization

extension View {
    @ViewBuilder
    nonisolated func noAutocapitalization() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }
}

// MARK: - Toolbar Placement

extension ToolbarItemPlacement {
    #if os(iOS)
    static var platformLeading: ToolbarItemPlacement { .navigationBarLeading }
    static var platformTrailing: ToolbarItemPlacement { .navigationBarTrailing }
    static var platformTopLeading: ToolbarItemPlacement { .topBarLeading }
    static var platformTopTrailing: ToolbarItemPlacement { .topBarTrailing }
    #else
    static var platformLeading: ToolbarItemPlacement { .cancellationAction }
    static var platformTrailing: ToolbarItemPlacement { .confirmationAction }
    static var platformTopLeading: ToolbarItemPlacement { .cancellationAction }
    static var platformTopTrailing: ToolbarItemPlacement { .confirmationAction }
    #endif
}
