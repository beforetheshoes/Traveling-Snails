//
//  UniversalAddActivityFormContent.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/18/25.
//

import SwiftUI

struct UniversalAddActivityFormContent: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Icon
                UniversalActivityHeaderView(viewModel: viewModel)
                
                // Basic Info Section
                UniversalBasicInfoSection(viewModel: viewModel)
                
                // Organization Section
                UniversalOrganizationSection(viewModel: viewModel)
                
                // Schedule Section
                UniversalScheduleSection(viewModel: viewModel)
                
                // Cost & Payment Section
                UniversalCostSection(viewModel: viewModel)
                
                // Additional Details Section
                UniversalDetailsSection(viewModel: viewModel)
                
                // File Attachments Section
                UniversalAttachmentsSection(viewModel: viewModel)
                
                // Submit Button
                UniversalSubmitButton(
                    viewModel: viewModel,
                    onSubmit: {
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
            .padding()
        }
        .sheet(isPresented: $viewModel.showingOrganizationPicker) {
            OrganizationPicker(
                selectedOrganization: $viewModel.editData.organization
            )
        }
    }
}

// MARK: - Supporting Views

struct UniversalActivityHeaderView: View {
    let viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.icon)
                .font(.system(size: 40))
                .foregroundColor(Color(viewModel.color))
            
            Text("Add \(viewModel.activityType.displayName)")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding()
    }
}

struct UniversalBasicInfoSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Information")
                .font(.headline)
            
            TextField("Name", text: $viewModel.editData.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if viewModel.hasTypeSelector {
                Picker("Transportation Type", selection: $viewModel.editData.transportationType) {
                    ForEach(TransportationType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.systemImage)
                            .tag(type as TransportationType?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
}

struct UniversalOrganizationSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Organization")
                .font(.headline)
            
            Button(action: { viewModel.showingOrganizationPicker = true }) {
                HStack {
                    Text(viewModel.editData.organization?.name ?? "Select Organization")
                        .foregroundColor(viewModel.editData.organization == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if viewModel.supportsCustomLocation {
                TextField("Custom Location Name (Optional)", text: $viewModel.editData.customLocationName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Toggle("Hide Location", isOn: $viewModel.editData.hideLocation)
            }
        }
    }
}

struct UniversalScheduleSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .font(.headline)
            
            DatePicker(viewModel.startLabel, selection: $viewModel.editData.start, displayedComponents: [.date, .hourAndMinute])
            
            DatePicker(viewModel.endLabel, selection: $viewModel.editData.end, displayedComponents: [.date, .hourAndMinute])
        }
    }
}

struct UniversalCostSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost & Payment")
                .font(.headline)
            
            FancyCurrencyTextField(value: $viewModel.editData.cost)
            
            Picker("Payment Status", selection: $viewModel.editData.paid) {
                ForEach(PaidStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
}

struct UniversalDetailsSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Details")
                .font(.headline)
            
            TextField(viewModel.confirmationLabel, text: $viewModel.editData.confirmationField)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Notes (Optional)", text: $viewModel.editData.notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
}

struct UniversalAttachmentsSection: View {
    @Bindable var viewModel: UniversalActivityFormViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("File Attachments")
                .font(.headline)
            
            if viewModel.attachments.isEmpty {
                Text("No attachments")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(viewModel.attachments) { attachment in
                    HStack {
                        Image(systemName: "doc.fill")
                        Text(attachment.fileName)
                        Spacer()
                        Button("Remove") {
                            viewModel.removeAttachment(attachment)
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Button("Add Attachment") {
                // TODO: Implement file picker
            }
            .buttonStyle(.bordered)
        }
    }
}

struct UniversalSubmitButton: View {
    let viewModel: UniversalActivityFormViewModel
    let onSubmit: () -> Void
    
    var body: some View {
        Button(action: onSubmit) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 4)
                }
                
                Text(viewModel.isSaving ? "Saving..." : "Save \(viewModel.activityType.displayName)")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isFormValid && !viewModel.isSaving ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(!viewModel.isFormValid || viewModel.isSaving)
        
        if let error = viewModel.saveError {
            Text("Error: \(error.localizedDescription)")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}