//
//  OrganizationDetailView.swift
//  Traveling Snails
//
//

import SwiftUI

struct OrganizationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTab: Int
    @Binding var selectedTrip: Trip?
    let organization: Organization

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedPhone: String = ""
    @State private var editedEmail: String = ""
    @State private var editedWebsite: String = ""
    @State private var editedAddress: Address?
    @State private var editedLogoURL: String = ""
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    @State private var showDeleteConfirmation = false

    var relatedTrips: [Trip] {
        var trips = Set<Trip>()


        trips.formUnion(organization.transportation.compactMap { $0.trip })
        trips.formUnion(organization.lodging.compactMap { $0.trip })
        trips.formUnion(organization.activity.compactMap { $0.trip })

        return Array(trips)
    }

    var canDeleteOrganization: Bool {
        // Can't delete the sentinel "None" organization
        if organization.isNone {
            return false
        }

        // Can't delete if it has any references
        return (organization.transportation.isEmpty) &&
        (organization.lodging.isEmpty) &&
        (organization.activity.isEmpty)
    }

    var deleteButtonTitle: String {
        if organization.isNone {
            return "Cannot Delete System Organization"
        } else if !canDeleteOrganization {
            return "Cannot Delete - Has References"
        } else {
            return "Delete Organization"
        }
    }

    var totalActivityCount: Int {
        (organization.transportation.count) +
        (organization.lodging.count) +
        (organization.activity.count)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

            HStack {
                CachedAsyncImage(url: organization.logoURL, organizationId: organization.id)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading) {
                    if isEditing {
                        TextField("Organization Name", text: $editedName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(organization.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }

                    Text("\(totalActivityCount) activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()

            Spacer()

            List {
                ContactInfoSection(
                    isEditing: $isEditing,
                    editedPhone: $editedPhone,
                    editedEmail: $editedEmail,
                    editedWebsite: $editedWebsite,
                    editedLogoURL: $editedLogoURL,
                    editedAddress: $editedAddress,
                    organization: organization
                )

                if !relatedTrips.isEmpty {
                    Section(header: Text("Related Trips")) {
                        ForEach(relatedTrips.sorted { $0.name < $1.name }) { trip in
                            Button {
                                selectedTrip = trip
                                selectedTab = 0  // Switch to Trips tab
                                dismiss()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(trip.name)
                                        .font(.headline)

                                    Text("\(countActivities(in: trip)) activities")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }

                // Delete Button (show when editing and organization can be deleted)
                if isEditing {
                    Button(role: canDeleteOrganization ? .destructive : .cancel) {
                        if canDeleteOrganization {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Label(deleteButtonTitle, systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canDeleteOrganization)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            Spacer()
        }
        .navigationTitle(isEditing ? "Edit Organization" : "Organization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }

                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(editedName.isEmpty || (organization.isNone && editedName.lowercased() != "none"))
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .confirmationDialog(
            getDeleteConfirmationMessage(),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteOrganization()
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func getDeleteConfirmationMessage() -> String {
        if organization.isNone {
            return "The system 'None' organization cannot be deleted."
        } else if !canDeleteOrganization {
            let transportCount = organization.transportation.count
            let lodgingCount = organization.lodging.count
            let activityCount = organization.activity.count
            return "Cannot delete '\(organization.name)'. It has \(transportCount) transportation, \(lodgingCount) lodging, and \(activityCount) activities associated with it."
        } else {
            return "Are you sure you want to delete '\(organization.name)'? This action cannot be undone."
        }
    }

    private func startEditing() {
        editedName = organization.name
        editedPhone = organization.phone
        editedEmail = organization.email
        editedWebsite = organization.website
        editedLogoURL = organization.logoURL
        editedAddress = (organization.address?.isEmpty == false) ? organization.address : nil
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false

        editedName = ""
        editedPhone = ""
        editedEmail = ""
        editedWebsite = ""
        editedLogoURL = ""
        editedAddress = nil
    }

    private func saveChanges() {
        // Prevent changing name to "None" for non-sentinel organizations
        if !organization.isNone && editedName.lowercased() == "none" {
            saveErrorMessage = "Cannot rename organization to 'None' - this name is reserved for the system."
            showingSaveError = true
            return
        }

        // Prevent changing sentinel organization name to something else
        if organization.isNone && editedName.lowercased() != "none" {
            saveErrorMessage = "Cannot rename the system 'None' organization."
            showingSaveError = true
            return
        }

        organization.name = editedName
        organization.phone = editedPhone
        organization.email = editedEmail
        organization.website = editedWebsite
        organization.logoURL = editedLogoURL

        if let newAddress = editedAddress {
            // Ensure organization has an address object to update
            if organization.address == nil {
                organization.address = Address()
            }
            organization.address?.street = newAddress.street
            organization.address?.city = newAddress.city
            organization.address?.state = newAddress.state
            organization.address?.country = newAddress.country
            organization.address?.postalCode = newAddress.postalCode
            organization.address?.latitude = newAddress.latitude
            organization.address?.longitude = newAddress.longitude
            organization.address?.formattedAddress = newAddress.formattedAddress
        }

        do {
            try modelContext.save()
            isEditing = false

            // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
        } catch {
            Logger.shared.error("Failed to save organization: \(error.localizedDescription)", category: .database)
            saveErrorMessage = L(L10n.Save.organizationFailed)
            showingSaveError = true
        }
    }

    private func deleteOrganization() {
        if organization.isNone {
            saveErrorMessage = "Cannot delete the system 'None' organization."
            showingSaveError = true
            return
        }

        if canDeleteOrganization {
            modelContext.delete(organization)
            do {
                try modelContext.save()
                dismiss()

                // REMOVED: Custom sync triggers - let SwiftData+CloudKit handle automatically
            } catch {
                Logger.shared.error("Failed to delete organization: \(error.localizedDescription)", category: .database)
                saveErrorMessage = L(L10n.Delete.organizationFailed)
                showingSaveError = true
            }
        } else {
            let transportCount = organization.transportation.count
            let lodgingCount = organization.lodging.count
            let activityCount = organization.activity.count
            saveErrorMessage = "Cannot delete '\(organization.name)'. It's used by \(transportCount) transportation, \(lodgingCount) lodging, and \(activityCount) activity records."
            showingSaveError = true
        }
    }

    private func countActivities(in trip: Trip) -> Int {
        let lodgingCount = (trip.lodging).filter { $0.organization?.id == organization.id }.count
        let transportationCount = (trip.transportation).filter { $0.organization?.id == organization.id }.count
        let activityCount = (trip.activity).filter { $0.organization?.id == organization.id }.count
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
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                .padding(.vertical, 8)
            }

            HStack {
                Image(systemName: "phone")
                    .frame(width: 24, height: 24)
                    .padding(.horizontal, 4)

                if isEditing {
                    TextField("Phone", text: $editedPhone)
                        .keyboardType(.phonePad)
                } else {
                    if !organization.phone.isEmpty {
                        SecurePhoneLink(phoneNumber: organization.phone)
                    } else {
                        Text("Not provided").foregroundColor(.secondary)
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
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } else {
                    if !organization.email.isEmpty {
                        SecureEmailLink(email: organization.email)
                    } else {
                        Text("Not provided").foregroundColor(.secondary)
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
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } else {
                    if !organization.website.isEmpty {
                        SecureWebsiteLink(website: organization.website)
                    } else {
                        Text("Not provided").foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        (organization.address?.formattedAddress == ""
                         ? "Not provided"
                         : organization.address?.formattedAddress) ?? ""
                    )
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 4)

                        Text("Address")
                            .font(.headline)
                    }

                    AddressAutocompleteView(
                        selectedAddress: $editedAddress,
                        placeholder: "Enter organization address"
                    )
                    .padding(.vertical, 8)
                }
                .padding(.vertical, 8)
            } else {
                HStack(alignment: .top) {
                    Image(systemName: "mappin.and.ellipse")
                        .frame(width: 24, height: 24)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        if !(organization.address?.isEmpty ?? true) {
                            Text(organization.address?.displayAddress ?? "")
                        } else {
                            Text("Not provided").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)

                if organization.address != nil && organization.address?.isEmpty == false {
                    AddressMapView(address: organization.address!)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets())
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        OrganizationDetailView(
            selectedTab: .constant(1),
            selectedTrip: .constant(nil),
            organization: Organization(name: "Test Organization")
        )
    }
    .modelContainer(for: Organization.self, inMemory: true)
}
