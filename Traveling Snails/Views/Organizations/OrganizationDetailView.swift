//
//  OrganizationDetailView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SwiftUI

struct OrganizationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let onOpenTrip: (Trip.ID) -> Void
    @State private var store: StoreOf<OrganizationFeature>

    init(
        onOpenTrip: @escaping (Trip.ID) -> Void,
        store: StoreOf<OrganizationFeature>
    ) {
        self.onOpenTrip = onOpenTrip
        self._store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = self.store

        VStack(alignment: .leading) {
            Spacer()

            HStack {
                CachedAsyncImage(url: store.organization.logoURL, organizationId: store.organization.id)
                    .frame(width: 60, height: 60)
                    .clipShape(.rect(cornerRadius: 8))

                VStack(alignment: .leading) {
                    if store.isEditing {
                        TextField("Organization Name", text: $store.editedName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(store.organization.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Text("\(store.totalActivityCount) activities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()

            Spacer()

            List {
                ContactInfoSection(
                    isEditing: $store.isEditing,
                    editedPhone: $store.editedPhone,
                    editedEmail: $store.editedEmail,
                    editedWebsite: $store.editedWebsite,
                    editedLogoURL: $store.editedLogoURL,
                    editedAddress: $store.editedAddress,
                    organization: store.organization
                )

                if !store.relatedTrips.isEmpty {
                    Section(header: Text("Related Trips")) {
                        ForEach(store.relatedTrips.sorted { $0.name < $1.name }) { trip in
                            Button {
                                onOpenTrip(trip.id)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(trip.name)
                                        .font(.headline)

                                    Text("\(countActivities(in: trip)) activities")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if store.isEditing {
                    Button(role: store.canDeleteOrganization ? .destructive : .cancel) {
                        store.send(.deleteTapped)
                    } label: {
                        Label(store.deleteButtonTitle, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canDeleteOrganization)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            Spacer()
        }
        .navigationTitle(store.isEditing ? "Edit Organization" : "Organization")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                if store.isEditing {
                    HStack {
                        Button("Cancel") {
                            store.send(.cancelEditing)
                        }

                        Button("Save") {
                            store.send(.saveTapped)
                        }
                        .disabled(store.editedName.isEmpty || (store.organization.isNone && store.editedName.lowercased() != "none"))
                    }
                } else {
                    Button("Edit") {
                        store.send(.startEditing)
                    }
                }
            }
        }
        .confirmationDialog(
            getDeleteConfirmationMessage(),
            isPresented: $store.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
        }
        .alert("Save Error", isPresented: $store.showingSaveError) {
            Button("OK") {
                store.send(.dismissSaveError)
            }
        } message: {
            Text(store.saveErrorMessage)
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private func getDeleteConfirmationMessage() -> String {
        if store.organization.isNone {
            return "The system 'None' organization cannot be deleted."
        }
        if !store.canDeleteOrganization {
            let transportCount = store.organization.transportation.count
            let lodgingCount = store.organization.lodging.count
            let activityCount = store.organization.activity.count
            return "Cannot delete '\(store.organization.name)'. It has \(transportCount) transportation, \(lodgingCount) lodging, and \(activityCount) activities associated with it."
        }
        return "Are you sure you want to delete '\(store.organization.name)'? This action cannot be undone."
    }

    private func countActivities(in trip: Trip) -> Int {
        let lodgingCount = trip.lodging.filter { $0.organization?.id == store.organization.id }.count
        let transportationCount = trip.transportation.filter { $0.organization?.id == store.organization.id }.count
        let activityCount = trip.activity.filter { $0.organization?.id == store.organization.id }.count
        return lodgingCount + transportationCount + activityCount
    }
}

private struct ContactInfoSection: View {
    @Binding var isEditing: Bool
    @Binding var editedPhone: String
    @Binding var editedEmail: String
    @Binding var editedWebsite: String
    @Binding var editedLogoURL: String
    @Binding var editedAddress: Address?
    let organization: Organization

    var body: some View {
        Section(header: Text("Contact Information")) {
            if isEditing {
                HStack {
                    Image(systemName: "photo")
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 4)

                    TextField("Logo URL", text: $editedLogoURL)
                        .platformKeyboardType(.URL)
                        .noAutocapitalization()
                }
                .padding(.vertical, 8)
            }

            HStack {
                Image(systemName: "phone")
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 4)

                if isEditing {
                    TextField("Phone", text: $editedPhone)
                        .platformKeyboardType(.phonePad)
                } else {
                    if organization.phone.isEmpty {
                        Text("No phone")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(organization.phone)
                    }
                }
            }
            .padding(.vertical, 8)

            HStack {
                Image(systemName: "envelope")
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 4)

                if isEditing {
                    TextField("Email", text: $editedEmail)
                        .platformKeyboardType(.emailAddress)
                        .noAutocapitalization()
                } else {
                    if organization.email.isEmpty {
                        Text("No email")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(organization.email)
                    }
                }
            }
            .padding(.vertical, 8)

            HStack {
                Image(systemName: "globe")
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 4)

                if isEditing {
                    TextField("Website", text: $editedWebsite)
                        .platformKeyboardType(.URL)
                        .noAutocapitalization()
                } else {
                    if organization.website.isEmpty {
                        Text("No website")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(organization.website)
                    }
                }
            }
            .padding(.vertical, 8)

            AddressSection(
                isEditing: $isEditing,
                editedAddress: $editedAddress,
                organization: organization
            )
        }
    }
}

private struct AddressSection: View {
    @Binding var isEditing: Bool
    @Binding var editedAddress: Address?
    let organization: Organization

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "location")
                .frame(width: 24, height: 24)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    AddressAutocompleteView(
                        selectedAddress: $editedAddress,
                        placeholder: "Organization address"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if let address = organization.address, !address.isEmpty {
                    Text(formatAddress(address))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No address")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func formatAddress(_ address: Address) -> String {
        var components: [String] = []

        if !address.street.isEmpty {
            components.append(address.street)
        }

        var cityStatePostal: [String] = []
        if !address.city.isEmpty {
            cityStatePostal.append(address.city)
        }
        if !address.state.isEmpty {
            cityStatePostal.append(address.state)
        }
        if !address.postalCode.isEmpty {
            cityStatePostal.append(address.postalCode)
        }

        if !cityStatePostal.isEmpty {
            components.append(cityStatePostal.joined(separator: ", "))
        }

        if !address.country.isEmpty {
            components.append(address.country)
        }

        return components.joined(separator: "\n")
    }
}

#Preview {
    let org = Organization(name: "Test Org")
    NavigationStack {
        OrganizationDetailView(
            onOpenTrip: { _ in },
            store: StoreOf<OrganizationFeature>.init(initialState: OrganizationFeature.State(organization: org)) {
                OrganizationFeature()
            }
        )
    }
}
