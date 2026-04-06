//
//  DatabaseBrowserTab.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

// MARK: - Database Browser Tab
struct DatabaseBrowserTab: View {
    @FetchAll private var tripRecords: [Trip]
    @FetchAll private var transportationRecords: [Transportation]
    @FetchAll private var lodging: [Lodging]
    @FetchAll private var activities: [Activity]
    @FetchAll private var organizationRecords: [Organization]
    @FetchAll private var addresses: [Address]
    @FetchAll private var attachments: [EmbeddedFileAttachment]

    @Bindable var store: StoreOf<DatabaseBrowserFeature>
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
            Picker("Section", selection: $store.selectedSection) {
                ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                    Text(section).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Search Bar
            SearchBarView(text: $store.searchText, placeholder: "Search \(sections[store.selectedSection].lowercased())...")
                .padding(.horizontal)

            // Content List
            List {
                switch store.selectedSection {
                case 0: // Trips
                    ForEach(filteredTrips, id: \.id) { trip in
                        Button {
                            selectedItem = .trip(trip)
                        } label: {
                            TripRowView(trip: trip)
                        }
                        .foregroundStyle(.primary)
                    }

                case 1: // Transportation
                    ForEach(filteredTransportation, id: \.id) { item in
                        Button {
                            selectedItem = .transportation(item)
                        } label: {
                            TransportationRowView(transportation: item)
                        }
                        .foregroundStyle(.primary)
                    }

                case 2: // Lodging
                    ForEach(filteredLodging, id: \.id) { item in
                        Button {
                            selectedItem = .lodging(item)
                        } label: {
                            LodgingRowView(lodging: item)
                        }
                        .foregroundStyle(.primary)
                    }

                case 3: // Activities
                    ForEach(filteredActivities, id: \.id) { item in
                        Button {
                            selectedItem = .activity(item)
                        } label: {
                            NewActivityRowView(activity: item)
                        }
                        .foregroundStyle(.primary)
                    }

                case 4: // Organizations
                    ForEach(filteredOrganizations, id: \.id) { item in
                        Button {
                            selectedItem = .organization(item)
                        } label: {
                            NewOrganizationRowView(organization: item)
                        }
                        .foregroundStyle(.primary)
                    }

                case 5: // Addresses
                    ForEach(filteredAddresses, id: \.id) { item in
                        Button {
                            selectedItem = .address(item)
                        } label: {
                            AddressRowView(address: item)
                        }
                        .foregroundStyle(.primary)
                    }

                case 6: // Attachments
                    ForEach(filteredAttachments, id: \.id) { item in
                        Button {
                            selectedItem = .attachment(item)
                        } label: {
                            AttachmentRowView(attachment: item)
                        }
                        .foregroundStyle(.primary)
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
        if store.searchText.isEmpty {
            return tripRecords.sorted { $0.name < $1.name }
        }
        return tripRecords.filter {
            $0.name.localizedStandardContains(store.searchText) ||
            $0.notes.localizedStandardContains(store.searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredTransportation: [Transportation] {
        if store.searchText.isEmpty {
            return transportationRecords.sorted { $0.name < $1.name }
        }
        return transportationRecords.filter {
            $0.name.localizedStandardContains(store.searchText) ||
            $0.confirmation.localizedStandardContains(store.searchText) ||
            $0.notes.localizedStandardContains(store.searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredLodging: [Lodging] {
        if store.searchText.isEmpty {
            return lodging.sorted { $0.name < $1.name }
        }
        return lodging.filter {
            $0.name.localizedStandardContains(store.searchText) ||
            $0.reservation.localizedStandardContains(store.searchText) ||
            $0.notes.localizedStandardContains(store.searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredActivities: [Activity] {
        if store.searchText.isEmpty {
            return activities.sorted { $0.name < $1.name }
        }
        return activities.filter {
            $0.name.localizedStandardContains(store.searchText) ||
            $0.reservation.localizedStandardContains(store.searchText) ||
            $0.notes.localizedStandardContains(store.searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredOrganizations: [Organization] {
        if store.searchText.isEmpty {
            return organizationRecords.sorted { $0.name < $1.name }
        }
        return organizationRecords.filter {
            $0.name.localizedStandardContains(store.searchText) ||
            $0.email.localizedStandardContains(store.searchText) ||
            $0.website.localizedStandardContains(store.searchText)
        }.sorted { $0.name < $1.name }
    }

    private var filteredAddresses: [Address] {
        if store.searchText.isEmpty {
            return addresses.sorted { $0.displayAddress < $1.displayAddress }
        }
        return addresses.filter {
            $0.displayAddress.localizedStandardContains(store.searchText) ||
            $0.street.localizedStandardContains(store.searchText) ||
            $0.city.localizedStandardContains(store.searchText)
        }.sorted { $0.displayAddress < $1.displayAddress }
    }

    private var filteredAttachments: [EmbeddedFileAttachment] {
        if store.searchText.isEmpty {
            return attachments.sorted { $0.originalFileName < $1.originalFileName }
        }
        return attachments.filter {
            $0.originalFileName.localizedStandardContains(store.searchText) ||
            $0.fileDescription.localizedStandardContains(store.searchText)
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
                    .clipShape(.rect(cornerRadius: 4))
            }

            if !trip.notes.isEmpty {
                Text(trip.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("Created: \(trip.createdDate, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(trip.totalCost, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
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
                    .foregroundStyle(.blue)

                Text(transportation.name.isEmpty ? "Unnamed Transportation" : transportation.name)
                    .font(.headline)

                Spacer()

                Text(transportation.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 4))
            }

            HStack {
                Text(transportation.startFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(transportation.endFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let trip = transportation.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                    .foregroundStyle(.indigo)

                Text(lodging.name.isEmpty ? "Unnamed Lodging" : lodging.name)
                    .font(.headline)

                Spacer()

                let startDay = Calendar.current.startOfDay(for: lodging.start)
                let endDay = Calendar.current.startOfDay(for: lodging.end)
                let nights = Calendar.current.dateComponents([.day], from: startDay, to: endDay).day ?? 0
                Text("\(nights) night\(nights == 1 ? "" : "s")")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.indigo.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 4))
            }

            HStack {
                Text("Check-in: \(lodging.startFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let trip = lodging.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                    .foregroundStyle(.purple)

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
                    .clipShape(.rect(cornerRadius: 4))
            }

            HStack {
                Text(activity.startFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let trip = activity.trip {
                    Text("Trip: \(trip.name)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("No trip")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                    .foregroundStyle(.red)

                Text(organization.name.isEmpty ? "Unnamed Organization" : organization.name)
                    .font(.headline)

                Spacer()

                if organization.isNone {
                    Text("System")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 4))
                }
            }

            HStack {
                if organization.hasPhone {
                    Image(systemName: "phone.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if organization.hasEmail {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if organization.hasWebsite {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                let totalUsage = (organization.transportation.count) +
                               (organization.lodging.count) +
                               (organization.activity.count)
                Text("Used by \(totalUsage) activities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.cyan)

                Text(address.displayAddress.isEmpty ? "Empty Address" : address.displayAddress)
                    .font(.headline)

                Spacer()
            }

            HStack {
                if let coordinate = address.coordinate {
                    Text("Lat: \(coordinate.latitude, specifier: "%.4f"), Lng: \(coordinate.longitude, specifier: "%.4f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No coordinates")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer()

                let usageCount = address.organizations.count +
                    address.activities.count +
                    address.lodgings.count
                Text("Used by \(usageCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.brown)

                Text(attachment.displayName.isEmpty ? "Unnamed File" : attachment.displayName)
                    .font(.headline)

                Spacer()

                Text(attachment.fileExtension.uppercased())
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.brown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 4))
            }

            HStack {
                Text(attachment.formattedFileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(attachment.createdDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if attachment.activity != nil {
                    Text("Activity")
                        .font(.caption)
                        .foregroundStyle(.purple)
                } else if attachment.lodging != nil {
                    Text("Lodging")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                } else if attachment.transportation != nil {
                    Text("Transportation")
                        .font(.caption)
                        .foregroundStyle(.blue)
                } else {
                    Text("Orphaned")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
                .foregroundStyle(.blue)

            content
        }
        .padding()
        .background(Color.systemGray6)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}
