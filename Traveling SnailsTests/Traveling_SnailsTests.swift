//
//  Traveling_SnailsTests.swift
//  Traveling SnailsTests
//
//  Created by Ryan Williams on 5/24/25.
//

import Testing
@testable import Traveling_Snails

struct Traveling_SnailsTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func organizationInitialization() async throws {
        let org = Organization(name: "Test Org")
        #expect(org.name == "Test Org")
        #expect(org.phone == "")
        #expect(org.email == "")
        #expect(org.website == "")
        #expect(org.logoURL == "")
        #expect(org.cachedLogoFilename == "")
        // Check that address has default values
        #expect(org.address.street == "")
        #expect(org.address.city == "")
        #expect(org.address.state == "")
        #expect(org.address.country == "")
        #expect(org.address.postalCode == "")
        #expect(org.address.latitude == 0.0)
        #expect(org.address.longitude == 0.0)
        #expect(org.address.formattedAddress == "")
        #expect(org.transportation.isEmpty)
        #expect(org.lodging.isEmpty)
    }

    @Test func organizationFullInitialization() async throws {
        let address = Address(street: "123 Main St", city: "Townsville", state: "TS", country: "Country", postalCode: "12345", latitude: 1.23, longitude: 4.56, formattedAddress: "123 Main St, Townsville, TS, Country, 12345")
        let org = Organization(
            name: "Full Org",
            phone: "555-1234",
            email: "test@example.com",
            website: "https://example.com",
            logoURL: "https://logo.com/logo.png",
            cachedLogoFilename: "logo.png",
            address: address
        )
        #expect(org.name == "Full Org")
        #expect(org.phone == "555-1234")
        #expect(org.email == "test@example.com")
        #expect(org.website == "https://example.com")
        #expect(org.logoURL == "https://logo.com/logo.png")
        #expect(org.cachedLogoFilename == "logo.png")
        #expect(org.address === address)
    }

    @Test func organizationComputedProperties() async throws {
        let org = Organization(name: "Test", phone: "123", email: "a@b.com", website: "site.com", logoURL: "logo", address: Address(street: "A"))
        #expect(org.hasPhone)
        #expect(org.hasEmail)
        #expect(org.hasWebsite)
        #expect(org.hasLogoURL)
        #expect(org.hasAddress)

        let emptyOrg = Organization(name: "Empty")
        #expect(!emptyOrg.hasPhone)
        #expect(!emptyOrg.hasEmail)
        #expect(!emptyOrg.hasWebsite)
        #expect(!emptyOrg.hasLogoURL)
        #expect(!emptyOrg.hasAddress)
    }

    @Test func addressDefaultValues() async throws {
        let address = Address()
        #expect(address.street == "")
        #expect(address.city == "")
        #expect(address.state == "")
        #expect(address.country == "")
        #expect(address.postalCode == "")
        #expect(address.latitude == 0.0)
        #expect(address.longitude == 0.0)
        #expect(address.formattedAddress == "")
    }

}
