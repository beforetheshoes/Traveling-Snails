//
//  RestaurantDetailView.swift
//  Traveling Snails
//

import ComposableArchitecture
import MapKit
import PhotosUI
import SwiftUI

struct RestaurantDetailView: View {
    @Bindable var store: StoreOf<RestaurantItemDetailFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        let item = store.state.restaurantItem

        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Hero Header
                HStack(alignment: .top, spacing: 16) {
                    CoverArtView(
                        imageURL: "",
                        imageData: item.coverImageData,
                        width: 120,
                        height: 120,
                        cornerRadius: 12,
                        placeholderIcon: "fork.knife",
                        imageContentMode: item.isBrandImage ? .fit : .fill
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(4)
                    }
                    .onTapGesture {
                        store.send(.coverImageTapped)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)

                        if let category = item.category, !category.isEmpty {
                            Text(category)
                                .font(.subheadline)
                                .foregroundStyle(.teal)
                        }

                        if !item.formattedLocation.isEmpty {
                            Text(item.formattedLocation)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if !item.address.isEmpty {
                            Text(item.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        StatusBadgeView(status: item.status)

                        RatingView(
                            rating: $store.restaurantItem.rating.sending(\.ratingChanged),
                            starSize: 22
                        )

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)

                // MARK: - Status Picker
                statusSection(item: item)

                // MARK: - Map
                if item.hasCoordinate {
                    mapSection(item: item)
                }

                // MARK: - Metadata
                if hasMetadata(item) {
                    metadataSection(item: item)
                }

                // MARK: - Visited Date
                if item.hasVisitedDate {
                    visitedDateSection(item: item)
                }

                // MARK: - Notes
                notesSection(item: item)

                // MARK: - Actions
                if item.hasCoordinate {
                    openInMapsButton(item: item)
                }

                // MARK: - Delete
                Button(role: .destructive) {
                    store.send(.deleteTapped)
                } label: {
                    Label("Delete Restaurant", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.top)
        }
        .navigationTitle(item.title)
        .inlineNavigationBarTitle()
        .confirmationDialog(
            "Delete Restaurant",
            isPresented: Binding(
                get: { store.state.showingDeleteConfirmation },
                set: { if !$0 { store.send(.deleteCancelled) } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
        } message: {
            Text("Are you sure you want to delete \"\(item.title)\"?")
        }
        .onAppear { store.send(.onAppear) }
        .onChange(of: store.isDeleted) { _, isDeleted in
            if isDeleted { dismiss() }
        }
        .confirmationDialog(
            "Cover Image",
            isPresented: Binding(
                get: { store.state.showingImageOptions },
                set: { if !$0 { store.send(.imageOptionsDismissed) } }
            ),
            titleVisibility: .visible
        ) {
            Button { store.send(.photoPickerTapped) } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
            Button { store.send(.pasteImageURLTapped) } label: {
                Label("Paste Image URL", systemImage: "link")
            }
            if item.coverImageData != nil {
                Button("Reset to Auto", role: .destructive) {
                    store.send(.resetCoverImageTapped)
                }
            }
        } message: {
            Text("Choose a cover image for this restaurant.")
        }
        .alert("Image URL", isPresented: Binding(
            get: { store.state.showingImageURLInput },
            set: { if !$0 { store.send(.imageURLDismissed) } }
        )) {
            TextField("https://…", text: Binding(
                get: { store.state.imageURLText },
                set: { store.send(.imageURLChanged($0)) }
            ))
            Button("Cancel", role: .cancel) { store.send(.imageURLDismissed) }
            Button("Download") { store.send(.imageURLSubmitted) }
        } message: {
            Text("Enter the URL of an image to use as the cover.")
        }
        .photosPicker(
            isPresented: Binding(
                get: { store.state.showingPhotoPicker },
                set: { if !$0 { store.send(.photoPickerDismissed) } }
            ),
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    store.send(.photoSelected(data))
                }
                selectedPhoto = nil
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func statusSection(item: RestaurantItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RestaurantStatus.allCases, id: \.self) { status in
                        Button {
                            store.send(.statusChanged(status))
                        } label: {
                            Label(status.displayName, systemImage: status.systemImage)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    item.status == status
                                        ? status.color.opacity(0.2)
                                        : Color.systemGray6
                                )
                                .foregroundStyle(
                                    item.status == status
                                        ? status.color
                                        : .secondary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func mapSection(item: RestaurantItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
                .padding(.horizontal)

            let coordinate = CLLocationCoordinate2D(
                latitude: item.latitude,
                longitude: item.longitude
            )

            Map(initialPosition: .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )) {
                Marker(item.title, coordinate: coordinate)
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func metadataSection(item: RestaurantItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            VStack(spacing: 0) {
                if let category = item.category, !category.isEmpty {
                    metadataRow(label: "Type", value: category)
                }
                if !item.cuisine.isEmpty {
                    metadataRow(label: "Cuisine", value: item.cuisine)
                }
                if !item.address.isEmpty {
                    metadataRow(label: "Address", value: item.address)
                }
                let locationParts = [item.city, item.state, item.postalCode].compactMap { $0 }.filter { !$0.isEmpty }
                if !locationParts.isEmpty {
                    metadataRow(label: "Location", value: locationParts.joined(separator: ", "))
                }
                if let country = item.country, !country.isEmpty {
                    metadataRow(label: "Country", value: country)
                }
                if !item.phone.isEmpty {
                    HStack {
                        Text("Phone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link(item.phone, destination: URL(string: "tel:\(item.phone)")!)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                if item.priceLevel > 0 {
                    metadataRow(label: "Price", value: String(repeating: "$", count: item.priceLevel))
                }
                if !item.websiteURL.isEmpty {
                    HStack {
                        Text("Website")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let url = URL(string: item.websiteURL) {
                            Link("Visit", destination: url)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                if let tz = item.timeZone, tz != .current {
                    metadataRow(label: "Time Zone", value: tz.localizedName(for: .shortGeneric, locale: .current) ?? tz.identifier)
                }
            }
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func visitedDateSection(item: RestaurantItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visit History")
                .font(.headline)

            VStack(spacing: 0) {
                if let visited = item.effectiveVisitedDate {
                    metadataRow(label: "Visited", value: visited.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .background(Color.systemGray6)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func notesSection(item: RestaurantItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button {
                    store.send(.editNotesTapped)
                } label: {
                    Image(systemName: "pencil")
                }
            }

            if store.state.isEditing {
                TextEditor(text: $store.editedNotes.sending(\.editedNotesChanged))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.systemGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Cancel") { store.send(.cancelEditNotes) }
                        .buttonStyle(.bordered)
                    Button("Save") { store.send(.saveNotesTapped) }
                        .buttonStyle(.borderedProminent)
                }
            } else if item.notes.isEmpty {
                Text("No notes yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text(item.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func openInMapsButton(item: RestaurantItem) -> some View {
        Button {
            let coordinate = CLLocationCoordinate2D(
                latitude: item.latitude,
                longitude: item.longitude
            )
            let mapItem: MKMapItem
            if #available(iOS 26.0, macOS 26.0, *) {
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let address = MKAddress(
                    fullAddress: item.address,
                    shortAddress: item.formattedLocation
                )
                mapItem = MKMapItem(location: location, address: address)
            } else {
                let placemark = MKPlacemark(coordinate: coordinate)
                mapItem = MKMapItem(placemark: placemark)
            }
            mapItem.name = item.title
            mapItem.openInMaps()
        } label: {
            Label("Open in Maps", systemImage: "map")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
    }

    private func hasMetadata(_ item: RestaurantItem) -> Bool {
        !(item.category ?? "").isEmpty || !item.cuisine.isEmpty || !item.phone.isEmpty
            || item.priceLevel > 0 || !item.websiteURL.isEmpty
            || !item.address.isEmpty || !(item.country ?? "").isEmpty
    }
}
