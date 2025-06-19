//
//  UnifiedTripActivityDetailView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/31/25.
//

import SwiftUI

struct UnifiedTripActivityDetailView<T: TripActivityProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let activity: T
    
    @State private var isEditing = false
    @State private var editData: TripActivityEditData = TripActivityEditData(from: Activity())
    @State private var showDeleteConfirmation = false
    @State private var showingOrganizationPicker = false
    @State private var showMap = false
    
    init(activity: T) {
        self.activity = activity
    }
    
    // Use @State for attachments since we need to mutate it
    @State private var attachments: [EmbeddedFileAttachment] = []
    
    private var displayAddress: Address? {
        if isEditing {
            return editData.customAddress ?? editData.organization?.address
        } else {
            return activity.displayAddress
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Location Section (if applicable)
                if !activity.supportsCustomLocation || (!editData.hideLocation || isEditing) {
                    locationSection
                }
                
                // Schedule Section
                scheduleSection
                
                // Cost & Payment Section
                costSectionWithFancy
                
                // Details Section
                detailsSection
                
                // File Attachments Section
                if !isEditing {
                    attachmentsSection
                }
                
                // Delete Button (only in edit mode)
                if isEditing {
                    deleteButton
                }
            }
        }
        .navigationTitle(isEditing ? "Edit \(activity.activityType.rawValue)" : "\(activity.activityType.rawValue) Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
        }
        .sheet(isPresented: $showingOrganizationPicker) {
            NavigationStack {
                OrganizationPicker(selectedOrganization: $editData.organization)
            }
        }
        .sheet(isPresented: $showMap) {
            if let address = displayAddress {
                NavigationStack {
                    AddressMapView(address: address)
                        .navigationTitle(activity.displayLocation)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showMap = false }
                            }
                        }
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this \(activity.activityType.rawValue.lowercased())?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        }
        .onAppear {
            // Initialize edit data and attachments from activity
            editData = TripActivityEditData(from: activity)
            attachments = activity.fileAttachments
        }
        .modifier(EditTransition(isEditing: isEditing))
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Activity Icon
            Image(systemName: activity.icon)
                .font(.system(size: 60))
                .foregroundColor(activity.color)
                .padding()
                .background(activity.color.opacity(0.1))
                .clipShape(Circle())
            
            // Name Field
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("\(activity.activityType.rawValue) Name", text: $editData.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            } else {
                HStack {
                    Text(activity.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    // Show attachment indicator if attachments exist
                    if !attachments.isEmpty {
                        Image(systemName: "paperclip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Type picker for transportation in edit mode
            if isEditing && activity.hasTypeSelector {
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
                .padding(.horizontal)
            }
            
            // Duration/nights display
            if !isEditing {
                if activity.activityType == .lodging {
                    let nights = Calendar.current.dateComponents([.day], from: activity.start, to: activity.end).day ?? 0
                    Text("\(nights) night\(nights == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    let duration = activity.duration()
                    let hours = Int(duration) / 3600
                    let minutes = (Int(duration) % 3600) / 60
                    Text("\(hours)h \(minutes)m")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top)
    }
    
    @ViewBuilder
    private var locationSection: some View {
        // Show organization section for all activity types, but custom location fields only for supported types
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(activity.color)
                
                Text(activity.supportsCustomLocation && editData.organization?.isNone == false ? "Organization" :
                     activity.supportsCustomLocation ? "Location" : "Organization")
                    .font(.headline)
                    .foregroundColor(activity.color)
            }
            
            VStack(spacing: 16) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Organization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showingOrganizationPicker = true
                        } label: {
                            HStack {
                                Text((editData.organization ?? activity.organization)?.name ?? "No organization")
                                    .foregroundColor(.primary)
                                
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
                    
                    // Only show custom location fields for activities that support them
                    if activity.supportsCustomLocation && editData.organization?.isNone == true {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Custom Location Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TextField("Enter location name", text: $editData.customLocationName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
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
                    
                    // Only show hide location toggle for activities that support custom locations
                    if activity.supportsCustomLocation {
                        Toggle("Hide location in views", isOn: $editData.hideLocation)
                            .toggleStyle(SwitchToggleStyle(tint: activity.color))
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.displayLocation)
                                .font(.headline)
                            
                            if let address = activity.displayAddress {
                                Text(address.displayAddress)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if let organization = activity.organization, !organization.isNone {
                            CachedAsyncImage(
                                url: organization.logoURL,
                                organizationId: organization.id
                            )
                            .frame(width: 50, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    if let address = displayAddress {
                        Button {
                            showMap = true
                        } label: {
                            AddressMapView(address: address)
                                .frame(height: 150)
                                .cornerRadius(8)
                                .allowsHitTesting(false)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(activity.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isEditing {
                if activity.activityType == .transportation {
                    if let trip = activity.trip {
                        TransportationDateTimeSection(
                            trip: trip,
                            startDate: $editData.start,
                            endDate: $editData.end,
                            startTimeZoneId: $editData.startTZId,
                            endTimeZoneId: $editData.endTZId,
                            address: editData.customAddress ?? editData.organization?.address
                        )
                    }
                } else {
                    if let trip = activity.trip {
                        SingleLocationDateTimeSection(
                            startLabel: activity.startLabel,
                            endLabel: activity.endLabel,
                            activityType: activity.activityType,
                            trip: trip,
                            startDate: $editData.start,
                            endDate: $editData.end,
                            timeZoneId: $editData.startTZId,
                            address: editData.customAddress ?? editData.organization?.address
                        )
                        .onChange(of: editData.startTZId) { _, newValue in
                            editData.endTZId = newValue
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: activity.activityType == .lodging ? "calendar.badge.plus" :
                                            activity.activityType == .transportation ? "airplane" : "clock.fill")
                            .font(.title3)
                            .foregroundColor(activity.color)
                        
                        Text(activity.scheduleTitle)
                            .font(.headline)
                            .foregroundColor(activity.color)
                    }
                    
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.startLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Use our corrected formatting
                                Text(formatDateInTimezone(activity.start, timezone: activity.startTZ))
                                    .font(.headline)
                                
                                Text("\(TimeZoneHelper.getAbbreviation(for: activity.startTZ)) • \(activity.startTZ.identifier)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: activity.activityType == .transportation ? "arrow.right" : "arrow.down")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.endLabel)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(formatDateInTimezone(activity.end, timezone: activity.endTZ))
                                    .font(.headline)
                                
                                Text("\(TimeZoneHelper.getAbbreviation(for: activity.endTZ)) • \(activity.endTZ.identifier)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(activity.color.opacity(0.05))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var costSectionWithFancy: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.title3)
                    .foregroundColor(activity.color)
                
                Text("Cost & Payment")
                    .font(.headline)
                    .foregroundColor(activity.color)
            }
            
            VStack(spacing: 16) {
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cost")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Pass the activity color to the component
                        CurrencyTextField(value: $editData.cost, color: activity.color)
                            .onChange(of: editData.cost) { _, newValue in
                                print("=== DEBUG: Cost updated to \(newValue) ===")
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Payment Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("", selection: $editData.paid) {
                            ForEach(PaidStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.activityType == .lodging ? "Total Cost" : "Cost")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(activity.cost, format: .currency(code: "USD"))
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            if activity.activityType == .lodging && activity.cost > 0 {
                                let nights = max(1, Calendar.current.dateComponents([.day], from: activity.start, to: activity.end).day ?? 1)
                                let perNight = activity.cost / Decimal(nights)
                                Text("\(perNight, format: .currency(code: "USD")) per night")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Payment Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text(activity.paid.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Circle()
                                    .fill(activity.paid == .infull ? Color.green :
                                          activity.paid == .deposit ? Color.orange : Color.gray)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(activity.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "note.text")
                    .font(.title3)
                    .foregroundColor(activity.color)
                
                Text("Additional Details")
                    .font(.headline)
                    .foregroundColor(activity.color)
            }
            
            VStack(spacing: 16) {
                if !activity.confirmationField.isEmpty || isEditing {
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(activity.confirmationLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter \(activity.confirmationLabel.lowercased()) number", text: $editData.confirmationField)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.confirmationLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(activity.confirmationField.isEmpty ? "Not provided" : activity.confirmationField)
                                .font(.subheadline)
                                .foregroundColor(activity.confirmationField.isEmpty ? .secondary : .primary)
                        }
                    }
                }
                
                if isEditing {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Add any additional notes", text: $editData.notes, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(activity.notes.isEmpty ? "No notes" : activity.notes)
                            .font(.subheadline)
                            .foregroundColor(activity.notes.isEmpty ? .secondary : .primary)
                    }
                }
                
                // Organization contact info (if available and not in edit mode)
                if !isEditing,
                   let organization = activity.organization,
                   !organization.isNone &&
                   (activity.supportsCustomLocation ? !activity.hideLocation : true) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact Information")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(activity.color)
                        
                        VStack(spacing: 12) {
                            if organization.hasPhone {
                                HStack {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(activity.color)
                                        .frame(width: 24, height: 24)
                                    SecurePhoneLink(phoneNumber: organization.phone)
                                    Spacer()
                                }
                            }
                            
                            if organization.hasEmail {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(activity.color)
                                        .frame(width: 24, height: 24)
                                    SecureEmailLink(email: organization.email)
                                    Spacer()
                                }
                            }
                            
                            if organization.hasWebsite {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(activity.color)
                                        .frame(width: 24, height: 24)
                                    SecureWebsiteLink(website: organization.website)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(activity.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paperclip")
                    .font(.title3)
                    .foregroundColor(activity.color)
                
                Text("Attachments")
                    .font(.headline)
                    .foregroundColor(activity.color)
                
                if !attachments.isEmpty {
                    Text("(\(attachments.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            EmbeddedFileAttachmentListView(
                attachments: attachments,
                onAttachmentAdded: { attachment in
                    addAttachmentToActivity(attachment)
                },
                onAttachmentRemoved: { attachment in
                    removeAttachmentFromActivity(attachment)
                }
            )
        }
        .padding()
        .background(activity.color.opacity(0.05))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("Delete \(activity.activityType.rawValue)", systemImage: "trash.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red)
                .foregroundColor(.white)
                .font(.headline)
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        editData = TripActivityEditData(from: activity)
        withAnimation {
            isEditing = true
        }
    }
    
    private func cancelEditing() {
        editData = TripActivityEditData(from: activity)
        withAnimation {
            isEditing = false
        }
    }
    
    private func formatDateInTimezone(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }

    private func saveChanges() {
        print("=== DEBUG: saveChanges() called ===")
        print("Edit data cost: \(editData.cost)")
        print("Edit data cost type: \(type(of: editData.cost))")
        print("Current activity cost: \(activity.cost)")
        print("Current activity cost type: \(type(of: activity.cost))")
        print("Activity type: \(activity.activityType)")
        
        // Try direct assignment first to isolate the issue
        let originalCost = activity.cost
        
        switch activity.activityType {
        case .lodging:
            if let lodging = activity as? Lodging {
                print("Direct assignment to lodging...")
                lodging.cost = editData.cost
                print("Lodging cost after direct assignment: \(lodging.cost)")
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                print("Direct assignment to transportation...")
                transportation.cost = editData.cost
                print("Transportation cost after direct assignment: \(transportation.cost)")
            }
        case .activity:
            if let activityItem = activity as? Activity {
                print("Direct assignment to activity...")
                activityItem.cost = editData.cost
                print("Activity cost after direct assignment: \(activityItem.cost)")
            }
        }
        
        print("Activity cost after direct assignment: \(activity.cost)")
        
        // Now try applyEdits
        print("Calling applyEdits...")
        activity.applyEdits(from: editData)
        print("Activity cost after applyEdits: \(activity.cost)")
        
        // Check if the change stuck
        if activity.cost == originalCost && editData.cost != originalCost {
            print("❌ COST UPDATE FAILED - cost reverted to original value")
            print("Trying one more direct assignment...")
            
            // Force one more time
            switch activity.activityType {
            case .lodging:
                (activity as? Lodging)?.cost = editData.cost
            case .transportation:
                (activity as? Transportation)?.cost = editData.cost
            case .activity:
                (activity as? Activity)?.cost = editData.cost
            }
            print("Final force assignment result: \(activity.cost)")
        }
        
        do {
            try modelContext.save()
            print("✅ Save successful - final cost: \(activity.cost)")
            withAnimation {
                isEditing = false
            }
        } catch {
            print("❌ Failed to save: \(error)")
        }
    }
    
    private func debugFormatDateInTimezone(_ date: Date, timezone: TimeZone, label: String) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        
        let formatted = formatter.string(from: date)
        
        // Debug output
        print("=== DEBUG: \(label) ===")
        print("Original date: \(date)")
        print("Timezone: \(timezone.identifier)")
        print("Formatted: \(formatted)")
        
        // Also try formatting in UTC to see the difference
        let utcFormatter = DateFormatter()
        utcFormatter.dateStyle = .medium
        utcFormatter.timeStyle = .short
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        print("Same date in UTC: \(utcFormatter.string(from: date))")
        
        return formatted
    }
    
    private func deleteActivity() {
        // Delete associated file attachments
        for attachment in attachments {
            modelContext.delete(attachment)
        }
        
        // Cast to concrete type for SwiftData deletion
        switch activity.activityType {
        case .lodging:
            if let lodging = activity as? Lodging {
                modelContext.delete(lodging)
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                modelContext.delete(transportation)
            }
        case .activity:
            if let activityItem = activity as? Activity {
                modelContext.delete(activityItem)
            }
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete activity: \(error)")
        }
        dismiss()
    }
    
    // loadAttachments() function removed - attachments is now a computed property
    
    private func addAttachmentToActivity(_ attachment: EmbeddedFileAttachment) {
        switch activity.activityType {
        case .activity:
            if let activityItem = activity as? Activity {
                attachment.activity = activityItem
                activityItem.fileAttachments.append(attachment)
            }
        case .lodging:
            if let lodging = activity as? Lodging {
                attachment.lodging = lodging
                lodging.fileAttachments.append(attachment)
            }
        case .transportation:
            if let transportation = activity as? Transportation {
                attachment.transportation = transportation
                transportation.fileAttachments.append(attachment)
            }
        }
        
        attachments.append(attachment)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save attachment relationship: \(error)")
        }
    }
    
    private func removeAttachmentFromActivity(_ attachment: EmbeddedFileAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }
}
