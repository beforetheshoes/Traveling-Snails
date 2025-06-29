//
//  ActivityScheduleSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and editing activity schedule information
struct ActivityScheduleSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color
    let trip: Trip?

    init(
        activity: T? = nil,
        editData: Binding<TripActivityEditData>,
        isEditing: Bool,
        color: Color,
        trip: Trip? = nil
    ) {
        self.activity = activity
        self._editData = editData
        self.isEditing = isEditing
        self.color = color
        self.trip = trip
    }

    var body: some View {
        ActivitySectionCard(
            headerIcon: scheduleIcon,
            headerTitle: scheduleTitle,
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

    @ViewBuilder
    private var editModeContent: some View {
        if let trip = trip {
            if activityType == .transportation {
                TransportationDateTimeSection(
                    trip: trip,
                    startDate: $editData.start,
                    endDate: $editData.end,
                    startTimeZoneId: $editData.startTZId,
                    endTimeZoneId: $editData.endTZId,
                    address: editData.customAddress ?? editData.organization?.address
                )
            } else {
                SingleLocationDateTimeSection(
                    startLabel: startLabel,
                    endLabel: endLabel,
                    activityType: activityType,
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
        } else {
            // Fallback for when no trip is provided
            fallbackEditContent
        }
    }

    private var fallbackEditContent: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start Date & Time")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DatePicker("Start", selection: $editData.start)
                    .datePickerStyle(.compact)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("End Date & Time")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DatePicker("End", selection: $editData.end)
                    .datePickerStyle(.compact)
            }
        }
    }

    // MARK: - View Mode Content

    private var viewModeContent: some View {
        VStack(spacing: 16) {
            // Start time display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(startLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatStartDate())
                        .font(.headline)

                    Text(startTimezoneInfo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: activityType == .transportation ? "arrow.right" : "arrow.down")
                    .foregroundColor(.secondary)
            }

            // End time display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(endLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatEndDate())
                        .font(.headline)

                    Text(endTimezoneInfo())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
    }

    // MARK: - Computed Properties

    private var scheduleIcon: String {
        switch activityType {
        case .lodging:
            return "calendar.badge.plus"
        case .transportation:
            return "airplane"
        default:
            return "clock.fill"
        }
    }

    private var scheduleTitle: String {
        activity?.scheduleTitle ?? "Schedule"
    }

    private var activityType: ActivityWrapper.ActivityType {
        // Try to get from activity first, then from transport type
        if let activity = activity {
            return activity.activityType
        }
        if editData.transportationType != nil {
            return .transportation
        }
        return .activity
    }

    private var startLabel: String {
        activity?.startLabel ?? (activityType == .transportation ? "Departure" : "Start")
    }

    private var endLabel: String {
        activity?.endLabel ?? (activityType == .transportation ? "Arrival" : "End")
    }

    // MARK: - Date Formatting

    private func formatStartDate() -> String {
        if let activity = activity {
            return formatDateInTimezone(activity.start, timezone: activity.startTZ)
        }
        return formatDateInTimezone(editData.start, timezone: startTimezone)
    }

    private func formatEndDate() -> String {
        if let activity = activity {
            return formatDateInTimezone(activity.end, timezone: activity.endTZ)
        }
        return formatDateInTimezone(editData.end, timezone: endTimezone)
    }

    private func startTimezoneInfo() -> String {
        let tz = startTimezone
        return "\(TimeZoneHelper.getAbbreviation(for: tz)) • \(tz.identifier)"
    }

    private func endTimezoneInfo() -> String {
        let tz = endTimezone
        return "\(TimeZoneHelper.getAbbreviation(for: tz)) • \(tz.identifier)"
    }

    private var startTimezone: TimeZone {
        if let activity = activity {
            return activity.startTZ
        }
        return TimeZone(identifier: editData.startTZId) ?? TimeZone.current
    }

    private var endTimezone: TimeZone {
        if let activity = activity {
            return activity.endTZ
        }
        return TimeZone(identifier: editData.endTZId) ?? TimeZone.current
    }

    private func formatDateInTimezone(_ date: Date, timezone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = timezone
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode preview
        ActivityScheduleSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.start = Date()
                data.end = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
                return data
            }()),
            isEditing: true,
            color: .green,
            trip: nil
        )

        // View mode preview
        ActivityScheduleSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.start = Date()
                data.end = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
                return data
            }()),
            isEditing: false,
            color: .blue,
            trip: nil
        )
    }
    .padding()
}
