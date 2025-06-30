//
//  UnifiedNavigationView.swift
//  Traveling Snails
//
//

import Foundation
import SwiftData
import SwiftUI
// import OSLog

// MARK: - Navigation Item Protocol

protocol NavigationItem: Identifiable, Hashable {
    var id: UUID { get }
    var displayName: String { get }
    var displaySubtitle: String? { get }
    var displayIcon: String { get }
    var displayColor: Color { get }
    var displayBadgeCount: Int? { get }
}

// MARK: - Navigation Configuration

struct NavigationConfiguration<Item: NavigationItem> {
    let title: String
    let emptyStateTitle: String
    let emptyStateIcon: String
    let emptyStateDescription: String
    let addButtonTitle: String
    let addButtonIcon: String
    let searchPlaceholder: String
    let allowsSearch: Bool
    let allowsSelection: Bool

    init(
        title: String,
        emptyStateTitle: String = "No Items",
        emptyStateIcon: String = "tray",
        emptyStateDescription: String = "No items found",
        addButtonTitle: String = "Add Item",
        addButtonIcon: String = "plus",
        searchPlaceholder: String = "Search...",
        allowsSearch: Bool = true,
        allowsSelection: Bool = true
    ) {
        self.title = title
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateIcon = emptyStateIcon
        self.emptyStateDescription = emptyStateDescription
        self.addButtonTitle = addButtonTitle
        self.addButtonIcon = addButtonIcon
        self.searchPlaceholder = searchPlaceholder
        self.allowsSearch = allowsSearch
        self.allowsSelection = allowsSelection
    }
}

// MARK: - Unified Navigation View

struct UnifiedNavigationView<Item: NavigationItem, DetailView: View>: View {
    // Environment
    @Environment(\.navigationRouter) private var navigationRouter
    
    // Data
    let items: [Item]
    let configuration: NavigationConfiguration<Item>

    // Navigation
    @State private var selectedItem: Item?
    @State private var navigationPath = NavigationPath()
    @Binding var selectedTab: Int
    @Binding var selectedTrip: Trip?
    let tabIndex: Int

    // UI State
    @State private var searchText = ""
    @State private var showingAddView = false

    // Content builders
    let detailViewBuilder: (Item) -> DetailView
    let addViewBuilder: () -> AnyView
    let rowContentBuilder: ((Item) -> AnyView)?

    // Search filtering
    let searchFilter: ((Item, String) -> Bool)?

    // Actions
    let onItemSelected: ((Item) -> Void)?
    let onAddItem: (() -> Void)?

    init(
        items: [Item],
        configuration: NavigationConfiguration<Item>,
        selectedTab: Binding<Int>,
        selectedTrip: Binding<Trip?>,
        tabIndex: Int,
        detailViewBuilder: @escaping (Item) -> DetailView,
        addViewBuilder: @escaping () -> AnyView,
        rowContentBuilder: ((Item) -> AnyView)? = nil,
        searchFilter: ((Item, String) -> Bool)? = nil,
        onItemSelected: ((Item) -> Void)? = nil,
        onAddItem: (() -> Void)? = nil
    ) {
        self.items = items
        self.configuration = configuration
        self._selectedTab = selectedTab
        self._selectedTrip = selectedTrip
        self.tabIndex = tabIndex
        self.detailViewBuilder = detailViewBuilder
        self.addViewBuilder = addViewBuilder
        self.rowContentBuilder = rowContentBuilder
        self.searchFilter = searchFilter
        self.onItemSelected = onItemSelected
        self.onAddItem = onAddItem
    }

    private var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }

        if let customFilter = searchFilter {
            return items.filter { customFilter($0, searchText) }
        }

        // Default search implementation
        return items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationSplitView {
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
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemsList
                }
            }
            .navigationTitle(configuration.title)
            .navigationDestination(for: Item.self) { item in
                detailViewBuilder(item)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Logger.shared.info("Add button tapped", category: .navigation)
                        if let onAddItem = onAddItem {
                            onAddItem()
                        } else {
                            showingAddView = true
                        }
                    } label: {
                        Label(configuration.addButtonTitle, systemImage: configuration.addButtonIcon)
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                addViewBuilder()
            }
        } detail: {
            if let selectedItem = selectedItem {
                detailViewBuilder(selectedItem)
            } else {
                ContentUnavailableView(
                    NSLocalizedString("navigation.detail.selectItem.title", value: "Select an Item", comment: "Title when no item is selected"),
                    systemImage: "sidebar.left",
                    description: Text(NSLocalizedString("navigation.detail.selectItem.description", value: "Choose an item from the list to view details", comment: "Description when no item is selected"))
                )
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != tabIndex {
                selectedItem = nil
                navigationPath = NavigationPath()
                Logger.shared.debug("Tab changed to \(newTab), clearing selection", category: .navigation)
            } else if newTab == tabIndex, let trip = selectedTrip {
                // Restore trip selection when returning to this tab
                if let tripItem = items.first(where: { $0.id == trip.id }) {
                    selectedItem = tripItem
                    Logger.shared.info("Restoring trip selection on tab return: \(trip.name)", category: .navigation)
                }
            }
        }
        .onChange(of: selectedTrip) { _, newTrip in
            if selectedTab == tabIndex, let trip = newTrip {
                // Navigate to trip when selected from another tab
                if let tripItem = items.first(where: { $0.id == trip.id }) {
                    selectedItem = tripItem
                    Logger.shared.info("Navigating to trip: \(trip.name)", category: .navigation)
                }
            }
        }
        .onAppear {
            // iPad fix: Ensure trip selection is restored when view appears
            if selectedTab == tabIndex, let trip = selectedTrip, selectedItem == nil {
                if let tripItem = items.first(where: { $0.id == trip.id }) {
                    selectedItem = tripItem
                    Logger.shared.info("iPad restoration: Restoring trip selection on view appear: \(trip.name)", category: .navigation)
                }
            }
        }
        .onChange(of: navigationRouter.shouldClearNavigationPath) { _, shouldClear in
            handleNavigationPathClear(shouldClear: shouldClear)
        }
    }
    
    /// Handle environment-based navigation path clearing
    /// This method coordinates navigation state clearing between the environment router
    /// and local navigation state in a type-safe manner
    private func handleNavigationPathClear(shouldClear: Bool) {
        guard shouldClear else { return }
        
        Logger.shared.debug("Environment-based navigation clear - clearing selectedItem and navigationPath", category: .navigation)
        Logger.shared.debug("Current selectedItem: \(selectedItem?.displayName ?? "nil")", category: .navigation)
        
        // Clear local navigation state
        selectedItem = nil
        navigationPath = NavigationPath()
        
        // Acknowledge that we've handled the navigation clear request
        navigationRouter.acknowledgeNavigationPathClear()
        
        Logger.shared.debug("Cleared selectedItem and navigationPath for environment-based navigation", category: .navigation)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView(
            NSLocalizedString(configuration.emptyStateTitle, value: configuration.emptyStateTitle, comment: "Empty state title"),
            systemImage: configuration.emptyStateIcon,
            description: Text(NSLocalizedString(configuration.emptyStateDescription, value: configuration.emptyStateDescription, comment: "Empty state description"))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var itemsList: some View {
        List(
            filteredItems,
            selection: configuration.allowsSelection ? $selectedItem : .constant(nil)
        ) { item in
            // Remove the conflicting NavigationLink + onTapGesture pattern
            // Use a single gesture handling approach
            Group {
                if let customRow = rowContentBuilder {
                    customRow(item)
                } else {
                    EnhancedItemRowView(
                        item: item,
                        isSelected: selectedItem?.id == item.id || selectedTrip?.id == item.id
                    )
                }
            }
            .contentShape(Rectangle()) // Ensure entire row area is tappable
            .onTapGesture {
                Logger.shared.debug("Item tapped: \(item.displayName)", category: .navigation)
                selectedItem = item
                onItemSelected?(item)

                // Update selectedTrip if this is a trip
                if let trip = item as? Trip {
                    selectedTrip = trip
                    // Use environment-based navigation instead of notifications
                    navigationRouter.selectTrip(trip.id)
                    Logger.shared.debug("Environment-based trip selection for trip: \(trip.name)", category: .navigation)
                }
            }
            .listRowSeparator(.hidden) // Hide separators since we have our own styling
            .listRowBackground(Color.clear) // Remove the gray background
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)) // Reduce list insets to give more room for the rounded rectangle
        }
        .listStyle(.plain) // Use plain style to avoid extra background styling
        .scrollContentBackground(.visible)
    }
}

// MARK: - Enhanced Row View with Better Touch Targets

struct EnhancedItemRowView<Item: NavigationItem>: View {
    let item: Item
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    private let authManager = BiometricAuthManager.shared

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
        .padding(.horizontal, 16) // Add back horizontal padding inside the rounded rectangle
        .padding(.vertical, 8) // Slightly increase internal vertical padding
        .frame(maxWidth: .infinity) // Make it full width
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

// Wrapper view to ensure stable identity
struct TripDetailWrapper: View {
    let trip: Trip

    // Cache the trip ID to avoid SwiftData reactivity
    private let tripID: UUID
    private let tripName: String

    init(trip: Trip) {
        self.trip = trip
        self.tripID = trip.id
        self.tripName = trip.name
    }

    var body: some View {
        IsolatedTripDetailView(trip: trip)
    }
}

extension UnifiedNavigationView where Item == Trip, DetailView == AnyView {
    static func trips(
        trips: [Trip],
        selectedTab: Binding<Int>,
        selectedTrip: Binding<Trip?>,
        tabIndex: Int,
        onTripSelected: ((Trip) -> Void)? = nil
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
            selectedTab: selectedTab,
            selectedTrip: selectedTrip,
            tabIndex: tabIndex,
            detailViewBuilder: { trip in
                AnyView(TripDetailWrapper(trip: trip))
            },
            addViewBuilder: {
                AnyView(AddTrip())
            },
            onItemSelected: onTripSelected
        )
    }
}

extension UnifiedNavigationView where Item == Organization, DetailView == AnyView {
    static func organizations(
        organizations: [Organization],
        selectedTab: Binding<Int>,
        selectedTrip: Binding<Trip?>,
        tabIndex: Int,
        onOrganizationSelected: ((Organization) -> Void)? = nil
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
            selectedTab: selectedTab,
            selectedTrip: selectedTrip,
            tabIndex: tabIndex,
            detailViewBuilder: { organization in
                AnyView(OrganizationDetailView(
                    selectedTab: selectedTab,
                    selectedTrip: selectedTrip,
                    organization: organization
                ))
            },
            addViewBuilder: {
                AnyView(AddOrganizationForm { _ in
                    // Organization added, dismiss handled by the form itself
                })
            },
            onItemSelected: onOrganizationSelected
        )
    }
}
