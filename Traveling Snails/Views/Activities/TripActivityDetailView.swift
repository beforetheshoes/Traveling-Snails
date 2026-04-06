//
//  TripActivityDetailView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct TripActivityDetailView<T: TripActivityProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    let activity: T

    @FetchAll private var fetchedAttachments: [EmbeddedFileAttachment]
    @State private var store: StoreOf<TripActivityDetailFeature>

    init(
        activity: T,
        store: StoreOf<TripActivityDetailFeature>
    ) {
        self.activity = activity
        switch activity.activityType {
        case .activity:
            self._fetchedAttachments = FetchAll(
                EmbeddedFileAttachment.where { $0.activityID.eq(activity.id) }
                    .order { $0.createdDate.desc() }
            )
        case .lodging:
            self._fetchedAttachments = FetchAll(
                EmbeddedFileAttachment.where { $0.lodgingID.eq(activity.id) }
                    .order { $0.createdDate.desc() }
            )
        case .transportation:
            self._fetchedAttachments = FetchAll(
                EmbeddedFileAttachment.where { $0.transportationID.eq(activity.id) }
                    .order { $0.createdDate.desc() }
            )
        }
        self._store = State(initialValue: store)
    }

    /// Dynamic icon that updates based on current transportation type selection in edit mode
    private var currentIcon: String {
        // In edit mode for transportation activities, use the selected transportation type icon
        if store.isEditing,
           case .transportation = activity.activityType,
           let transportationType = store.editData.transportationType {
            return transportationType.systemImage
        }
        // Otherwise, use the activity's default icon
        return activity.icon
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                basicInfoSection
                locationSection
                scheduleSection
                costAndDetailsSection
                attachmentsSection

                if store.isEditing {
                    deleteButton
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(store.isEditing ? "Edit \(activity.activityType.rawValue)" : "\(activity.activityType.rawValue) Details")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button(store.isEditing ? "Save" : "Edit") {
                    if store.isEditing {
                        store.send(.saveTapped)
                    } else {
                        store.send(.startEditing)
                    }
                }
            }

            if store.isEditing {
                ToolbarItem(placement: .platformLeading) {
                    Button("Cancel") {
                        store.send(.cancelEditing)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $store.showingLegsEditor) {
            TransportationLegsEditorView(
                legs: $store.transportationLegs,
                onAddLeg: { store.send(.addLegTapped) }
            )
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
        .sheet(
            item: Binding(
                get: { store.activeSheet },
                set: { store.send(.sheetChanged($0)) }
            )
        ) { sheet in
            switch sheet {
            case .organizationPicker:
                EmptyView()
            case .map:
                if let address = displayAddress {
                    NavigationStack {
                        AddressMapView(address: address)
                            .navigationTitle(activity.displayLocation)
                            .inlineNavigationBarTitle()
                            .toolbar {
                                ToolbarItem(placement: .platformTrailing) {
                                    Button("Done") {
                                        store.send(.sheetChanged(nil))
                                    }
                                }
                            }
                    }
                }
            }
        }
        .confirmationDialog(
            "Are you sure you want to delete this \(activity.activityType.rawValue.lowercased())?",
            isPresented: Binding(
                get: { store.showDeleteConfirmation },
                set: { store.send(.deleteDialogChanged($0)) }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteConfirmed)
            }
        }
        .onAppear {
            store.send(.onAppear)
            store.send(.fetchedAttachmentsChanged(fetchedAttachments))
        }
        .onChange(of: fetchedAttachments) { _, _ in
            store.send(.fetchedAttachmentsChanged(fetchedAttachments))
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.dismissError) } }
            )
        ) {
            Button("OK") {
                store.send(.dismissError)
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Body Helpers (split to assist type-checker)

    @ViewBuilder
    private var basicInfoSection: some View {
        ActivityBasicInfoSection(
            activity: activity,
            editData: $store.editData,
            isEditing: store.isEditing,
            color: activity.color,
            icon: currentIcon,
            attachmentCount: store.attachments.count
        )
    }

    @ViewBuilder
    private var locationSection: some View {
        if !activity.supportsCustomLocation || (!store.editData.hideLocation || store.isEditing) {
            ActivityLocationSection(
                activity: activity,
                editData: $store.editData,
                isEditing: store.isEditing,
                color: activity.color,
                supportsCustomLocation: activity.supportsCustomLocation,
                showingOrganizationPicker: { store.send(.showOrganizationPicker) },
                showMap: { store.send(.sheetChanged(.map)) }
            )
        }
    }

    @ViewBuilder
    private var scheduleSection: some View {
        if activity.activityType == .transportation {
            TransportationScheduleSectionView(
                trip: activity.trip ?? Trip(name: ""),
                icon: currentIcon,
                color: activity.color,
                isEditing: store.isEditing,
                legs: $store.transportationLegs,
                legsValidationError: store.legsValidationError,
                showingLegsEditor: $store.showingLegsEditor
            )
        } else {
            ActivityScheduleSection(
                activity: activity,
                editData: $store.editData,
                isEditing: store.isEditing,
                color: activity.color,
                trip: activity.trip
            )
        }
    }

    @ViewBuilder
    private var costAndDetailsSection: some View {
        ActivityCostSection(
            activity: activity,
            editData: $store.editData,
            isEditing: store.isEditing,
            color: activity.color
        )

        ActivityDetailsSection(
            activity: activity,
            editData: $store.editData,
            isEditing: store.isEditing,
            color: activity.color,
            supportsCustomLocation: activity.supportsCustomLocation
        )
    }

    @ViewBuilder
    private var attachmentsSection: some View {
        ActivityAttachmentsSection(
            attachments: $store.attachments,
            isEditing: store.isEditing,
            color: activity.color,
            onAttachmentAdded: { attachment in
                store.send(.attachmentAdded(attachment))
            },
            onAttachmentRemoved: { attachment in
                store.send(.attachmentRemoved(attachment))
            }
        )
    }

    @ViewBuilder
    private var deleteButton: some View {
        Button(role: .destructive) {
            store.send(.deleteTapped)
        } label: {
            Label("Delete \(activity.activityType.rawValue)", systemImage: "trash.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.bottom)
    }
    
    private var displayAddress: Address? {
        if store.isEditing {
            return store.editData.customAddress ?? store.editData.organization?.address
        }
        return activity.displayAddress
    }
}
