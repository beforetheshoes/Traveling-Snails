//
//  Organization.swift
//  Traveling Snails
//
//

import Foundation
import SwiftUI
import SwiftData

@Model
class Organization: Identifiable {
    var id = UUID()
    var name: String = ""
    var phone: String = ""
    var email: String = ""
    var website: String = ""
    var logoURL: String = ""
    var cachedLogoFilename: String = ""
    
    @Relationship(deleteRule: .cascade, inverse: \Address.organizations)
    var address: Address? = nil
    
    // CLOUDKIT REQUIRED: Optional relationships with SAFE accessors
    @Relationship(deleteRule: .nullify, inverse: \Transportation.organization)
    private var _transportation: [Transportation]? = nil

    @Relationship(deleteRule: .nullify, inverse: \Lodging.organization)
    private var _lodging: [Lodging]? = nil

    @Relationship(deleteRule: .nullify, inverse: \Activity.organization)
    private var _activity: [Activity]? = nil
   
    // SAFE ACCESSORS: Never return nil
    var transportation: [Transportation] {
        get { _transportation ?? [] }
        set { _transportation = newValue.isEmpty ? nil : newValue }
    }
   
    var lodging: [Lodging] {
        get { _lodging ?? [] }
        set { _lodging = newValue.isEmpty ? nil : newValue }
    }
   
    var activity: [Activity] {
        get { _activity ?? [] }
        set { _activity = newValue.isEmpty ? nil : newValue }
    }

    init(
        name: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        logoURL: String = "",
        cachedLogoFilename: String = "",
        address: Address? = nil
    ) {
        self.name = name
        self.phone = phone
        self.email = email
        self.website = website
        self.logoURL = logoURL
        self.cachedLogoFilename = cachedLogoFilename
        self.address = address ?? Address()
    }
    
    var isNone: Bool { name == "None" }
    var hasPhone: Bool { !phone.isEmpty }
    var hasEmail: Bool { !email.isEmpty }
    var hasWebsite: Bool { !website.isEmpty }
    var hasLogoURL: Bool { !logoURL.isEmpty }
    var hasAddress: Bool { address?.isEmpty == false }

    var hasTransportation: Bool { !transportation.isEmpty }
    var hasLodging: Bool { !lodging.isEmpty }
    var hasActivity: Bool { !activity.isEmpty }

    // Helper method to check if organization can be deleted
    var canBeDeleted: Bool {
        if isNone { return false } // Never delete None organization
        return transportation.isEmpty && lodging.isEmpty && activity.isEmpty
    }

    static func cleanupDuplicateNoneOrganizations(in context: ModelContext) {
        switch OrganizationManager.shared.ensureNoneOrganization(in: context) {
        case .success:
            print("✅ Successfully ensured None organization consistency")
        case .failure(let error):
            print("❌ Error cleaning up duplicate 'None' organizations: \(error.localizedDescription)")
        }
    }
    
/// Ensure there's exactly one None organization - delegates to OrganizationManager
    static func ensureUniqueNoneOrganization(in context: ModelContext) -> Organization {
        switch OrganizationManager.shared.ensureNoneOrganization(in: context) {
        case .success(let org):
            print("✅ Successfully ensured unique None organization")
            return org
        case .failure(let error):
            print("❌ Error ensuring unique None organization: \(error.localizedDescription)")
            // Fallback: try to create one the old way
            return Organization(name: "None")
        }
    }
    
    static func createNoneOrganization(in context: ModelContext) -> Organization? {
        return getNoneOrganization(in: context)
    }
}
