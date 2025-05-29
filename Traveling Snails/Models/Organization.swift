//
//  Organization.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import Foundation
import SwiftData

@Model
class Organization: Identifiable {
    var id = UUID()
    var name: String
    var phone: String = ""
    var email: String = ""
    var website: String = ""
    var logoURL: String = ""
    var cachedLogoFilename: String = ""
    
    @Relationship(deleteRule: .cascade) var address: Address = Address()
    
    @Relationship(deleteRule: .deny, inverse: \Transportation.organization) var transportation: [Transportation] = []
    @Relationship(deleteRule: .deny, inverse: \Lodging.organization) var lodging: [Lodging] = []
    
    init(
        name: String,
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
    
    var hasPhone: Bool { !phone.isEmpty }
    var hasEmail: Bool { !email.isEmpty }
    var hasWebsite: Bool { !website.isEmpty }
    var hasLogoURL: Bool { !logoURL.isEmpty }
    var hasAddress: Bool { !address.isEmpty }
}
