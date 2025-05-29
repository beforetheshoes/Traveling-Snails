//
//  ContentView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/24/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TripsNavigationView(selectedTab: $selectedTab, tabIndex: 0)
                .tabItem {
                    Image(systemName: "suitcase")
                    Text("My Trips")
                }
                .tag(0)
            
            OrganizationsNavigationView(selectedTab: $selectedTab, tabIndex: 1)
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Organizations")
                }
                .tag(1)
        }
    }
}

#Preview {
    ContentView()
}
