//
//  UniversalAddActivityFormContent.swift
//  Traveling Snails
//
//

import SwiftUI

struct UniversalAddActivityFormContent: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
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
        .sheet(isPresented: $viewModel.showingOrganizationPicker) {
            OrganizationPicker(
                selectedOrganization: $viewModel.editData.organization
            )
        }
    }
    
    // MARK: - Section Views
    
    private var headerSection: some View {
        ActivityHeaderView(
            icon: viewModel.icon,
            color: colorFromString(viewModel.color),
            title: viewModel.activityType.displayName
        )
    }
    
    private var basicInfoSection: some View {
        ActivitySectionCard(
            headerIcon: "info.circle.fill",
            headerTitle: "Basic Information",
            headerColor: colorFromString(viewModel.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormField(
                    label: "Name",
                    text: $viewModel.editData.name,
                    placeholder: "\(viewModel.activityType.displayName) Name"
                )                
                if viewModel.hasTypeSelector {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transportation Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Transportation Type", selection: $viewModel.editData.transportationType) {
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
            headerTitle: viewModel.supportsCustomLocation ? "Location" : "Organization",
            headerColor: colorFromString(viewModel.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormButton(
                    label: "Organization",
                    value: viewModel.editData.organization?.name ?? "Select Organization",
                    action: { viewModel.showingOrganizationPicker = true }
                )
                
                if viewModel.supportsCustomLocation {
                    if viewModel.editData.organization?.isNone == true {
                        VStack(spacing: 16) {
                            ActivityFormField(
                                label: "Custom Location Name",
                                text: $viewModel.editData.customLocationName,
                                placeholder: "Enter location name"
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Address")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                AddressAutocompleteView(
                                    selectedAddress: $viewModel.editData.customAddress,
                                    placeholder: "Enter address"
                                )
                            }
                        }
                    }
                    
                    Toggle("Hide location in views", isOn: $viewModel.editData.hideLocation)
                        .toggleStyle(SwitchToggleStyle(tint: colorFromString(viewModel.color)))
                }
            }
        }
    }
    
    private var scheduleSection: some View {
        ActivitySectionCard(
            headerIcon: viewModel.activityType == .lodging ? "calendar.badge.plus" :
                        viewModel.activityType == .transportation ? "airplane" : "clock.fill",
            headerTitle: "Schedule",
            headerColor: colorFromString(viewModel.color)
        ) {
            if viewModel.activityType == .transportation {
                TransportationDateTimeSection(
                    trip: viewModel.trip,
                    startDate: $viewModel.editData.start,
                    endDate: $viewModel.editData.end,
                    startTimeZoneId: $viewModel.editData.startTZId,
                    endTimeZoneId: $viewModel.editData.endTZId,
                    address: viewModel.locationAddress
                )
            } else {
                SingleLocationDateTimeSection(
                    startLabel: viewModel.startLabel,
                    endLabel: viewModel.endLabel,
                    activityType: ActivityWrapper.ActivityType(rawValue: viewModel.activityType.rawValue) ?? .activity,
                    trip: viewModel.trip,
                    startDate: $viewModel.editData.start,
                    endDate: $viewModel.editData.end,
                    timeZoneId: $viewModel.editData.startTZId,
                    address: viewModel.locationAddress
                )
                .onChange(of: viewModel.editData.startTZId) { _, newValue in
                    viewModel.editData.endTZId = newValue
                }
            }
        }
    }
    
    private var costSection: some View {
        ActivitySectionCard(
            headerIcon: "dollarsign.circle.fill",
            headerTitle: "Cost & Payment",
            headerColor: colorFromString(viewModel.color)
        ) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    CurrencyTextField(value: $viewModel.editData.cost, color: colorFromString(viewModel.color))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Payment Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $viewModel.editData.paid) {
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
            headerColor: colorFromString(viewModel.color)
        ) {
            VStack(spacing: 16) {
                ActivityFormField(
                    label: viewModel.confirmationLabel,
                    text: $viewModel.editData.confirmationField,
                    placeholder: "Enter \(viewModel.confirmationLabel.lowercased()) number"
                )
                
                ActivityFormField(
                    label: "Notes",
                    text: $viewModel.editData.notes,
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
            headerColor: colorFromString(viewModel.color)
        ) {
            VStack(spacing: 12) {
                if !viewModel.attachments.isEmpty {
                    HStack {
                        Spacer()
                        Text("(\(viewModel.attachments.count))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if viewModel.attachments.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("No attachments yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)
                } else {
                    ForEach(viewModel.attachments) { attachment in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(colorFromString(viewModel.color))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(attachment.fileName)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                if attachment.fileSize > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(attachment.fileSize), countStyle: .file))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.removeAttachment(attachment)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                Button {
                    // TODO: Implement file picker
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Attachment")
                    }
                    .foregroundColor(colorFromString(viewModel.color))
                }
                .buttonStyle(.bordered)
                .tint(colorFromString(viewModel.color))
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var submitButton: some View {
        ActivitySubmitButton(
            title: "Save \(viewModel.activityType.displayName)",
            isValid: viewModel.isFormValid,
            isSaving: viewModel.isSaving,
            color: colorFromString(viewModel.color),
            saveError: viewModel.saveError,
            action: {
                Task { @MainActor in
                    do {
                        try await viewModel.save()
                        dismiss()
                    } catch {
                        // Error is stored in viewModel.saveError
                    }
                }
            }
        )
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
