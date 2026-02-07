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

    @FetchAll private var allAttachments: [EmbeddedFileAttachment]
    @State private var store: StoreOf<TripActivityDetailFeature>

    init(
        activity: T,
        store: StoreOf<TripActivityDetailFeature>? = nil
    ) {
        self.activity = activity
        let resolvedStore = store ?? Store(
            initialState: TripActivityDetailFeature.State(
                snapshot: TripActivityDetailFeature.ActivityTarget(activity: activity)
            )
        ) {
            TripActivityDetailFeature()
        }
        self._store = State(initialValue: resolvedStore)
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
        @Bindable var store = self.store

        ScrollView {
            VStack(spacing: 24) {
                // Basic Info Section (replaces headerSection)
                ActivityBasicInfoSection(
                    activity: activity,
                    editData: $store.editData,
                    isEditing: store.isEditing,
                    color: activity.color,
                    icon: currentIcon,
                    attachmentCount: store.attachments.count
                )

                // Location Section (if applicable)
                if !activity.supportsCustomLocation || (!store.editData.hideLocation || store.isEditing) {
                    ActivityLocationSection(
                        activity: activity,
                        editData: $store.editData,
                        isEditing: store.isEditing,
                        color: activity.color,
                        supportsCustomLocation: activity.supportsCustomLocation,
                        showingOrganizationPicker: { store.send(.sheetChanged(.organizationPicker)) },
                        showMap: { store.send(.sheetChanged(.map)) }
                    )
                }

                // Schedule Section
                ActivityScheduleSection(
                    activity: activity,
                    editData: $store.editData,
                    isEditing: store.isEditing,
                    color: activity.color,
                    trip: activity.trip
                )

                // Cost & Payment Section
                ActivityCostSection(
                    activity: activity,
                    editData: $store.editData,
                    isEditing: store.isEditing,
                    color: activity.color
                )

                // Details Section
                ActivityDetailsSection(
                    activity: activity,
                    editData: $store.editData,
                    isEditing: store.isEditing,
                    color: activity.color,
                    supportsCustomLocation: activity.supportsCustomLocation
                )

                // File Attachments Section (always visible)
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

                // Delete Button (only in edit mode)
                if store.isEditing {
                    deleteButton
                }
            }
            .padding(.horizontal, 16)
        }
        .navigationTitle(store.isEditing ? "Edit \(activity.activityType.rawValue)" : "\(activity.activityType.rawValue) Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(store.isEditing ? "Save" : "Edit") {
                    if store.isEditing {
                        store.send(.saveTapped)
                    } else {
                        store.send(.startEditing)
                    }
                }
            }

            if store.isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.cancelEditing)
                    }
                }
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
                NavigationStack {
                    OrganizationPicker(selectedOrganization: $store.editData.organization)
                }
            case .map:
                if let address = displayAddress {
                    NavigationStack {
                        AddressMapView(address: address)
                            .navigationTitle(activity.displayLocation)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
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
        .onChange(of: allAttachments) { _, _ in
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
    
    private var fetchedAttachments: [EmbeddedFileAttachment] {
        allAttachments.filter { attachment in
            switch activity.activityType {
            case .activity:
                return attachment.activityID == activity.id
            case .lodging:
                return attachment.lodgingID == activity.id
            case .transportation:
                return attachment.transportationID == activity.id
            }
        }
    }

    private var displayAddress: Address? {
        if store.isEditing {
            return store.editData.customAddress ?? store.editData.organization?.address
        }
        return activity.displayAddress
    }
}
