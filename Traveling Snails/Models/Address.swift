//
//  Address.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import Foundation
import MapKit
import SwiftData

@Model
class Address: Identifiable {
    var id = UUID()
    var street: String = ""
    var city: String = ""
    var state: String = ""
    var country: String = ""
    var postalCode: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var formattedAddress: String = ""
    
    init(
        street: String = "",
        city: String = "",
        state: String = "",
        country: String = "",
        postalCode: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        formattedAddress: String = ""
    ) {
        self.street = street
        self.city = city
        self.state = state
        self.country = country
        self.postalCode = postalCode
        self.latitude = latitude
        self.longitude = longitude
        self.formattedAddress = formattedAddress
    }
    
    // Convenience initializer from MKPlacemark
    convenience init(from placemark: MKPlacemark) {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }.joined(separator: " ")
        
        self.init(
            street: street,
            city: placemark.locality ?? "",
            state: placemark.administrativeArea ?? "",
            country: placemark.country ?? "",
            postalCode: placemark.postalCode ?? "",
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude,
            formattedAddress: placemark.title ?? ""
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
        return street.isEmpty && city.isEmpty && state.isEmpty && country.isEmpty &&
               postalCode.isEmpty && formattedAddress.isEmpty
    }
}
