//
//  Address.swift
//  Traveling Snails
//

import Foundation
import MapKit
import SQLiteData

@Table
nonisolated struct Address: Hashable, Identifiable {
    let id: UUID
    var street: String
    var city: String
    var state: String
    var country: String
    var postalCode: String
    var latitude: Double
    var longitude: Double
    var formattedAddress: String

    init(
        id: UUID = UUID(),
        street: String = "",
        city: String = "",
        state: String = "",
        country: String = "",
        postalCode: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        formattedAddress: String = ""
    ) {
        self.id = id
        self.street = street
        self.city = city
        self.state = state
        self.country = country
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.formattedAddress = formattedAddress
    }

    @available(iOS 26.0, macOS 26.0, *)
    init(from mapItem: MKMapItem) {
        let coordinate = mapItem.location.coordinate

        if let representations = mapItem.addressRepresentations {
            self.init(
                street: mapItem.address?.shortAddress ?? "",
                city: representations.cityName ?? "",
                state: "",
                country: representations.regionName ?? "",
                postalCode: "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                formattedAddress: representations.fullAddress(includingRegion: true, singleLine: false) ?? mapItem.name ?? ""
            )
            return
        }

        self.init(
            street: mapItem.address?.shortAddress ?? "",
            city: "",
            state: "",
            country: "",
            postalCode: "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            formattedAddress: mapItem.address?.fullAddress ?? mapItem.name ?? ""
        )
    }

    var coordinate: CLLocationCoordinate2D? {
        guard latitude != 0.0 || longitude != 0.0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayAddress: String {
        if !formattedAddress.isEmpty {
            return formattedAddress
        }

        let components = [street, city, state, country].filter { !$0.isEmpty }
        return components.joined(separator: ", ")
    }

    var isEmpty: Bool {
        street.isEmpty && city.isEmpty && state.isEmpty && country.isEmpty &&
               postalCode.isEmpty && formattedAddress.isEmpty
    }
}
