//
//  PrefilledAddActivityView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/3/25.
//

import SwiftUI

struct PrefilledAddActivityView<T: TripActivityProtocol>: View {
    let trip: Trip
    let activityType: T.Type
    let startTime: Date
    let endTime: Date
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var editData: TripActivityEditData
    @State private var showingOrganizationPicker = false
    @State private var attachments: [EmbeddedFileAttachment] = []
    @State private var isSaving = false
    
    init(trip: Trip, activityType: T.Type, startTime: Date, endTime: Date) {
        self.trip = trip
        self.activityType = activityType
        self.startTime = startTime
        self.endTime = endTime
        
        // Create prefilled edit data based on activity type
        let template = Self.createTemplate(for: activityType, startTime: startTime, endTime: endTime)
        self._editData = State(initialValue: TripActivityEditData(from: template))
    }
    
    private static func createTemplate(for type: T.Type, startTime: Date, endTime: Date) -> T {
        _ = "\(String(describing: type).replacingOccurrences(of: "Type", with: ""))"
        
        switch type {
        case is Lodging.Type:
            return Lodging(
                name: "New Lodging",
                start: startTime,
                end: endTime,
                trip: nil,
                organization: nil
            ) as! T
        case is Transportation.Type:
            return Transportation(
                name: "New Transportation",
                start: startTime,
                end: endTime,
                trip: nil,
                organization: nil
            ) as! T
        case is Activity.Type:
            return Activity(
                name: "New Activity",
                start: startTime,
                end: endTime,
                trip: nil,
                organization: nil
            ) as! T
        default:
            fatalError("Unknown activity type")
        }
    }
    
    private var template: T {
        Self.createTemplate(for: activityType, startTime: startTime, endTime: endTime)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: template.icon)
                        .font(.system(size: 60))
                        .foregroundColor(template.color)
                        .padding()
                        .background(template.color.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("New \(template.activityType.rawValue)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(template.color)
                    
                    VStack(spacing: 4) {
                        Text("\(startTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(endTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top)
                
                // Basic Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(template.color)
                        
                        Text("Details")
                            .font(.headline)
                            .foregroundColor(template.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Enter \(template.activityType.rawValue.lowercased()) name", text: $editData.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Type picker for transportation
                    if template.hasTypeSelector {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transportation Type")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Picker("Type", selection: Binding(
                                get: { editData.transportationType ?? .plane },
                                set: { editData.transportationType = $0 }
                            )) {
                                ForEach(TransportationType.allCases, id: \.self) { type in
                                    Label(type.displayName, systemImage: type.systemImage).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }
                .padding()
                .background(template.color.opacity(0.05))
                .cornerRadius(12)
                
                // Organization
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.title3)
                            .foregroundColor(template.color)
                        
                        Text("Organization")
                            .font(.headline)
                            .foregroundColor(template.color)
                    }
                    
                    Button {
                        showingOrganizationPicker = true
                    } label: {
                        HStack {
                            Text(editData.organization?.name ?? "Select organization")
                                .foregroundColor(editData.organization == nil ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(template.color.opacity(0.05))
                .cornerRadius(12)
                
                // Time adjustment (optional)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundColor(template.color)
                        
                        Text("Adjust Times (Optional)")
                            .font(.headline)
                            .foregroundColor(template.color)
                    }
                    
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.startLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $editData.start, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.endLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            DatePicker("", selection: $editData.end, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                }
                .padding()
                .background(template.color.opacity(0.05))
                .cornerRadius(12)
                
                // Cost
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title3)
                            .foregroundColor(template.color)
                        
                        Text("Cost (Optional)")
                            .font(.headline)
                            .foregroundColor(template.color)
                    }
                    
                    HStack {
                        CurrencyTextField(value: $editData.cost)
                            .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
                .background(template.color.opacity(0.05))
                .cornerRadius(12)
                
                // Notes
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundColor(template.color)
                        
                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundColor(template.color)
                    }
                    
                    TextField("Add any notes", text: $editData.notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                .padding()
                .background(template.color.opacity(0.05))
                .cornerRadius(12)
                
                // Submit Button
                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Text("Create \(template.activityType.rawValue)")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? template.color : Color.gray)
                .foregroundColor(.white)
                .font(.headline)
                .cornerRadius(12)
                .disabled(!isFormValid || isSaving)
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("New \(template.activityType.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if !isSaving {
                        dismiss()
                    }
                }
                .disabled(isSaving)
            }
        }
        .sheet(isPresented: $showingOrganizationPicker) {
            NavigationStack {
                OrganizationPicker(selectedOrganization: $editData.organization)
            }
        }
        .onAppear {
            if editData.organization == nil {
                editData.organization = Organization.createNoneOrganization(in: modelContext)
            }
        }
        .disabled(isSaving)
    }
    
    private var isFormValid: Bool {
        !editData.name.isEmpty && editData.organization != nil
    }
    
    private func save() {
        guard !isSaving, let organization = editData.organization else { return }
        
        isSaving = true
        
        switch activityType {
        case is Lodging.Type:
            saveLodging(organization: organization)
        case is Transportation.Type:
            saveTransportation(organization: organization)
        case is Activity.Type:
            saveActivity(organization: organization)
        default:
            isSaving = false
            return
        }
    }
    
    private func saveLodging(organization: Organization) {
        let lodging = Lodging(
            name: editData.name,
            start: editData.start,
            checkInTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            checkOutTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: organization
        )
        
        modelContext.insert(lodging)
        saveToContext()
    }
    
    private func saveTransportation(organization: Organization) {
        let transportation = Transportation(
            name: editData.name,
            type: editData.transportationType ?? .plane,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            confirmation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: organization
        )
        
        modelContext.insert(transportation)
        saveToContext()
    }
    
    private func saveActivity(organization: Organization) {
        let activity = Activity(
            name: editData.name,
            start: editData.start,
            startTZ: TimeZone(identifier: editData.startTZId),
            end: editData.end,
            endTZ: TimeZone(identifier: editData.endTZId),
            cost: editData.cost,
            paid: editData.paid,
            reservation: editData.confirmationField,
            notes: editData.notes,
            trip: trip,
            organization: organization
        )
        
        modelContext.insert(activity)
        saveToContext()
    }
    
    private func saveToContext() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save: \(error)")
            isSaving = false
        }
    }
}
