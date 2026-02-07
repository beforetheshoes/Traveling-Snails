//
//  PrefilledAddActivityView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct PrefilledAddActivityView<T: TripActivityProtocol>: View {
    private enum ActiveSheet: Identifiable {
        case organizationPicker

        var id: Int { 0 }
    }

    let trip: Trip
    let activityType: T.Type
    let startTime: Date
    let endTime: Date

    @Environment(\.dismiss) private var dismiss
    @State private var store: StoreOf<PrefilledAddActivityFeature>

    init(
        trip: Trip,
        activityType: T.Type,
        startTime: Date,
        endTime: Date,
        store: StoreOf<PrefilledAddActivityFeature>? = nil
    ) {
        self.trip = trip
        self.activityType = activityType
        self.startTime = startTime
        self.endTime = endTime

        // Create prefilled edit data based on activity type
        let template = Self.createTemplate(for: activityType, startTime: startTime, endTime: endTime)
        let resolvedStore = store ?? Store(
            initialState: PrefilledAddActivityFeature.State(
                trip: trip,
                activityKind: Self.activityKind(for: activityType),
                editData: TripActivityEditData(from: template)
            )
        ) {
            PrefilledAddActivityFeature()
        }
        self._store = State(initialValue: resolvedStore)
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

    private static func activityKind(for type: T.Type) -> PrefilledAddActivityFeature.ActivityKind {
        switch type {
        case is Lodging.Type:
            return .lodging
        case is Transportation.Type:
            return .transportation
        case is Activity.Type:
            return .activity
        default:
            fatalError("Unknown activity type")
        }
    }

    var body: some View {
        @Bindable var store = self.store

        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: template.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(template.color)
                        .padding()
                        .background(template.color.opacity(0.1))
                        .clipShape(Circle())

                    Text("New \(template.activityType.rawValue)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(template.color)

                    VStack(spacing: 4) {
                        Text("\(startTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("to")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(endTime.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                // Basic Info
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundStyle(template.color)

                        Text("Details")
                            .font(.headline)
                            .foregroundStyle(template.color)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Enter \(template.activityType.rawValue.lowercased()) name", text: $store.editData.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    // Type picker for transportation
                    if template.hasTypeSelector {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transportation Type")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("Type", selection: Binding(
                                get: { store.editData.transportationType ?? .plane },
                                set: { store.editData.transportationType = $0 }
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
                .clipShape(.rect(cornerRadius: 12))

                // Organization
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.title3)
                            .foregroundStyle(template.color)

                        Text("Organization")
                            .font(.headline)
                            .foregroundStyle(template.color)
                    }

                    Button {
                        store.showingOrganizationPicker = true
                    } label: {
                        HStack {
                            Text(store.editData.organization?.name ?? "Select organization")
                                .foregroundStyle(store.editData.organization == nil ? .secondary : .primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.systemGray6))
                        .clipShape(.rect(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(template.color.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

                // Time adjustment (optional)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundStyle(template.color)

                        Text("Adjust Times (Optional)")
                            .font(.headline)
                            .foregroundStyle(template.color)
                    }

                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.startLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker("", selection: $store.editData.start, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.endLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker("", selection: $store.editData.end, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                }
                .padding()
                .background(template.color.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

                // Cost
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.title3)
                            .foregroundStyle(template.color)

                        Text("Cost (Optional)")
                            .font(.headline)
                            .foregroundStyle(template.color)
                    }

                    HStack {
                        CurrencyTextField(value: $store.editData.cost)
                            .frame(maxWidth: .infinity)

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .padding()
                .background(template.color.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

                // Notes
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .foregroundStyle(template.color)

                        Text("Notes (Optional)")
                            .font(.headline)
                            .foregroundStyle(template.color)
                    }

                    TextField("Add any notes", text: $store.editData.notes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                .padding()
                .background(template.color.opacity(0.05))
                .clipShape(.rect(cornerRadius: 12))

                // Submit Button
                Button {
                    save()
                } label: {
                    HStack {
                        if store.isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundStyle(.white)
                        } else {
                            Text("Create \(template.activityType.rawValue)")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isFormValid ? template.color : Color.gray)
                .foregroundStyle(.white)
                .font(.headline)
                .clipShape(.rect(cornerRadius: 12))
                .disabled(!isFormValid || store.isSaving)
                .padding(.horizontal)
            }
            .padding()
        }
        .navigationTitle("New \(template.activityType.rawValue)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    if !store.isSaving {
                        dismiss()
                    }
                }
                .disabled(store.isSaving)
            }
        }
        .sheet(item: organizationSheet) { sheet in
            switch sheet {
            case .organizationPicker:
                NavigationStack {
                    OrganizationPicker(selectedOrganization: $store.editData.organization)
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
        .disabled(store.isSaving)
    }

    private var isFormValid: Bool {
        !store.editData.name.isEmpty && store.editData.organization != nil
    }

    private func save() {
        store.send(.saveTapped)
    }

    private var organizationSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                store.showingOrganizationPicker ? .organizationPicker : nil
            },
            set: { newValue in
                store.showingOrganizationPicker = (newValue != nil)
            }
        )
    }
}
