//
//  UnifiedNavigationView.swift
//  Traveling Snails
//

import Foundation
import SQLiteData
import SwiftUI

// MARK: - Unified Navigation View

struct UnifiedNavigationView<Item: NavigationItem, DetailView: View>: View {
    private struct CompactRoute: Identifiable, Hashable {
        let id: UUID
    }

    // Data
    let items: [Item]
    let configuration: NavigationConfiguration<Item>
    @Binding var selectedItemID: UUID?

    // UI State
    @State private var searchText = ""
    @State private var showingAddView = false
    @State private var compactRoute: CompactRoute?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesCompactNavigation: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    // Content builders
    let detailViewBuilder: (Item) -> DetailView
    let addViewBuilder: () -> AnyView
    let rowContentBuilder: ((Item, Bool) -> AnyView)?

    // Search filtering
    let searchFilter: ((Item, String) -> Bool)?

    // Actions
    let onItemSelection: (Item, Bool) -> Void
    let onAddItem: (() -> Void)?

    init(
        items: [Item],
        configuration: NavigationConfiguration<Item>,
        selectedItemID: Binding<UUID?>,
        detailViewBuilder: @escaping (Item) -> DetailView,
        addViewBuilder: @escaping () -> AnyView,
        rowContentBuilder: ((Item, Bool) -> AnyView)? = nil,
        searchFilter: ((Item, String) -> Bool)? = nil,
        onItemSelection: @escaping (Item, Bool) -> Void,
        onAddItem: (() -> Void)? = nil
    ) {
        self.items = items
        self.configuration = configuration
        self._selectedItemID = selectedItemID
        self.detailViewBuilder = detailViewBuilder
        self.addViewBuilder = addViewBuilder
        self.rowContentBuilder = rowContentBuilder
        self.searchFilter = searchFilter
        self.onItemSelection = onItemSelection
        self.onAddItem = onAddItem
    }

    private var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }

        if let customFilter = searchFilter {
            return items.filter { customFilter($0, searchText) }
        }

        return items.filter { item in
            item.displayName.localizedStandardContains(searchText) ||
            (item.displaySubtitle?.localizedStandardContains(searchText) ?? false)
        }
    }

    private var selectedItem: Item? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    var body: some View {
        Group {
            if usesCompactNavigation {
                NavigationStack {
                    listContent
                        .navigationDestination(item: $compactRoute) { route in
                            if let item = items.first(where: { $0.id == route.id }) {
                                detailViewBuilder(item)
                            } else if let id = selectedItemID,
                               let item = items.first(where: { $0.id == id }) {
                                detailViewBuilder(item)
                            } else {
                                ContentUnavailableView(
                                    NSLocalizedString("navigation.detail.selectItem.title", value: "Select an Item", comment: "Title when no item is selected"),
                                    systemImage: "sidebar.left",
                                    description: Text(NSLocalizedString("navigation.detail.selectItem.description", value: "Choose an item from the list to view details", comment: "Description when no item is selected"))
                                )
                            }
                        }
                }
                .onAppear {
                    guard compactRoute == nil, let selectedItemID else { return }
                    compactRoute = CompactRoute(id: selectedItemID)
                    #if DEBUG
                    Logger.shared.debug("Compact nav onAppear seeded route: \(selectedItemID)", category: .navigation)
                    #endif
                }
                .onChange(of: selectedItemID) { _, newID in
                    guard let newID else {
                        #if DEBUG
                        Logger.shared.debug("Compact nav clearing route because selectedItemID became nil", category: .navigation)
                        #endif
                        compactRoute = nil
                        return
                    }
                    if compactRoute?.id != newID {
                        #if DEBUG
                        Logger.shared.debug("Compact nav syncing route to selectedItemID: \(newID)", category: .navigation)
                        #endif
                        compactRoute = CompactRoute(id: newID)
                    }
                }
                .onChange(of: compactRoute) { _, newRoute in
                    #if DEBUG
                    Logger.shared.debug("Compact nav route changed: \(newRoute?.id.uuidString ?? "nil")", category: .navigation)
                    #endif
                }
            } else {
                NavigationSplitView {
                    listContent
                } detail: {
                    if let selectedItem {
                        detailViewBuilder(selectedItem)
                    } else {
                        ContentUnavailableView(
                            NSLocalizedString("navigation.detail.selectItem.title", value: "Select an Item", comment: "Title when no item is selected"),
                            systemImage: "sidebar.left",
                            description: Text(NSLocalizedString("navigation.detail.selectItem.description", value: "Choose an item from the list to view details", comment: "Description when no item is selected"))
                        )
                    }
                }
            }
        }
        .id(usesCompactNavigation ? "compact-nav" : "split-nav")
    }

    @ViewBuilder
    private var listContent: some View {
        VStack(spacing: 0) {
            if configuration.allowsSearch {
                UnifiedSearchBar.general(
                    text: $searchText,
                    placeholder: configuration.searchPlaceholder
                )
                .padding(.top, 8)
                .accessibilityIdentifier("SearchBar")
                .accessibilityLabel(configuration.searchPlaceholder)
                .accessibilityHint("Type to search \(configuration.title.lowercased())")
            }

            if filteredItems.isEmpty {
                emptyStateView
            } else {
                itemsList
            }
        }
        .navigationTitle(configuration.title)
        .accessibilityIdentifier("NavigationView_\(configuration.title.replacingOccurrences(of: " ", with: ""))")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let onAddItem {
                        onAddItem()
                    } else {
                        showingAddView = true
                    }
                } label: {
                    Label(configuration.addButtonTitle, systemImage: configuration.addButtonIcon)
                }
                .accessibilityIdentifier("AddButton_\(configuration.title.replacingOccurrences(of: " ", with: ""))")
                .accessibilityLabel(configuration.addButtonTitle)
            }
        }
        .sheet(isPresented: $showingAddView) {
            addViewBuilder()
        }
    }
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            NSLocalizedString(configuration.emptyStateTitle, value: configuration.emptyStateTitle, comment: "Empty state title"),
            systemImage: configuration.emptyStateIcon,
            description: Text(NSLocalizedString(configuration.emptyStateDescription, value: configuration.emptyStateDescription, comment: "Empty state description"))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("EmptyStateView_\(configuration.title.replacingOccurrences(of: " ", with: ""))")
    }

    @ViewBuilder
    private var itemsList: some View {
        List(filteredItems) { item in
            let isSelected = selectedItemID == item.id
            let isActiveInCompact = compactRoute?.id == item.id

            Button {
                let isReselect = usesCompactNavigation ? isActiveInCompact : isSelected
                #if DEBUG
                Logger.shared.debug("Row tap \(item.id), isReselect: \(isReselect)", category: .navigation)
                #endif
                onItemSelection(item, isReselect)
                if usesCompactNavigation {
                    compactRoute = CompactRoute(id: item.id)
                }
            } label: {
                itemRowContent(for: item, isSelected: isSelected)
                    .modifier(ItemRowModifier(item: item))
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .scrollContentBackground(.visible)
        .accessibilityIdentifier("\(configuration.title.replacingOccurrences(of: " ", with: ""))ListView")
        .accessibilityLabel("\(configuration.title) list")
    }

    @ViewBuilder
    private func itemRowContent(for item: Item, isSelected: Bool) -> some View {
        Group {
            if let customRow = rowContentBuilder {
                customRow(item, isSelected)
            } else {
                EnhancedItemRowView(
                    item: item,
                    isSelected: isSelected
                )
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Enhanced Row View with Better Touch Targets

struct EnhancedItemRowView<Item: NavigationItem>: View {
    let item: Item
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ModernBiometricAuthManager.self) private var authManager

    var body: some View {
        HStack(spacing: 16) {
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

            HStack(spacing: 8) {
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(NSLocalizedString("navigation.row.accessibilityHint", value: "Double tap to view details", comment: "Accessibility hint for navigation rows"))
    }
}

// MARK: - Navigation Item Extensions for Existing Models

extension Trip: NavigationItem, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Trip, rhs: Trip) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String { name.isEmpty ? NSLocalizedString("trip.untitled", value: "Untitled Trip", comment: "Default trip name") : name }

    var displaySubtitle: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if hasDateRange {
            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)
            return "\(start) - \(end)"
        } else if hasStartDate {
            return String(format: NSLocalizedString("trip.startsOn", value: "Starts %@", comment: "Trip start date format"), formatter.string(from: startDate))
        } else if hasEndDate {
            return String(format: NSLocalizedString("trip.endsOn", value: "Ends %@", comment: "Trip end date format"), formatter.string(from: endDate))
        } else {
            return NSLocalizedString("trip.noDates", value: "No dates set", comment: "Trip with no dates")
        }
    }

    var displayIcon: String { "airplane" }
    var displayColor: Color { .blue }

    var displayBadgeCount: Int? {
        let count = totalActivities
        return count > 0 ? count : nil
    }
}

extension Organization: NavigationItem, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Organization, rhs: Organization) -> Bool {
        lhs.id == rhs.id
    }

    var displayName: String { name.isEmpty ? NSLocalizedString("organization.unnamed", value: "Unnamed Organization", comment: "Default organization name") : name }

    var displaySubtitle: String? {
        let parts = [phone, email].filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " • ")
        }

        let transportCount = transportation.count
        let lodgingCount = lodging.count
        let activityCount = activity.count
        let totalCount = transportCount + lodgingCount + activityCount

        if totalCount > 0 {
            var components: [String] = []
            if transportCount > 0 {
                components.append(String(format: NSLocalizedString("organization.transportCount", value: "%d transport", comment: "Transport count"), transportCount))
            }
            if lodgingCount > 0 {
                components.append(String(format: NSLocalizedString("organization.lodgingCount", value: "%d lodging", comment: "Lodging count"), lodgingCount))
            }
            if activityCount > 0 {
                components.append(String(format: NSLocalizedString("organization.activityCount", value: "%d activities", comment: "Activity count"), activityCount))
            }
            return components.joined(separator: ", ")
        }

        return nil
    }

    var displayIcon: String { "building.2" }
    var displayColor: Color { .orange }

    var displayBadgeCount: Int? {
        let count = transportation.count + lodging.count + activity.count
        return count > 0 ? count : nil
    }
}

// MARK: - Convenience Initializers

extension UnifiedNavigationView where Item == Trip, DetailView == AnyView {
    static func trips(
        trips: [Trip],
        selectedTripID: Binding<Trip.ID?>,
        tripPath: Binding<[TripRoute]>,
        tripResetToken: Int,
        onTripSelection: @escaping (Trip, Bool) -> Void
    ) -> UnifiedNavigationView<Trip, AnyView> {
        let config = NavigationConfiguration<Trip>(
            title: NSLocalizedString("navigation.trips.title", value: "Trips", comment: "Trips navigation title"),
            emptyStateTitle: NSLocalizedString("navigation.trips.empty.title", value: "No Trips", comment: "Empty trips title"),
            emptyStateIcon: "airplane",
            emptyStateDescription: NSLocalizedString("navigation.trips.empty.description", value: "Create your first trip to get started", comment: "Empty trips description"),
            addButtonTitle: NSLocalizedString("navigation.trips.add", value: "Add Trip", comment: "Add trip button"),
            addButtonIcon: "plus",
            searchPlaceholder: NSLocalizedString("navigation.trips.search", value: "Search trips...", comment: "Trips search placeholder")
        )

        return UnifiedNavigationView(
            items: trips,
            configuration: config,
            selectedItemID: Binding(
                get: { selectedTripID.wrappedValue },
                set: { selectedTripID.wrappedValue = $0 }
            ),
            detailViewBuilder: { trip in
                AnyView(
                    IsolatedTripDetailView(
                        trip: trip,
                        path: tripPath,
                        resetToken: tripResetToken
                    )
                )
            },
            addViewBuilder: {
                AnyView(AddTrip())
            },
            onItemSelection: { item, isReselect in
                onTripSelection(item, isReselect)
            }
        )
    }
}

extension UnifiedNavigationView where Item == Organization, DetailView == AnyView {
    static func organizations(
        organizations: [Organization],
        selectedOrganizationID: Binding<Organization.ID?>,
        onOrganizationSelected: @escaping (Organization) -> Void,
        onOpenTrip: @escaping (Trip.ID) -> Void
    ) -> UnifiedNavigationView<Organization, AnyView> {
        let config = NavigationConfiguration<Organization>(
            title: NSLocalizedString("navigation.organizations.title", value: "Organizations", comment: "Organizations navigation title"),
            emptyStateTitle: NSLocalizedString("navigation.organizations.empty.title", value: "No Organizations", comment: "Empty organizations title"),
            emptyStateIcon: "building.2",
            emptyStateDescription: NSLocalizedString("navigation.organizations.empty.description", value: "Add your first organization to get started", comment: "Empty organizations description"),
            addButtonTitle: NSLocalizedString("navigation.organizations.add", value: "Add Organization", comment: "Add organization button"),
            addButtonIcon: "plus",
            searchPlaceholder: NSLocalizedString("navigation.organizations.search", value: "Search organizations...", comment: "Organizations search placeholder")
        )

        return UnifiedNavigationView(
            items: organizations,
            configuration: config,
            selectedItemID: Binding(
                get: { selectedOrganizationID.wrappedValue },
                set: { selectedOrganizationID.wrappedValue = $0 }
            ),
            detailViewBuilder: { organization in
                AnyView(
                    OrganizationDetailView(
                        organization: organization,
                        onOpenTrip: onOpenTrip
                    )
                )
            },
            addViewBuilder: {
                AnyView(AddOrganizationForm { _ in })
            },
            onItemSelection: { item, _ in
                onOrganizationSelected(item)
            }
        )
    }
}

// MARK: - ItemRowModifier

struct ItemRowModifier<Item: NavigationItem>: ViewModifier {
    let item: Item

    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier("ItemRow_\(item.id.uuidString.prefix(8))")
            .accessibilityLabel(buildAccessibilityLabel(for: item))
            .accessibilityHint(buildAccessibilityHint(for: item))
            .accessibilityValue(buildAccessibilityValue(for: item) ?? "")
            .accessibilityAddTraits(.isButton)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
    }

    private func buildAccessibilityLabel(for item: Item) -> String {
        var components: [String] = [item.displayName]

        if let subtitle = item.displaySubtitle {
            components.append(subtitle)
        }

        if let badgeCount = item.displayBadgeCount, badgeCount > 0 {
            components.append("\(badgeCount) items")
        }

        return components.joined(separator: ", ")
    }

    private func buildAccessibilityHint(for item: Item) -> String {
        "Double tap to select and view details"
    }

    private func buildAccessibilityValue(for item: Item) -> String? {
        if let badgeCount = item.displayBadgeCount, badgeCount > 0 {
            return "\(badgeCount) items"
        }
        return nil
    }
}
