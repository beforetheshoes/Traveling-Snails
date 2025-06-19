import SwiftUI
import SwiftData

// NavigationSplitView-based trip navigation with proper SwiftData patterns
struct NavigationSplitTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var selectedTripID: Trip.ID?
    @State private var searchText = ""
    @State private var showingAddTrip = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    var filteredTrips: [Trip] {
        guard !searchText.isEmpty else { return trips }
        return trips.filter { trip in
            trip.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var selectedTrip: Trip? {
        guard let selectedTripID = selectedTripID else { return nil }
        return trips.first { $0.id == selectedTripID }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            tripSidebar
                .navigationTitle("Trips")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        } detail: {
            // Detail
            if let selectedTrip = selectedTrip {
                // Use the same IsolatedTripDetailView that works correctly
                IsolatedTripDetailView(trip: selectedTrip)
            } else {
                TripSelectionPlaceholder()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAddTrip) {
            AddTrip()
        }
    }
    
    @ViewBuilder
    private var tripSidebar: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBar(text: $searchText, placeholder: "Search trips...")
                .padding(.horizontal)
                .padding(.top, 8)
            
            // Trip list
            if filteredTrips.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "No Trips",
                        systemImage: "airplane",
                        description: Text("Create your first trip to get started")
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                List(filteredTrips, selection: $selectedTripID) { trip in
                    NavigationSplitTripRowView(trip: trip)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                }
                .listStyle(.plain)
                .scrollContentBackground(.visible)
            }
        }
    }
}

// Trip row for NavigationSplitView (no custom tap handling needed)
struct NavigationSplitTripRowView: View {
    let trip: Trip
    private let authManager = BiometricAuthManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "airplane")
                    .foregroundStyle(.blue)
                    .font(.system(size: 20, weight: .medium))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name.isEmpty ? "Untitled Trip" : trip.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                if let subtitle = tripSubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Badge
            HStack(spacing: 8) {
                // Biometric protection indicator
                if authManager.isEnabled && authManager.isProtected(trip) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Protected with biometric authentication")
                }
                
                if trip.totalActivities > 0 {
                    Text("\(trip.totalActivities)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue, in: Capsule())
                        .accessibilityLabel("\(trip.totalActivities) items")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
        )
        .contentShape(Rectangle())
    }
    
    private var tripSubtitle: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        if trip.hasDateRange {
            let start = formatter.string(from: trip.startDate)
            let end = formatter.string(from: trip.endDate)
            return "\(start) - \(end)"
        } else if trip.hasStartDate {
            return "Starts \(formatter.string(from: trip.startDate))"
        } else if trip.hasEndDate {
            return "Ends \(formatter.string(from: trip.endDate))"
        } else {
            return "No dates set"
        }
    }
}

// Placeholder for when no trip is selected
struct TripSelectionPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Select a Trip",
            systemImage: "airplane",
            description: Text("Choose a trip from the sidebar to view its details")
        )
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationSplitTripView()
}