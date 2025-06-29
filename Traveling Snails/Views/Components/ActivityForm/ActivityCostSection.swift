//
//  ActivityCostSection.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable section component for displaying and editing activity cost and payment information
struct ActivityCostSection<T: TripActivityProtocol>: View {
    let activity: T?
    @Binding var editData: TripActivityEditData
    let isEditing: Bool
    let color: Color

    init(
        activity: T? = nil,
        editData: Binding<TripActivityEditData>,
        isEditing: Bool,
        color: Color
    ) {
        self.activity = activity
        self._editData = editData
        self.isEditing = isEditing
        self.color = color
    }

    var body: some View {
        ActivitySectionCard(
            headerIcon: "dollarsign.circle.fill",
            headerTitle: "Cost & Payment",
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
            // Cost input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Cost")
                    .font(.caption)
                    .foregroundColor(.secondary)

                CurrencyTextField(value: $editData.cost, color: color)
                    .onChange(of: editData.cost) { _, newValue in
                        #if DEBUG
                        Logger.shared.debug("Cost field updated", category: .ui)
                        #endif
                    }
            }

            // Payment status picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Payment Status")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Payment Status", selection: $editData.paid) {
                    ForEach(PaidStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - View Mode Content

    private var viewModeContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(costLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(displayCost, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.semibold)

                // Show per-night cost for lodging
                if showPerNightCost {
                    Text(perNightText)
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
                    Text(displayPaidStatus.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Circle()
                        .fill(paidStatusColor)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var costLabel: String {
        if activityType == .lodging {
            return "Total Cost"
        }
        return "Cost"
    }

    private var displayCost: Decimal {
        if let activity = activity {
            return activity.cost
        }
        return editData.cost
    }

    private var displayPaidStatus: PaidStatus {
        if let activity = activity {
            return activity.paid
        }
        return editData.paid
    }

    private var activityType: ActivityWrapper.ActivityType {
        if let activity = activity {
            return activity.activityType
        }
        if editData.transportationType != nil {
            return .transportation
        }
        return .activity
    }

    private var showPerNightCost: Bool {
        activityType == .lodging && displayCost > 0
    }

    private var perNightText: String {
        guard showPerNightCost else { return "" }

        let startDate: Date
        let endDate: Date

        if let activity = activity {
            startDate = activity.start
            endDate = activity.end
        } else {
            startDate = editData.start
            endDate = editData.end
        }

        let nights = max(1, Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1)
        let perNight = displayCost / Decimal(nights)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let formattedAmount = formatter.string(from: perNight as NSDecimalNumber) ?? "$0.00"

        return "\(formattedAmount) per night"
    }

    private var paidStatusColor: Color {
        switch displayPaidStatus {
        case .infull:
            return .green
        case .deposit:
            return .orange
        case .none:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        // Edit mode preview
        ActivityCostSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.cost = 150.00
                data.paid = .deposit
                return data
            }()),
            isEditing: true,
            color: .green
        )

        // View mode preview for lodging with per-night calculation
        ActivityCostSection<Activity>(
            editData: .constant({
                var data = TripActivityEditData(from: Activity())
                data.cost = 300.00
                data.paid = .infull
                data.start = Date()
                data.end = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
                return data
            }()),
            isEditing: false,
            color: .indigo
        )
    }
    .padding()
}
