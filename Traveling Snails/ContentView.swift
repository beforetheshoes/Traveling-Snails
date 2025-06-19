//
//  ContentView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @Query private var organizations: [Organization]
    
    // Navigation state
    @State private var selectedTab = 0
    @State private var selectedTrip: Trip?
    
    // CloudKit sync state
    @State private var isInitialSyncComplete = false
    @State private var showingSyncIndicator = false
    
    var body: some View {
        Group {
            if !isInitialSyncComplete && trips.isEmpty {
                // Show sync indicator while waiting for initial CloudKit sync
                CloudKitSyncIndicatorView(isVisible: $showingSyncIndicator)
                    .onAppear {
                        showingSyncIndicator = true
                        // Give CloudKit a moment to sync
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            await MainActor.run {
                                isInitialSyncComplete = true
                                showingSyncIndicator = false
                            }
                        }
                    }
            } else {
                mainContent
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Use TabView for iPhone (bottom tabs)
            TabView(selection: $selectedTab) {
                tripsTab
                    .tabItem {
                        Label("Trips", systemImage: "airplane")
                    }
                    .tag(0)
                
                organizationsTab
                    .tabItem {
                        Label("Organizations", systemImage: "building.2")
                    }
                    .tag(1)
                
                settingsTab
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
        } else {
            // Use custom tab bar for iPad to avoid overlap
            VStack(spacing: 0) {
                // Content area
                switch selectedTab {
                case 0:
                    tripsTab
                case 1:
                    organizationsTab
                case 2:
                    settingsTab
                default:
                    tripsTab
                }
                
                // Custom bottom tab bar
                HStack(spacing: 0) {
                    iPadTabButton(
                        title: "Trips",
                        icon: "airplane",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                    }
                    
                    iPadTabButton(
                        title: "Organizations",
                        icon: "building.2",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                    }
                    
                    iPadTabButton(
                        title: "Settings",
                        icon: "gear",
                        isSelected: selectedTab == 2
                    ) {
                        selectedTab = 2
                    }
                }
                .frame(height: 60)
                .background(.regularMaterial)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color(UIColor.separator)),
                    alignment: .top
                )
            }
        }
        #else
        // macOS - use NavigationSplitView
        NavigationSplitView {
            List {
                Button("Trips") {
                    selectedTab = 0
                }
                .listRowBackground(selectedTab == 0 ? Color.blue.opacity(0.2) : Color.clear)
                
                Button("Organizations") {
                    selectedTab = 1
                }
                .listRowBackground(selectedTab == 1 ? Color.blue.opacity(0.2) : Color.clear)
                
                Button("Settings") {
                    selectedTab = 2
                }
                .listRowBackground(selectedTab == 2 ? Color.blue.opacity(0.2) : Color.clear)
            }
            .navigationTitle("Traveling Snails")
        } detail: {
            switch selectedTab {
            case 0:
                tripsTab
            case 1:
                organizationsTab
            case 2:
                settingsTab
            default:
                tripsTab
            }
        }
        #endif
    }
    
    private var tripsTab: some View {
        UnifiedNavigationView.trips(
            trips: trips,
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: 0
        )
    }
    
    private var organizationsTab: some View {
        UnifiedNavigationView.organizations(
            organizations: organizations,
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: 1
        )
    }
    
    private var settingsTab: some View {
        SettingsRootView()
    }
    
    @ViewBuilder
    private func iPadTabButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// View shown while waiting for CloudKit sync
struct CloudKitSyncIndicatorView: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .repeating)
            
            VStack(spacing: 8) {
                Text("Syncing with iCloud")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Your trips and data are being synchronized from iCloud. This may take a moment.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            ProgressView()
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, Organization.self])
}