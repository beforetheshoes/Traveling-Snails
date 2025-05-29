//
//  Traveling_SnailsApp.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

@main
struct Traveling_SnailsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self, Lodging.self, Organization.self, Transportation.self])
    }
}
