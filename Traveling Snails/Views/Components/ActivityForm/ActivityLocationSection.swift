//
//  ActivityLocationSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and editing activity location information
struct ActivityLocationSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color
    let supportsCustomLocation: Bool
    let showingOrganizationPicker: () -> Void
    let showMap: () -> Void

    init(
        activity: T? = nil,
        editData: Binding<TripActivityEditData>,
        isEditing: Bool,
        color: Color,
        supportsCustomLocation: Bool = true,
        showingOrganizationPicker: @escaping () -> Void = {},
        showMap: @escaping () -> Void = {}
    ) {
        self.activity = activity
        self._editData = editData
        self.isEditing = isEditing
        self.color = color
        self.supportsCustomLocation = supportsCustomLocation
        self.showingOrganizationPicker = showingOrganizationPicker
        self.showMap = showMap
    }

    var body: some View {
        ActivitySectionCard(
            headerIcon: "mappin.circle.fill",
            headerTitle: sectionTitle,
            headerColor: color
        ) {
            VStack(spacing: 16) {
                if isEditing {
                    editModeContent
                } else {
                    viewModeContent
                }
            }
        }
    }

    // MARK: - Edit Mode Content

    private var editModeContent: some View {
        VStack(spacing: 16) {
            // Organization picker
            organizationPicker

            // Custom location fields (if applicable)
            if supportsCustomLocation && editData.organization?.isNone == true {
                customLocationFields
            }

            // Hide location toggle (if applicable)
            if supportsCustomLocation {
                hideLocationToggle
            }
        }
    }

    private var organizationPicker: some View {
        ActivityFormButton(
            label: "Organization",
            value: organizationDisplayName,
            action: showingOrganizationPicker
        )
    }

    private var customLocationFields: some View {
        VStack(spacing: 16) {
            ActivityFormField(
                label: "Custom Location Name",
                text: $editData.customLocationName,
                placeholder: "Enter location name"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.caption)
                    .foregroundColor(.secondary)

                AddressAutocompleteView(
                    selectedAddress: $editData.customAddress,
                    placeholder: "Enter address"
                )
            }
        }
    }

    private var hideLocationToggle: some View {
        Toggle("Hide location in views", isOn: $editData.hideLocation)
            .toggleStyle(SwitchToggleStyle(tint: color))
    }

    // MARK: - View Mode Content

    private var viewModeContent: some View {
        VStack(spacing: 16) {
            locationDisplayHeader

            // Map view (if address is available)
            if let address = displayAddress {
                mapButton(for: address)
            }
        }
    }

    private var locationDisplayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(displayLocation)
                    .font(.headline)

                if let address = displayAddress {
                    Text(address.displayAddress)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Organization logo (if available)
            if let organization = displayOrganization, !organization.isNone {
                CachedAsyncImage(
                    url: organization.logoURL,
                    organizationId: organization.id
                )
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func mapButton(for address: Address) -> some View {
        Button(action: showMap) {
            AddressMapView(address: address)
                .frame(height: 150)
                .cornerRadius(8)
                .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var sectionTitle: String {
        if supportsCustomLocation && editData.organization?.isNone != false {
            return "Location"
        }
        return "Organization"
    }

    private var organizationDisplayName: String {
        let org = editData.organization ?? activity?.organization
        return org?.name ?? "Select Organization"
    }

    private var displayLocation: String {
        if let activity = activity {
            return activity.displayLocation
        }
        // Fallback for when no activity is provided (add mode)
        if let org = editData.organization, !org.isNone {
            return org.name
        }
        if !editData.customLocationName.isEmpty {
            return editData.customLocationName
        }
        return "No location set"
    }

    private var displayAddress: Address? {
        if isEditing {
            return editData.customAddress ?? editData.organization?.address
        } else {
            return activity?.displayAddress
        }
    }

    private var displayOrganization: Organization? {
        if isEditing {
            return editData.organization
        } else {
            return activity?.organization
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode preview with custom location
        ActivityLocationSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.customLocationName = "Custom Restaurant"
                return data
            }()),
            isEditing: true,
            color: .orange,
            supportsCustomLocation: true
        )

        // View mode preview
        ActivityLocationSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.customLocationName = "The Louvre Museum"
                return data
            }()),
            isEditing: false,
            color: .blue,
            supportsCustomLocation: true
        )
    }
    .padding()
}
