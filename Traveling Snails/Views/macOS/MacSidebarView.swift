//
//  MacSidebarView.swift
//  Traveling Snails
//
//  Sidebar navigation for the native macOS layout.
//

#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct MacSidebarView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        let selectedTab = store.state.navigation.selectedTab

        List(selection: Binding(
            get: { selectedTab },
            set: { newTab in
                if let newTab {
                    store.send(.navigation(.selectTab(newTab)))
                }
            }
        )) {
            Section("Library") {
                Label("Trips", systemImage: "airplane")
                    .tag(AppFeature.AppTab.trips)

                Label("Collections", systemImage: "square.stack")
                    .tag(AppFeature.AppTab.collections)

                Label("Organizations", systemImage: "building.2")
                    .tag(AppFeature.AppTab.organizations)
            }

            Section {
                Label("Settings", systemImage: "gear")
                    .tag(AppFeature.AppTab.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Traveling Snails")
    }
}
#endif
