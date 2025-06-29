//
//  NavigationViewModel.swift
//  Traveling Snails
//
//

import Foundation
import Observation
import SwiftUI

@Observable
class NavigationViewModel<Item: NavigationItem> {
    // MARK: - Properties

    let items: [Item]
    let configuration: NavigationConfiguration<Item>
    let tabIndex: Int
    private let coordinator: NavigationCoordinator

    // State properties
    var searchText: String = ""
    var selectedItem: Item?
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
            // Save current navigation state before clearing
            if let selected = selectedItem {
                let state = NavigationState(
                    selectedItemId: selected.id,
                    navigationPath: [],
                    currentView: createCurrentView(for: selected)
                )
                coordinator.saveNavigationState(for: tabIndex, state: state)
            }

            selectedItem = nil
            coordinator.clearNavigationPath()
        } else {
            // Restore navigation state when returning to this tab
            if let savedState = coordinator.restoreNavigationState(for: tabIndex) {
                if let itemId = savedState.selectedItemId {
                    selectedItem = items.first { $0.id == itemId }
                }
            }
        }
    }

    private func createCurrentView<NavigationItemType: NavigationItem>(for item: NavigationItemType) -> NavigationState.CurrentView? {
        if let trip = item as? Trip {
            return .tripDetail(trip.id)
        } else if let organization = item as? Organization {
            return .organizationDetail(organization.id)
        }
        return nil
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

    // Navigation state preservation
    private var savedNavigationStates: [Int: NavigationState] = [:]

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

    // Navigation state preservation methods
    func saveNavigationState(for tabIndex: Int, state: NavigationState) {
        savedNavigationStates[tabIndex] = state
    }

    func restoreNavigationState(for tabIndex: Int) -> NavigationState? {
        savedNavigationStates[tabIndex]
    }

    func clearNavigationState(for tabIndex: Int) {
        savedNavigationStates.removeValue(forKey: tabIndex)
    }
}

// MARK: - Navigation State

struct NavigationState {
    let selectedItemId: UUID?
    let navigationPath: [AnyHashable]
    let currentView: CurrentView?

    enum CurrentView {
        case tripDetail(UUID)
        case activityDetail(UUID, activityType: ActivityType)
        case organizationDetail(UUID)
    }

    enum ActivityType {
        case lodging, transportation, activity
    }
}
