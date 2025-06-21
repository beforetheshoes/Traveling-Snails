//
//  UnifiedNavigationRootView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import SwiftUI
import SwiftData
//import OSLog

/// Root view for unified navigation - coordinates ViewModels and handles external dependencies
struct UnifiedNavigationRootView<Item: NavigationItem, DetailView: View>: View {
    // Dependencies
    @Binding var selectedTab: Int
    @Binding var selectedTrip: Trip?
    
    // ViewModel
    @State private var viewModel: NavigationViewModel<Item>
    
    // Configuration
    private let detailViewBuilder: (Item) -> DetailView
    private let addViewBuilder: () -> AnyView
    private let customRowContentBuilder: ((Item) -> AnyView)?
    private let searchFilter: ((Item, String) -> Bool)?
    private let onItemSelected: ((Item) -> Void)?
    private let onAddItem: (() -> Void)?
    
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
        let coordinator = NavigationCoordinator()
        self._viewModel = State(wrappedValue: NavigationViewModel(
            items: items,
            configuration: configuration,
            tabIndex: tabIndex,
            coordinator: coordinator
        ))
        self._selectedTab = selectedTab
        self._selectedTrip = selectedTrip
        self.detailViewBuilder = detailViewBuilder
        self.addViewBuilder = addViewBuilder
        self.customRowContentBuilder = rowContentBuilder
        self.searchFilter = searchFilter
        self.onItemSelected = onItemSelected
        self.onAddItem = onAddItem
    }
    
    var body: some View {
        NavigationSplitView {
            NavigationContentView(
                items: filteredItems,
                configuration: viewModel.configuration,
                searchText: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.handleSearch($0) }
                ),
                selectedItem: Binding(
                    get: { viewModel.selectedItem },
                    set: { item in
                        if let item = item {
                            viewModel.selectItem(item)
                            onItemSelected?(item)
                            
                            // Handle trip selection for coordination
                            if let trip = item as? Trip {
                                selectedTrip = trip
                            }
                        }
                    }
                ),
                onItemTap: { item in
                    Logger.shared.debug("Item tapped: \(item.displayName)", category: .navigation)
                    viewModel.selectItem(item)
                    onItemSelected?(item)
                    
                    // Handle trip selection for coordination
                    if let trip = item as? Trip {
                        selectedTrip = trip
                    }
                },
                onAddTap: {
                    Logger.shared.info("Add button tapped", category: .navigation)
                    viewModel.handleAddAction(onAddItem)
                }
            )
            .navigationDestination(for: Item.self) { item in
                detailViewBuilder(item)
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showingAddView },
                set: { showing in
                    if showing {
                        viewModel.showAddView()
                    } else {
                        viewModel.hideAddView()
                    }
                }
            )) {
                addViewBuilder()
            }
        } detail: {
            if let selectedItem = viewModel.selectedItem {
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
            viewModel.handleTabChange(to: newTab)
            Logger.shared.debug("Tab changed to \(newTab), clearing selection", category: .navigation)
        }
        .onChange(of: selectedTrip) { _, newTrip in
            if selectedTab == viewModel.tabIndex, let trip = newTrip {
                // Navigate to trip when selected from another tab
                if let tripItem = viewModel.items.first(where: { $0.id == trip.id }) {
                    viewModel.selectItem(tripItem)
                    Logger.shared.info("Navigating to trip: \(trip.name)", category: .navigation)
                }
            }
        }
    }
    
    // MARK: - Private Computed Properties
    
    private var filteredItems: [Item] {
        if let customFilter = searchFilter {
            return viewModel.items.filter { customFilter($0, viewModel.searchText) }
        }
        return viewModel.filteredItems
    }
}

// MARK: - Convenience Initializers

extension UnifiedNavigationRootView where Item == Trip, DetailView == AnyView {
    static func trips(
        trips: [Trip],
        selectedTab: Binding<Int>,
        selectedTrip: Binding<Trip?>,
        tabIndex: Int,
        onTripSelected: ((Trip) -> Void)? = nil
    ) -> UnifiedNavigationRootView<Trip, AnyView> {
        let config = NavigationConfiguration<Trip>(
            title: NSLocalizedString("navigation.trips.title", value: "Trips", comment: "Trips navigation title"),
            emptyStateTitle: NSLocalizedString("navigation.trips.empty.title", value: "No Trips", comment: "Empty trips title"),
            emptyStateIcon: "airplane",
            emptyStateDescription: NSLocalizedString("navigation.trips.empty.description", value: "Create your first trip to get started", comment: "Empty trips description"),
            addButtonTitle: NSLocalizedString("navigation.trips.add", value: "Add Trip", comment: "Add trip button"),
            addButtonIcon: "plus",
            searchPlaceholder: NSLocalizedString("navigation.trips.search", value: "Search trips...", comment: "Trips search placeholder")
        )
        
        return UnifiedNavigationRootView(
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

extension UnifiedNavigationRootView where Item == Organization, DetailView == AnyView {
    static func organizations(
        organizations: [Organization],
        selectedTab: Binding<Int>,
        selectedTrip: Binding<Trip?>,
        tabIndex: Int,
        onOrganizationSelected: ((Organization) -> Void)? = nil
    ) -> UnifiedNavigationRootView<Organization, AnyView> {
        let config = NavigationConfiguration<Organization>(
            title: NSLocalizedString("navigation.organizations.title", value: "Organizations", comment: "Organizations navigation title"),
            emptyStateTitle: NSLocalizedString("navigation.organizations.empty.title", value: "No Organizations", comment: "Empty organizations title"),
            emptyStateIcon: "building.2",
            emptyStateDescription: NSLocalizedString("navigation.organizations.empty.description", value: "Add your first organization to get started", comment: "Empty organizations description"),
            addButtonTitle: NSLocalizedString("navigation.organizations.add", value: "Add Organization", comment: "Add organization button"),
            addButtonIcon: "plus",
            searchPlaceholder: NSLocalizedString("navigation.organizations.search", value: "Search organizations...", comment: "Organizations search placeholder")
        )
        
        return UnifiedNavigationRootView(
            items: organizations,
            configuration: config,
            selectedTab: selectedTab,
            selectedTrip: selectedTrip,
            tabIndex: tabIndex,
            detailViewBuilder: { organization in
                AnyView(Text(NSLocalizedString("organizationDetail.placeholder", value: "Organization Detail - \(organization.displayName)", comment: "Organization detail placeholder")))
            },
            addViewBuilder: {
                AnyView(Text(NSLocalizedString("addOrganization.placeholder", value: "Add Organization View - To Be Implemented", comment: "Add organization placeholder")))
            },
            onItemSelected: onOrganizationSelected
        )
    }
}

// MARK: - Supporting Views
// TripDetailWrapper is already defined in UnifiedNavigationView.swift
