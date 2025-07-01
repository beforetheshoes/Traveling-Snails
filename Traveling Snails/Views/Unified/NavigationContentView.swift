//
//  NavigationContentView.swift
//  Traveling Snails
//
//

import SwiftUI

/// Content view for navigation - handles only UI rendering
struct NavigationContentView<Item: NavigationItem>: View {
    let items: [Item]
    let configuration: NavigationConfiguration<Item>
    @Binding var searchText: String
    @Binding var selectedItem: Item?
    let onItemTap: (Item) -> Void
    let onAddTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if configuration.allowsSearch {
                UnifiedSearchBar.general(
                    text: $searchText,
                    placeholder: configuration.searchPlaceholder
                )
                .padding(.top, 8)
            }

            // Content
            if items.isEmpty {
                NavigationEmptyStateView(configuration: configuration)
            } else {
                NavigationListView(
                    items: items,
                    configuration: configuration,
                    selectedItem: selectedItem,
                    onItemTap: onItemTap
                )
            }
        }
        .navigationTitle(configuration.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    onAddTap()
                } label: {
                    Label(configuration.addButtonTitle, systemImage: configuration.addButtonIcon)
                }
            }
        }
    }
}

/// Empty state view for when no items are available
struct NavigationEmptyStateView<Item: NavigationItem>: View {
    let configuration: NavigationConfiguration<Item>

    var body: some View {
        ContentUnavailableView(
            NSLocalizedString(configuration.emptyStateTitle, value: configuration.emptyStateTitle, comment: "Empty state title"),
            systemImage: configuration.emptyStateIcon,
            description: Text(NSLocalizedString(configuration.emptyStateDescription, value: configuration.emptyStateDescription, comment: "Empty state description"))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// List view for rendering navigation items
struct NavigationListView<Item: NavigationItem>: View {
    let items: [Item]
    let configuration: NavigationConfiguration<Item>
    let selectedItem: Item?
    let onItemTap: (Item) -> Void

    var body: some View {
        List(
            items,
            selection: configuration.allowsSelection ? .constant(selectedItem) : .constant(nil)
        ) { item in
            NavigationRowView(
                item: item,
                isSelected: selectedItem?.id == item.id
            ) { onItemTap(item) }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        }
        .listStyle(.plain)
        .scrollContentBackground(.visible)
    }
}

/// Individual row view for navigation items
struct NavigationRowView<Item: NavigationItem>: View {
    let item: Item
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ModernBiometricAuthManager.self) private var authManager

    var body: some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(item.displayColor.opacity(isSelected ? 0.3 : 0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(item.displayColor, lineWidth: isSelected ? 2 : 0)
                    )

                Image(systemName: item.displayIcon)
                    .foregroundStyle(item.displayColor)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let subtitle = item.displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Badge and chevron
            HStack(spacing: 8) {
                // Biometric protection indicator
                if let trip = item as? Trip,
                   authManager.isEnabled && authManager.isProtected(trip) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Protected with biometric authentication")
                }

                if let badgeCount = item.displayBadgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.displayColor, in: Capsule())
                        .accessibilityLabel("\(badgeCount) items")
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? item.displayColor.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.displayColor.opacity(isSelected ? 0.3 : 0), lineWidth: isSelected ? 1 : 0)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(NSLocalizedString("navigation.row.accessibilityHint", value: "Double tap to view details", comment: "Accessibility hint for navigation rows"))
    }
}
