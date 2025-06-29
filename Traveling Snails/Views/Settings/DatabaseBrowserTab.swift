//
//  DatabaseBrowserTab.swift
//  Traveling Snails
//
//

import SwiftData
import SwiftUI

// MARK: - Database Browser Tab
struct DatabaseBrowserTab: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @Query private var transportation: [Transportation]
    @Query private var lodging: [Lodging]
    @Query private var activities: [Activity]
    @Query private var organizations: [Organization]
    @Query private var addresses: [Address]
    @Query private var attachments: [EmbeddedFileAttachment]

    @State private var selectedSection = 0
    @State private var searchText = ""
    @State private var selectedItem: DatabaseItem?

    enum DatabaseItem: Identifiable {
        case trip(Trip)
        case transportation(Transportation)
        case lodging(Lodging)
        case activity(Activity)
        case organization(Organization)
        case address(Address)
        case attachment(EmbeddedFileAttachment)

        var id: String {
            switch self {
            case .trip(let item): return "trip-\(item.id)"
            case .transportation(let item): return "transportation-\(item.id)"
            case .lodging(let item): return "lodging-\(item.id)"
            case .activity(let item): return "activity-\(item.id)"
            case .organization(let item): return "organization-\(item.id)"
            case .address(let item): return "address-\(item.id)"
            case .attachment(let item): return "attachment-\(item.id)"
            }
        }
    }

    private let sections = ["Trips", "Transportation", "Lodging", "Activities", "Organizations", "Addresses", "Attachments"]

    var body: some View {
        VStack {
            // Section Picker
            Picker("Section", selection: $selectedSection) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    Text(section).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Search Bar
            UnifiedSearchBar(text: $searchText, placeholder: "Search \(sections[selectedSection].lowercased())...")
                .padding(.horizontal)

            // Content List
            List {
                switch selectedSection {
                case 0: // Trips
                    ForEach(filteredTrips, id: \.id) { trip in
                        Button {
                            selectedItem = .trip(trip)
                        } label: {
                            TripRowView(trip: trip)
                        }
                        .foregroundColor(.primary)
                    }

                case 1: // Transportation
                    ForEach(filteredTransportation, id: \.id) { item in
                        Button {
                            selectedItem = .transportation(item)
                        } label: {
                            TransportationRowView(transportation: item)
                        }
                        .foregroundColor(.primary)
                    }

                case 2: // Lodging
                    ForEach(filteredLodging, id: \.id) { item in
                        Button {
                            selectedItem = .lodging(item)
                        } label: {
                            LodgingRowView(lodging: item)
                        }
                        .foregroundColor(.primary)
                    }

                case 3: // Activities
                    ForEach(filteredActivities, id: \.id) { item in
                        Button {
                            selectedItem = .activity(item)
                        } label: {
                            NewActivityRowView(activity: item)
                        }
                        .foregroundColor(.primary)
                    }

                case 4: // Organizations
                    ForEach(filteredOrganizations, id: \.id) { item in
                        Button {
                            selectedItem = .organization(item)
                        } label: {
                            NewOrganizationRowView(organization: item)
                        }
                        .foregroundColor(.primary)
                    }

                case 5: // Addresses
                    ForEach(filteredAddresses, id: \.id) { item in
                        Button {
                            selectedItem = .address(item)
                        } label: {
                            AddressRowView(address: item)
                        }
                        .foregroundColor(.primary)
                    }

                case 6: // Attachments
                    ForEach(filteredAttachments, id: \.id) { item in
                        Button {
                            selectedItem = .attachment(item)
                        } label: {
                            AttachmentRowView(attachment: item)
                        }
                        .foregroundColor(.primary)
                    }

                default:
                    EmptyView()
                }
            }
            .listStyle(.plain)
        }
        .sheet(item: $selectedItem) { item in
            DatabaseItemDetailView(item: item)
        }
    }

    // MARK: - Filtered Data

    private var filteredTrips: [Trip] {
        if searchText.isEmpty {
            return trips.sorted { $0.name < $1.name }
        }
        return trips.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredTransportation: [Transportation] {
        if searchText.isEmpty {
            return transportation.sorted { $0.name < $1.name }
        }
        return transportation.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.confirmation.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredLodging: [Lodging] {
        if searchText.isEmpty {
            return lodging.sorted { $0.name < $1.name }
        }
        return lodging.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.reservation.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredActivities: [Activity] {
        if searchText.isEmpty {
            return activities.sorted { $0.name < $1.name }
        }
        return activities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.reservation.localizedCaseInsensitiveContains(searchText) ||
            $0.notes.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return organizations.sorted { $0.name < $1.name }
        }
        return organizations.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.website.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredAddresses: [Address] {
        if searchText.isEmpty {
            return addresses.sorted { $0.displayAddress < $1.displayAddress }
        }
        return addresses.filter {
            $0.displayAddress.localizedCaseInsensitiveContains(searchText) ||
            $0.street.localizedCaseInsensitiveContains(searchText) ||
            $0.city.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.displayAddress < $1.displayAddress }
    }

    private var filteredAttachments: [EmbeddedFileAttachment] {
        if searchText.isEmpty {
            return attachments.sorted { $0.originalFileName < $1.originalFileName }
        }
        return attachments.filter {
            $0.originalFileName.localizedCaseInsensitiveContains(searchText) ||
            $0.fileDescription.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.originalFileName < $1.originalFileName }
    }
}

// MARK: - Row Views

private struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.name.isEmpty ? "Unnamed Trip" : trip.name)
                    .font(.headline)

                Spacer()

                Text("\(trip.totalActivities) activities")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("Created: \(trip.createdDate, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(trip.totalCost, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct TransportationRowView: View {
    let transportation: Transportation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: transportation.type.systemImage)
                    .foregroundColor(.blue)

                Text(transportation.name.isEmpty ? "Unnamed Transportation" : transportation.name)
                    .font(.headline)

                Spacer()

                Text(transportation.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Text(transportation.startFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(transportation.endFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let trip = transportation.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LodgingRowView: View {
    let lodging: Lodging

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.indigo)

                Text(lodging.name.isEmpty ? "Unnamed Lodging" : lodging.name)
                    .font(.headline)

                Spacer()

                let nights = Calendar.current.dateComponents([.day], from: lodging.start, to: lodging.end).day ?? 0
                Text("\(nights) night\(nights == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.indigo.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Text("Check-in: \(lodging.startFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let trip = lodging.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct NewActivityRowView: View {
    let activity: Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(.purple)

                Text(activity.name.isEmpty ? "Unnamed Activity" : activity.name)
                    .font(.headline)

                Spacer()

                let duration = activity.duration()
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                Text("\(hours)h \(minutes)m")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.purple.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Text(activity.startFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if let trip = activity.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct NewOrganizationRowView: View {
    let organization: Organization

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "building.2.fill")
                    .foregroundColor(.red)

                Text(organization.name.isEmpty ? "Unnamed Organization" : organization.name)
                    .font(.headline)

                Spacer()

                if organization.isNone {
                    Text("System")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            HStack {
                if organization.hasPhone {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if organization.hasEmail {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                if organization.hasWebsite {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()

                let totalUsage = (organization.transportation.count) +
                               (organization.lodging.count) +
                               (organization.activity.count)
                Text("Used by \(totalUsage) activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddressRowView: View {
    let address: Address

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.cyan)

                Text(address.displayAddress.isEmpty ? "Empty Address" : address.displayAddress)
                    .font(.headline)

                Spacer()
            }

            HStack {
                if let coordinate = address.coordinate {
                    Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lng: \(coordinate.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No coordinates")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()

                let usageCount = (address.organizations?.count ?? 0) +
                (address.activities?.count ?? 0) +
                (address.lodgings?.count ?? 0)
                Text("Used by \(usageCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AttachmentRowView: View {
    let attachment: EmbeddedFileAttachment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: attachment.systemIcon)
                    .foregroundColor(.brown)

                Text(attachment.displayName.isEmpty ? "Unnamed File" : attachment.displayName)
                    .font(.headline)

                Spacer()

                Text(attachment.fileExtension.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.brown.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Text(attachment.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(attachment.createdDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if attachment.activity != nil {
                    Text("Activity")
                        .font(.caption)
                        .foregroundColor(.purple)
                } else if attachment.lodging != nil {
                    Text("Lodging")
                        .font(.caption)
                        .foregroundColor(.indigo)
                } else if attachment.transportation != nil {
                    Text("Transportation")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Orphaned")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct DatabaseItemDetailView: View {
    let item: DatabaseBrowserTab.DatabaseItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch item {
        case .trip(let trip):
            GenericDetailView(item: trip, title: "Trip Details")
        case .transportation(let transportation):
            GenericDetailView(item: transportation, title: "Transportation Details")
        case .lodging(let lodging):
            GenericDetailView(item: lodging, title: "Lodging Details")
        case .activity(let activity):
            GenericDetailView(item: activity, title: "Activity Details")
        case .organization(let organization):
            GenericDetailView(item: organization, title: "Organization Details")
        case .address(let address):
            GenericDetailView(item: address, title: "Address Details")
        case .attachment(let attachment):
            GenericDetailView(item: attachment, title: "Attachment Details")
        }
    }
}

// MARK: - Helper Views
struct DetailCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.blue)

            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}
