//
//  ContentView.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @Query private var organizations: [Organization]
    
    // App settings for color scheme
    @Environment(AppSettings.self) private var appSettings
    
    // Navigation state
    @State private var selectedTab = 0
    @State private var selectedTrip: Trip?
    private let navigationContext = NavigationContext.shared
    
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
        .preferredColorScheme(appSettings.colorScheme.colorScheme)
        .environment(navigationContext)
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab != newTab {
                print("📱 ContentView: Using NavigationContext instance: \(ObjectIdentifier(navigationContext))")
                print("📱 ContentView: selectedTrip = \(selectedTrip?.name ?? "nil")")
                navigationContext.markTabSwitch(to: newTab, from: oldTab)
                print("📱 ContentView: Tab changed from \(oldTab) to \(newTab)")
            }
        }
        .onChange(of: selectedTrip) { oldTrip, newTrip in
            print("📱 ContentView: selectedTrip changed from '\(oldTrip?.name ?? "nil")' to '\(newTrip?.name ?? "nil")'")
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        #if os(iOS)
        // Use TabView for both iPhone and iPad
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
        TripsNavigationView(
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: 0
        )
    }
    
    private var organizationsTab: some View {
        OrganizationsNavigationView(
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: 1
        )
    }
    
    private var settingsTab: some View {
        SettingsRootView()
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

// MARK: - Query-Based Navigation Wrappers

struct TripsNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @Binding var selectedTab: Int
    @Binding var selectedTrip: Trip?
    let tabIndex: Int
    
    init(selectedTab: Binding<Int>, selectedTrip: Binding<Trip?>, tabIndex: Int) {
        self._selectedTab = selectedTab
        self._selectedTrip = selectedTrip
        self.tabIndex = tabIndex
    }
    
    var body: some View {
        UnifiedNavigationView.trips(
            trips: trips,
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: tabIndex
        )
    }
}

struct OrganizationsNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var organizations: [Organization]
    @Binding var selectedTab: Int
    @Binding var selectedTrip: Trip?
    let tabIndex: Int
    
    init(selectedTab: Binding<Int>, selectedTrip: Binding<Trip?>, tabIndex: Int) {
        self._selectedTab = selectedTab
        self._selectedTrip = selectedTrip
        self.tabIndex = tabIndex
    }
    
    var body: some View {
        UnifiedNavigationView.organizations(
            organizations: organizations,
            selectedTab: $selectedTab,
            selectedTrip: $selectedTrip,
            tabIndex: tabIndex
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Trip.self, Organization.self])
}