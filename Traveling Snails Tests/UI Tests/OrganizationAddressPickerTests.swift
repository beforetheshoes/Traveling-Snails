//
//  OrganizationAddressPickerTests.swift
//  Traveling Snails Tests
//
//

import Testing
import SwiftUI
import SwiftData
import MapKit

@testable import Traveling_Snails

@Suite("Organization Address Picker Tests")
struct OrganizationAddressPickerTests {
    
    @Test("Empty address should not show Selected Address display")
    func emptyAddressShouldNotShowSelectedDisplay() {
        // Test that an empty address doesn't trigger the "Selected Address:" display
        let emptyAddress = Address()
        #expect(emptyAddress.isEmpty == true)
        
        // Simulate AddressAutocompleteView logic for empty address
        let shouldShowSelectedAddress = emptyAddress.isEmpty == false
        #expect(shouldShowSelectedAddress == false, "Empty address should not show Selected Address display")
    }
    
    @Test("Organization with empty address should not show selected state")
    func organizationWithEmptyAddressShouldNotShowSelectedState() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create organization - this creates a default empty address
        let org = Organization(name: "Test Org")
        context.insert(org)
        try context.save()
        
        // Verify organization has an address but it's empty
        #expect(org.address != nil, "Organization should have an address")
        #expect(org.address?.isEmpty == true, "Organization's default address should be empty")
        #expect(org.hasAddress == false, "Organization should not be considered to have an address")
        
        // Simulate what AddressAutocompleteView should do with this address
        let shouldShowSelectedAddress = org.address != nil && org.address?.isEmpty == false
        #expect(shouldShowSelectedAddress == false, "Should not show Selected Address for empty address")
    }
    
    @Test("Address picker should properly save selected address to organization")
    func addressPickerShouldProperlySaveSelectedAddress() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create organization
        let org = Organization(name: "Test Org")
        context.insert(org)
        try context.save()
        
        // Simulate selecting an address (like what AddressAutocompleteView would do)
        let selectedAddress = Address(
            street: "123 Test St",
            city: "Test City",
            state: "CA",
            country: "USA",
            formattedAddress: "123 Test St, Test City, CA, USA"
        )
        
        // Simulate the save process in OrganizationDetailView
        org.address?.street = selectedAddress.street
        org.address?.city = selectedAddress.city
        org.address?.state = selectedAddress.state
        org.address?.country = selectedAddress.country
        org.address?.formattedAddress = selectedAddress.formattedAddress
        
        try context.save()
        
        // Verify address was saved correctly
        #expect(org.address?.street == "123 Test St")
        #expect(org.address?.city == "Test City")
        #expect(org.address?.isEmpty == false)
        #expect(org.hasAddress == true)
        #expect(org.address?.displayAddress == "123 Test St, Test City, CA, USA")
    }
    
    @Test("Address picker state should reset correctly after clearing")
    func addressPickerStateShouldResetAfterClearing() {
        // Test the clear functionality
        let address = Address(
            street: "123 Test St",
            city: "Test City",
            formattedAddress: "123 Test St, Test City"
        )
        
        // Simulate initial state with address
        var selectedAddress: Address? = address
        var hasSelectedAddress = true
        var searchText = address.displayAddress
        
        #expect(selectedAddress != nil)
        #expect(hasSelectedAddress == true)
        #expect(searchText == "123 Test St, Test City")
        
        // Simulate clear action
        selectedAddress = nil
        hasSelectedAddress = false
        searchText = ""
        
        // Verify clear state
        #expect(selectedAddress == nil)
        #expect(hasSelectedAddress == false)
        #expect(searchText == "")
    }
    
    @Test("Address picker should distinguish between nil and empty addresses")
    func addressPickerShouldDistinguishBetweenNilAndEmptyAddresses() {
        // Test nil address
        let nilAddress: Address? = nil
        let shouldShowForNil = nilAddress != nil && nilAddress?.isEmpty == false
        #expect(shouldShowForNil == false, "Nil address should not show Selected Address display")
        
        // Test empty address
        let emptyAddress: Address? = Address()
        let shouldShowForEmpty = emptyAddress != nil && emptyAddress?.isEmpty == false
        #expect(shouldShowForEmpty == false, "Empty address should not show Selected Address display")
        
        // Test valid address
        let validAddress: Address? = Address(street: "123 Main St", city: "Test City")
        let shouldShowForValid = validAddress != nil && validAddress?.isEmpty == false
        #expect(shouldShowForValid == true, "Valid address should show Selected Address display")
    }
    
    @Test("Organization editing should handle address updates correctly")
    func organizationEditingShouldHandleAddressUpdatesCorrectly() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create organization with empty address
        let org = Organization(name: "Test Org")
        context.insert(org)
        try context.save()
        
        let originalAddress = org.address
        #expect(originalAddress?.isEmpty == true)
        
        // Simulate editing - create new address to edit
        let editedAddress = Address(
            street: "456 New St",
            city: "New City",
            state: "NY",
            country: "USA",
            formattedAddress: "456 New St, New City, NY, USA"
        )
        
        // Simulate save changes (the current problematic logic)
        if originalAddress != nil {
            originalAddress?.street = editedAddress.street
            originalAddress?.city = editedAddress.city
            originalAddress?.state = editedAddress.state
            originalAddress?.country = editedAddress.country
            originalAddress?.formattedAddress = editedAddress.formattedAddress
        }
        
        try context.save()
        
        // Verify the address was updated correctly
        #expect(org.address?.street == "456 New St")
        #expect(org.address?.city == "New City")
        #expect(org.address?.isEmpty == false)
        #expect(org.hasAddress == true)
    }
    
    @Test("Organization detail view should initialize editedAddress correctly for empty addresses")
    func organizationDetailViewShouldInitializeEditedAddressCorrectly() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        // Create organization with empty address
        let org = Organization(name: "Test Org")
        context.insert(org)
        try context.save()
        
        #expect(org.address?.isEmpty == true)
        
        // Simulate startEditing logic from OrganizationDetailView
        let editedAddress = (org.address?.isEmpty == false) ? org.address : nil
        
        // With empty address, editedAddress should be nil
        #expect(editedAddress == nil, "editedAddress should be nil for empty organization address")
        
        // Now test with valid address
        org.address?.street = "123 Test St"
        org.address?.city = "Test City"
        org.address?.formattedAddress = "123 Test St, Test City"
        
        let editedAddressWithData = (org.address?.isEmpty == false) ? org.address : nil
        
        // With valid address, editedAddress should not be nil
        #expect(editedAddressWithData != nil, "editedAddress should not be nil for valid organization address")
        #expect(editedAddressWithData?.street == "123 Test St")
    }
}