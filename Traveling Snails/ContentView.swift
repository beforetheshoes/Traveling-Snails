//
//  ContentView.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

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

    // Remote change detection
    @State private var syncTimer: Timer?
    @Environment(SyncManager.self) private var syncManager
    @Environment(\.scenePhase) private var scenePhase

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
                Logger.shared.debug("Using NavigationContext instance: \(ObjectIdentifier(navigationContext))", category: .navigation)
                Logger.shared.debug("selectedTrip = \(selectedTrip?.name ?? "nil")", category: .navigation)
                navigationContext.markTabSwitch(to: newTab, from: oldTab)
                Logger.shared.info("Tab changed from \(oldTab) to \(newTab)", category: .navigation)
            }
        }
        .onChange(of: selectedTrip) { oldTrip, newTrip in
            Logger.shared.debug("selectedTrip changed from '\(oldTrip?.name ?? "nil")' to '\(newTrip?.name ?? "nil")'")
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearTripSelection)) { _ in
            // Clear the selected trip to return to trip list (crucial for iPhone TabView navigation)
            Logger.shared.debug("Received clearTripSelection notification", category: .navigation)
            Logger.shared.debug("Current selectedTrip: \(selectedTrip?.name ?? "nil")", category: .navigation)
            selectedTrip = nil
            Logger.shared.debug("Cleared selectedTrip for TabView navigation", category: .navigation)
        }
        .onAppear {
            startPeriodicSyncCheck()
        }
        .onDisappear {
            stopPeriodicSyncCheck()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Logger.shared.info("App became active, triggering sync check", category: .sync)
                // Trigger sync when app becomes active to catch any missed remote changes
                syncManager.triggerSync()
            }
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

    // MARK: - Periodic Sync Check

    private func startPeriodicSyncCheck() {
        // Enable periodic sync check on both iPad and iPhone to ensure reliable sync
        #if os(iOS)
        let deviceType = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        let interval: TimeInterval = UIDevice.current.userInterfaceIdiom == .pad ? 30.0 : 45.0 // iPad syncs more frequently

        Logger.shared.info("Starting periodic sync check on \(deviceType) (every \(interval)s)", category: .sync)
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Logger.shared.debug("Periodic sync check triggered on \(deviceType)", category: .sync)
            syncManager.triggerSync()
        }
        #endif
    }

    private func stopPeriodicSyncCheck() {
        syncTimer?.invalidate()
        syncTimer = nil
        Logger.shared.debug("Stopped periodic sync check", category: .sync)
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
