//
//  NavigationViewModel.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import Foundation
import SwiftUI
import Observation

@Observable
class NavigationViewModel<Item: NavigationItem> {
    // MARK: - Properties
    
    let items: [Item]
    let configuration: NavigationConfiguration<Item>
    let tabIndex: Int
    private let coordinator: NavigationCoordinator
    
    // State properties
    var searchText: String = ""
    var selectedItem: Item? = nil
    var showingAddView: Bool = false
    
    // MARK: - Initialization
    
    init(items: [Item], configuration: NavigationConfiguration<Item>, tabIndex: Int, coordinator: NavigationCoordinator = NavigationCoordinator()) {
        self.items = items
        self.configuration = configuration
        self.tabIndex = tabIndex
        self.coordinator = coordinator
    }
    
    // MARK: - Computed Properties
    
    var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }
        
        return items.filter { item in
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            (item.displaySubtitle?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // MARK: - Actions
    
    func selectItem(_ item: Item) {
        selectedItem = item
        coordinator.handleItemSelection(item)
    }
    
    func clearSelection() {
        selectedItem = nil
    }
    
    func handleTabChange(to newTab: Int) {
        if newTab != tabIndex {
            selectedItem = nil
            coordinator.clearNavigationPath()
        }
    }
    
    func showAddView() {
        showingAddView = true
    }
    
    func hideAddView() {
        showingAddView = false
    }
    
    func handleSearch(_ text: String) {
        searchText = text
    }
    
    func handleAddAction(_ customAction: (() -> Void)? = nil) {
        if let customAction = customAction {
            customAction()
        } else {
            showAddView()
        }
    }
}

// MARK: - NavigationCoordinator

@Observable
class NavigationCoordinator {
    var navigationPath: [Any] = []
    var onTripSelected: ((Trip) -> Void)?
    var onOrganizationSelected: ((Organization) -> Void)?
    
    func navigateToTrip(_ trip: Trip, fromTab: Int, toTab: Int) {
        onTripSelected?(trip)
    }
    
    func navigateToOrganization(_ organization: Organization) {
        onOrganizationSelected?(organization)
    }
    
    func pushToPath<T>(_ item: T) {
        navigationPath.append(item)
    }
    
    func clearNavigationPath() {
        navigationPath.removeAll()
    }
    
    func handleItemSelection<Item: NavigationItem>(_ item: Item) {
        // Handle specific item type selection
        if let trip = item as? Trip {
            onTripSelected?(trip)
        } else if let organization = item as? Organization {
            onOrganizationSelected?(organization)
        }
    }
}