import SwiftUI
import SwiftData

// A simple navigation view that doesn't use NavigationSplitView
struct SimpleNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @State private var selectedTripID: UUID?
    @State private var searchText = ""
    @State private var showingAddTrip = false
    
    var filteredTrips: [Trip] {
        guard !searchText.isEmpty else { return trips }
        return trips.filter { trip in
            trip.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search trips...")
                    .padding(.top, 8)
                
                // Trip list or detail
                if let selectedTripID = selectedTripID,
                   let selectedTrip = trips.first(where: { $0.id == selectedTripID }) {
                    // Detail view - use modified IsolatedTripDetailView that fetches internally
                    IsolatedTripDetailView(trip: selectedTrip)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Back") {
                                    self.selectedTripID = nil
                                }
                            }
                        }
                } else {
                    // List view
                    if filteredTrips.isEmpty {
                        ContentUnavailableView(
                            "No Trips",
                            systemImage: "airplane",
                            description: Text("Create your first trip to get started")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        tripsList
                    }
                }
            }
            .navigationTitle(selectedTripID != nil ? "Trip Details" : "Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedTripID == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddTrip) {
                AddTrip()
            }
        }
    }
    
    @ViewBuilder
    private var tripsList: some View {
        List(filteredTrips) { trip in
            SimpleTripRowView(trip: trip) {
                selectedTripID = trip.id
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        }
        .listStyle(.plain)
        .scrollContentBackground(.visible)
    }
}

// Simple search bar component
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// Simple trip row component
struct SimpleTripRowView: View {
    let trip: Trip
    let onTap: () -> Void
    private let authManager = BiometricAuthManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
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
                
                // Badge and chevron
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
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
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
        .buttonStyle(.plain)
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



#Preview {
    SimpleNavigationView()
}