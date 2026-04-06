//
//  RestaurantItem.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

@Table
nonisolated struct RestaurantItem: Hashable, Identifiable {
    let id: UUID
    var collectionID: Collection.ID
    var title: String
    var cuisine: String
    var category: String?
    var phone: String
    var address: String
    var city: String?
    var state: String?
    var postalCode: String?
    var country: String?
    var latitude: Double
    var longitude: Double
    var priceLevel: Int
    var websiteURL: String
    var timeZoneIdentifier: String?
    var coverImageData: Data?
    var coverImageType: String?
    var externalID: String
    var rating: Int
    var status: RestaurantStatus
    var visitedDate: Date
    var hasVisitedDate: Bool
    var notes: String
    var sortOrder: Int
    var createdDate: Date

    init(
        id: UUID = UUID(),
        collectionID: Collection.ID,
        title: String = "",
        cuisine: String = "",
        category: String? = nil,
        phone: String = "",
        address: String = "",
        city: String? = nil,
        state: String? = nil,
        postalCode: String? = nil,
        country: String? = nil,
        latitude: Double = 0,
        longitude: Double = 0,
        priceLevel: Int = 0,
        websiteURL: String = "",
        timeZoneIdentifier: String? = nil,
        coverImageData: Data? = nil,
        coverImageType: String? = nil,
        externalID: String = "",
        rating: Int = 0,
        status: RestaurantStatus = .wantToVisit,
        visitedDate: Date = .distantPast,
        hasVisitedDate: Bool = false,
        notes: String = "",
        sortOrder: Int = 0,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.collectionID = collectionID
        self.title = title
        self.cuisine = cuisine
        self.category = category
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.priceLevel = priceLevel
        self.websiteURL = websiteURL
        self.timeZoneIdentifier = timeZoneIdentifier
        self.coverImageData = coverImageData
        self.coverImageType = coverImageType
        self.externalID = externalID
        self.rating = rating
        self.status = status
        self.visitedDate = visitedDate
        self.hasVisitedDate = hasVisitedDate
        self.notes = notes
        self.sortOrder = sortOrder
        self.createdDate = createdDate
    }

    var effectiveVisitedDate: Date? {
        hasVisitedDate ? visitedDate : nil
    }

    mutating func setVisitedDate(_ date: Date) {
        visitedDate = date
        hasVisitedDate = true
    }

    mutating func clearVisitedDate() {
        visitedDate = .distantPast
        hasVisitedDate = false
    }

    var hasCoordinate: Bool {
        latitude != 0 || longitude != 0
    }

    var isBrandImage: Bool {
        coverImageType == "brand"
    }

    var coverImageURL: String { "" }

    var displaySubtitle: String {
        if !address.isEmpty { return address }
        if !cuisine.isEmpty { return cuisine }
        if let category, !category.isEmpty { return category }
        return ""
    }

    var formattedLocation: String {
        var parts: [String] = []
        if let city, !city.isEmpty { parts.append(city) }
        if let state, !state.isEmpty { parts.append(state) }
        if let country, !country.isEmpty, country != "United States" { parts.append(country) }
        return parts.joined(separator: ", ")
    }

    var timeZone: TimeZone? {
        guard let timeZoneIdentifier, !timeZoneIdentifier.isEmpty else { return nil }
        return TimeZone(identifier: timeZoneIdentifier)
    }
}

extension RestaurantItem: CollectionItemProtocol {
    static var collectionType: CollectionType { .restaurant }
}
