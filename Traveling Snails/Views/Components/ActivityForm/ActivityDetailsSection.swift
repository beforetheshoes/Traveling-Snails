//
//  ActivityDetailsSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and editing activity details (confirmation, notes, contact info)
struct ActivityDetailsSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color
    let supportsCustomLocation: Bool

    init(
        activity: T? = nil,
        editData: Binding<TripActivityEditData>,
        isEditing: Bool,
        color: Color,
        supportsCustomLocation: Bool = true
    ) {
        self.activity = activity
        self._editData = editData
        self.isEditing = isEditing
        self.color = color
        self.supportsCustomLocation = supportsCustomLocation
    }

    var body: some View {
        ActivitySectionCard(
            headerIcon: "note.text",
            headerTitle: "Additional Details",
            headerColor: color
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Confirmation field (if applicable)
                if showConfirmationField {
                    confirmationFieldContent
                        .padding(.bottom, 16)
                }

                // Notes field
                notesFieldContent
                    .padding(.bottom, 16)

                // Organization contact info (view mode only)
                if showContactInfo {
                    Divider()
                        .padding(.vertical, 16)

                    contactInfoContent
                }
            }
        }
    }

    // MARK: - Confirmation Field

    @ViewBuilder
    private var confirmationFieldContent: some View {
        if isEditing {
            ActivityFormField(
                label: confirmationLabel,
                text: $editData.confirmationField,
                placeholder: "Enter \(confirmationLabel.lowercased()) number"
            )
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(confirmationLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(confirmationDisplayValue)
                        .font(.subheadline)
                        .foregroundColor(confirmationDisplayValue == "Not provided" ? .secondary : .primary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Notes Field

    @ViewBuilder
    private var notesFieldContent: some View {
        if isEditing {
            ActivityFormField(
                label: "Notes",
                text: $editData.notes,
                placeholder: "Add any additional notes",
                axis: .vertical
            )
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(notesDisplayValue)
                        .font(.subheadline)
                        .foregroundColor(notesDisplayValue == "No notes" ? .secondary : .primary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Contact Information

    @ViewBuilder
    private var contactInfoContent: some View {
        if let organization = displayOrganization {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contact Information")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)

                VStack(spacing: 12) {
                    if organization.hasPhone {
                        contactRow(
                            icon: "phone.fill",
                            label: "Phone",
                            value: organization.phone
                        )                            { callPhone(organization.phone) }
                    }

                    if organization.hasEmail {
                        contactRow(
                            icon: "envelope.fill",
                            label: "Email",
                            value: organization.email
                        )                            { sendEmail(organization.email) }
                    }

                    if organization.hasWebsite {
                        contactRow(
                            icon: "globe",
                            label: "Website",
                            value: organization.website
                        )                            { openWebsite(organization.website) }
                    }
                }
            }
        }
    }

    private func contactRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Button(action: action) {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var showConfirmationField: Bool {
        if let activity = activity {
            return !activity.confirmationField.isEmpty || isEditing
        }
        return isEditing || !editData.confirmationField.isEmpty
    }

    private var confirmationLabel: String {
        activity?.confirmationLabel ?? "Confirmation Number"
    }

    private var confirmationDisplayValue: String {
        let value = activity?.confirmationField ?? editData.confirmationField
        return value.isEmpty ? "Not provided" : value
    }

    private var notesDisplayValue: String {
        let notes = activity?.notes ?? editData.notes
        return notes.isEmpty ? "No notes" : notes
    }

    private var showContactInfo: Bool {
        guard !isEditing,
              let organization = displayOrganization,
              !organization.isNone else {
            return false
        }

        // Show contact info unless location is hidden for custom location activities
        if supportsCustomLocation {
            return !editData.hideLocation
        }
        return true
    }

    private var displayOrganization: Organization? {
        if let activity = activity {
            return activity.organization
        }
        return editData.organization
    }

    // MARK: - Contact Actions

    private func callPhone(_ phone: String) {
        guard let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func sendEmail(_ email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func openWebsite(_ website: String) {
        var urlString = website
        if !website.hasPrefix("http://") && !website.hasPrefix("https://") {
            urlString = "https://" + website
        }
        guard let url = URL(string: urlString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode preview
        ActivityDetailsSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.confirmationField = "ABC123"
                data.notes = "Remember to bring passport"
                return data
            }()),
            isEditing: true,
            color: .purple
        )

        // View mode preview
        ActivityDetailsSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.confirmationField = "XYZ789"
                data.notes = "Confirmed reservation for 2 guests"
                return data
            }()),
            isEditing: false,
            color: .blue
        )
    }
    .padding()
}
