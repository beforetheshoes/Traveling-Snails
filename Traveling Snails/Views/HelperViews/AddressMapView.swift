//
//  AddressMapView.swift
//  Traveling Snails
//
//

import SwiftUI
import MapKit

struct AddressMapView: View {
    let address: Address
    @State private var position: MapCameraPosition
    
    init(address: Address) {
        self.address = address
        if let coordinate = address.coordinate {
            self._position = State(initialValue: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        } else {
            self._position = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )))
        }
    }
    
    var body: some View {
        Map(position: $position) {
            if let coordinate = address.coordinate {
                Marker(
                    address.displayAddress,
                    coordinate: coordinate
                )
                .tint(.red)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
