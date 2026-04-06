//
//  AddTripActivityFormView.swift
//  Traveling Snails
//

import ComposableArchitecture
import SwiftUI

struct AddTripActivityFormView: View {
    @Bindable var store: StoreOf<TripActivityFormFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                basicInfoSection
                organizationSection
                scheduleSection
                costSection
                detailsSection
                attachmentsSection
                submitButton
            }
            .padding(.horizontal, 16)
        }
        .sheet(
            item: $store.scope(state: \.organizationPicker, action: \.organizationPicker)
        ) { pickerStore in
            NavigationStack {
                OrganizationPicker(
                    selectedOrganization: $store.editData.organization,
                    store: pickerStore
                )
            }
        }
        .navigationDestination(isPresented: $store.showingLegsEditor) {
            TransportationLegsEditorView(
                legs: $store.transportationLegs,
                onAddLeg: { store.send(.addLegTapped) }
            )
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
                store.send(.dismissHandled)
            }
        }
    }

    // MARK: - Section Views

    private var headerSection: some View {
        ActivityHeaderView(
            icon: store.currentIcon,
            color: colorFromString(store.color),
            title: store.activityType.displayName
        )
    }

    private var basicInfoSection: some View {
        ActivitySectionCard(
            headerIcon: "info.circle.fill",
            headerTitle: "Basic Information",
            headerColor: colorFromString(store.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormField(
                    label: "Name",
                    text: $store.editData.name,
                    placeholder: "\(store.activityType.displayName) Name"
                )
                if store.hasTypeSelector {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transportation Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Transportation Type", selection: $store.editData.transportationType) {
                            ForEach(TransportationType.allCases, id: \.self) { type in
                                Label(type.displayName, systemImage: type.systemImage)
                                    .tag(type as TransportationType?)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var organizationSection: some View {
        ActivitySectionCard(
            headerIcon: "mappin.circle.fill",
            headerTitle: store.supportsCustomLocation ? "Location" : "Organization",
            headerColor: colorFromString(store.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormButton(
                    label: "Organization",
                    value: store.editData.organization?.name ?? "Select Organization"
                ) { store.send(.showOrganizationPicker) }

                if store.supportsCustomLocation {
                    if store.editData.organization?.isNone == true {
                        VStack(spacing: 16) {
                            ActivityFormField(
                                label: "Custom Location Name",
                                text: $store.editData.customLocationName,
                                placeholder: "Enter location name"
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Address")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                AddressAutocompleteView(
                                    selectedAddress: $store.editData.customAddress,
                                    placeholder: "Enter address"
                                )
                            }
                        }
                    }

                    Toggle("Hide location in views", isOn: $store.editData.hideLocation)
                        .toggleStyle(SwitchToggleStyle(tint: colorFromString(store.color)))
                }
            }
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if store.activityType == .transportation {
            TransportationScheduleSectionView(
                trip: store.trip,
                icon: store.currentIcon,
                color: colorFromString(store.color),
                isEditing: true,
                legs: $store.transportationLegs,
                legsValidationError: store.legsValidationError,
                showingLegsEditor: $store.showingLegsEditor
            )
        } else {
            ActivitySectionCard(
                headerIcon: store.activityType == .lodging ? "calendar.badge.plus" : "clock.fill",
                headerTitle: "Schedule",
                headerColor: colorFromString(store.color)
            ) {
                SingleLocationDateTimeSection(
                    startLabel: store.startLabel,
                    endLabel: store.endLabel,
                    activityType: ActivityWrapper.ActivityType(rawValue: store.activityType.rawValue) ?? .activity,
                    trip: store.trip,
                    startDate: $store.editData.start,
                    endDate: $store.editData.end,
                    timeZoneId: $store.editData.startTZId,
                    address: store.locationAddress
                )
                .onChange(of: store.editData.startTZId) { _, newValue in
                    store.editData.endTZId = newValue
                }
            }
        }
    }

    private var costSection: some View {
        ActivitySectionCard(
            headerIcon: "dollarsign.circle.fill",
            headerTitle: "Cost & Payment",
            headerColor: colorFromString(store.color)
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    CurrencyTextField(value: $store.editData.cost, color: colorFromString(store.color))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment Status")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $store.editData.paid) {
                        ForEach(PaidStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var detailsSection: some View {
        ActivitySectionCard(
            headerIcon: "note.text",
            headerTitle: "Additional Details",
            headerColor: colorFromString(store.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormField(
                    label: store.confirmationLabel,
                    text: $store.editData.confirmationField,
                    placeholder: "Enter \(store.confirmationLabel.lowercased()) number"
                )

                ActivityFormField(
                    label: "Notes",
                    text: $store.editData.notes,
                    placeholder: "Add any additional notes",
                    axis: .vertical
                )
            }
        }
    }

    private var attachmentsSection: some View {
        ActivitySectionCard(
            headerIcon: "paperclip",
            headerTitle: "File Attachments",
            headerColor: colorFromString(store.color)
        ) {
            VStack(spacing: 12) {
                if !store.attachments.isEmpty {
                    HStack {
                        Spacer()
                        Text("(\(store.attachments.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if store.attachments.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        Text("No attachments yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)
                } else {
                    ForEach(store.attachments) { attachment in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(colorFromString(store.color))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.fileName)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                if attachment.fileSize > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.fileSize), countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                store.send(.removeAttachment(attachment))
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(Color.systemGray6)
                        .clipShape(.rect(cornerRadius: 8))
                    }
                }

                AttachmentPickerView.allFiles(
                    onSelected: { attachment in
                        store.send(.addAttachment(attachment))
                    },
                    onError: { error in
                        store.send(.attachmentError(error))
                    }
                )
                .buttonStyle(.bordered)
                .tint(colorFromString(store.color))
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var submitButton: some View {
        ActivitySubmitButton(
            title: "Save \(store.activityType.displayName)",
            isValid: store.isFormValid,
            isSaving: store.isSaving,
            color: colorFromString(store.color),
            saveError: store.saveError
        ) {
            store.send(.saveTapped)
        }
    }

    // Helper function to convert color strings to SwiftUI Colors
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "indigo":
            return .indigo
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        case "yellow":
            return .yellow
        case "pink":
            return .pink
        case "cyan":
            return .cyan
        case "mint":
            return .mint
        case "teal":
            return .teal
        case "brown":
            return .brown
        default:
            return .blue // fallback
        }
    }
}
