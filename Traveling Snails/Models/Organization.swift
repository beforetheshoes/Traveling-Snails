//
//  Organization.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct Organization: Identifiable {
    let id: UUID
    var name: String
    var phone: String
    var email: String
    var website: String
    var logoURL: String
    var cachedLogoFilename: String
    var addressID: Address.ID?

    init(
        id: UUID = UUID(),
        name: String = "",
        phone: String = "",
        email: String = "",
        website: String = "",
        logoURL: String = "",
        cachedLogoFilename: String = "",
        addressID: Address.ID? = nil
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.website = website
        self.logoURL = logoURL
        self.cachedLogoFilename = cachedLogoFilename
        self.addressID = addressID
    }

    var isNone: Bool { name == "None" }
    var hasPhone: Bool { !phone.isEmpty }
    var hasEmail: Bool { !email.isEmpty }
    var hasWebsite: Bool { !website.isEmpty }
    var hasLogoURL: Bool { !logoURL.isEmpty }
}
