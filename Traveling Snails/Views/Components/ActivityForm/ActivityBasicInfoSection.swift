//
//  ActivityBasicInfoSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and editing basic activity information
struct ActivityBasicInfoSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color
    let icon: String
    let attachmentCount: Int
    
    init(
        activity: T? = nil,
        editData: Binding<TripActivityEditData>,
        isEditing: Bool,
        color: Color,
        icon: String,
        attachmentCount: Int = 0
    ) {
        self.activity = activity
        self._editData = editData
        self.isEditing = isEditing
        self.color = color
        self.icon = icon
        self.attachmentCount = attachmentCount
    }
    
    var body: some View {
        ActivitySectionCard(
            headerIcon: "info.circle.fill",
            headerTitle: "Basic Information",
            headerColor: color
        ) {
            VStack(spacing: 16) {
                // Header with icon and name
                headerContent
                
                // Transportation type picker (if applicable)
                if isEditing && (editData.transportationType != nil || activity?.hasTypeSelector == true) {
                    transportationTypePicker
                }
                
                // Duration display (view mode only)
                if !isEditing, let activity = activity {
                    durationDisplay(for: activity)
                }
            }
        }
        .frame(maxWidth: .infinity)  // Force container to take full width
    }
    
    // MARK: - Header Content
    
    private var headerContent: some View {
        VStack(spacing: 16) {
            // Activity Icon (centered, prominent)
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(color)
                .padding(12)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            // Name content (centered like the icon)
            VStack(spacing: 12) {
                if isEditing {
                    ActivityFormField(
                        label: "Name",
                        text: $editData.name,
                        placeholder: activityTypeName + " Name"
                    )
                } else {
                    VStack(spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(editData.name.isEmpty ? "Unnamed Activity" : editData.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            // Show attachment indicator if attachments exist
                            if attachmentCount > 0 {
                                Image(systemName: "paperclip")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)  // Force content to take full width
    }
    
    // MARK: - Transportation Type Picker
    
    private var transportationTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transportation Type")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Transportation Type", selection: Binding(
                get: { editData.transportationType ?? .plane },
                set: { editData.transportationType = $0 }
            )) {
                ForEach(TransportationType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.systemImage)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    // MARK: - Duration Display
    
    @ViewBuilder
    private func durationDisplay(for activity: T) -> some View {
        if activity.activityType == .lodging {
            let nights = Calendar.current.dateComponents([.day], from: activity.start, to: activity.end).day ?? 0
            Text("\(nights) night\(nights == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            let duration = activity.duration()
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            if hours > 0 {
                Text("\(hours)h \(minutes)m")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("\(minutes)m")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var activityTypeName: String {
        if let transportationType = editData.transportationType {
            return transportationType.displayName
        }
        return activity?.activityType.rawValue.capitalized ?? "Activity"
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode preview
        ActivityBasicInfoSection<Activity>(
            editData: .constant(TripActivityEditData(from: Activity())),
            isEditing: true,
            color: .blue,
            icon: "airplane",
            attachmentCount: 2
        )
        
        // View mode preview
        ActivityBasicInfoSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.name = "Flight to Paris"
                data.transportationType = .plane
                return data
            }()),
            isEditing: false,
            color: .blue,
            icon: "airplane",
            attachmentCount: 1
        )
    }
    .padding()
}