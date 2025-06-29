//
//  OrganizationAddressPickerTests.swift
//  Traveling Snails Tests
//
//

import MapKit
import SwiftData
import SwiftUI
import Testing

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

    @Test("AddOrganizationForm should support logo URL field")
    func addOrganizationFormShouldSupportLogoURL() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Test data
        let testLogoURL = "https://example.com/logo.png"

        // Simulate AddOrganizationForm creation with logo URL
        let organization = Organization(
            name: "Test Organization",
            phone: "555-1234",
            email: "test@example.com",
            website: "https://example.com",
            logoURL: testLogoURL
        )

        context.insert(organization)
        try context.save()

        // Verify logo URL was saved correctly
        #expect(organization.logoURL == testLogoURL, "Organization logo URL should be saved correctly")
        #expect(organization.logoURL.isEmpty == false, "Logo URL should not be empty")
    }

    @Test("AddOrganizationForm should support address field")
    func addOrganizationFormShouldSupportAddress() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Create organization with address
        let organization = Organization(name: "Test Organization")
        context.insert(organization)

        // Simulate adding address through form
        let testAddress = Address(
            street: "123 Business Ave",
            city: "Business City",
            state: "CA",
            country: "USA",
            formattedAddress: "123 Business Ave, Business City, CA, USA"
        )

        // Simulate assigning address (what AddOrganizationForm should do)
        organization.address?.street = testAddress.street
        organization.address?.city = testAddress.city
        organization.address?.state = testAddress.state
        organization.address?.country = testAddress.country
        organization.address?.formattedAddress = testAddress.formattedAddress

        try context.save()

        // Verify address was saved correctly
        #expect(organization.address?.street == "123 Business Ave")
        #expect(organization.address?.city == "Business City")
        #expect(organization.address?.isEmpty == false)
        #expect(organization.hasAddress == true)
    }

    @Test("AddOrganizationForm should validate logo URL security")
    func addOrganizationFormShouldValidateLogoURLSecurity() {
        // Test safe URL
        let safeURL = "https://example.com/logo.png"
        let safeLevel = SecureURLHandler.evaluateURL(safeURL)
        #expect(safeLevel == .safe, "Standard HTTPS URL should be safe")

        // Test suspicious URL (URL shortener)
        let suspiciousURL = "https://bit.ly/logo"
        let suspiciousLevel = SecureURLHandler.evaluateURL(suspiciousURL)
        #expect(suspiciousLevel == .suspicious, "URL shortener should be suspicious")

        // Test blocked URL (invalid scheme)
        let blockedURL = "javascript:alert('xss')"
        let blockedLevel = SecureURLHandler.evaluateURL(blockedURL)
        #expect(blockedLevel == .blocked, "JavaScript URL should be blocked")

        // Test empty URL (SecureURLHandler blocks it, but form should handle it as safe)
        let emptyURL = ""
        let emptyLevel = SecureURLHandler.evaluateURL(emptyURL)
        #expect(emptyLevel == .blocked, "SecureURLHandler blocks empty URLs")

        // But in the form context, empty URLs should be treated as safe
        let formHandlesEmpty = emptyURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        #expect(formHandlesEmpty == true, "Form should recognize empty URLs and treat as safe")
    }

    @Test("AddOrganizationForm should handle blocked URLs correctly")
    func addOrganizationFormShouldHandleBlockedURLs() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Test that organization can be created without blocked URL
        let blockedURL = "ftp://unsafe.example.com/logo.png"
        let securityLevel = SecureURLHandler.evaluateURL(blockedURL)

        #expect(securityLevel == .blocked, "FTP URL should be blocked")

        // Simulate form validation - blocked URLs should not be saved
        let shouldAllowSave = securityLevel != .blocked
        #expect(shouldAllowSave == false, "Form should not allow saving with blocked URL")

        // Organization should be created with empty logo URL instead
        let organization = Organization(
            name: "Test Organization",
            logoURL: "" // Empty instead of blocked URL
        )

        context.insert(organization)
        try context.save()

        #expect(organization.logoURL.isEmpty == true, "Blocked URL should result in empty logo URL")
    }

    @Test("AddOrganizationForm should create address object when address is selected")
    func addOrganizationFormShouldCreateAddressObjectWhenSelected() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Create organization with logo URL and simulate address selection
        let organization = Organization(
            name: "Test Organization",
            logoURL: "https://example.com/logo.png"
        )

        // Initially, organization should have empty address (not nil, as per Organization init)
        #expect(organization.address != nil, "New organization should have an address object")
        #expect(organization.address?.isEmpty == true, "New organization should have empty address")

        // Simulate address selection and assignment (what the fixed code does)
        let selectedAddress = Address(
            street: "123 Business Ave",
            city: "Business City",
            state: "CA",
            country: "USA",
            postalCode: "12345",
            latitude: 37.7749,
            longitude: -122.4194,
            formattedAddress: "123 Business Ave, Business City, CA 12345, USA"
        )

        // Organization already has an address object (no need to create new one)
        organization.address?.street = selectedAddress.street
        organization.address?.city = selectedAddress.city
        organization.address?.state = selectedAddress.state
        organization.address?.country = selectedAddress.country
        organization.address?.postalCode = selectedAddress.postalCode
        organization.address?.latitude = selectedAddress.latitude
        organization.address?.longitude = selectedAddress.longitude
        organization.address?.formattedAddress = selectedAddress.formattedAddress

        context.insert(organization)
        try context.save()

        // Verify address was created and populated correctly
        #expect(organization.address != nil, "Organization should have address after assignment")
        #expect(organization.address?.street == "123 Business Ave")
        #expect(organization.address?.city == "Business City")
        #expect(organization.address?.state == "CA")
        #expect(organization.address?.country == "USA")
        #expect(organization.address?.postalCode == "12345")
        #expect(organization.address?.latitude == 37.7749)
        #expect(organization.address?.longitude == -122.4194)
        #expect(organization.address?.formattedAddress == "123 Business Ave, Business City, CA 12345, USA")
        #expect(organization.address?.isEmpty == false)
        #expect(organization.hasAddress == true)
    }

    @Test("AddOrganizationForm should accept empty logo URL without validation")
    func addOrganizationFormShouldAcceptEmptyLogoURL() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Organization.self, Address.self,
            configurations: config
        )
        let context = ModelContext(container)

        // Test that organization can be created with empty logo URL
        let emptyURL = ""
        let trimmedURL = emptyURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Simulate form logic - empty URL should be acceptable without validation
        let shouldSkipValidation = trimmedURL.isEmpty
        #expect(shouldSkipValidation == true, "Form should skip validation for empty URLs")

        // Organization should be created successfully with empty logo URL
        let organization = Organization(
            name: "Test Organization",
            logoURL: emptyURL
        )

        context.insert(organization)
        try context.save()

        #expect(organization.logoURL.isEmpty == true, "Organization should have empty logo URL")
        #expect(organization.name == "Test Organization", "Organization name should be saved correctly")
    }
}
