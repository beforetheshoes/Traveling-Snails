//
//  OrganizationPicker.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct OrganizationPicker: View {
    @Environment(\.dismiss) private var dismiss
    @FetchAll private var organizationRecords: [Organization]

    @Binding var selectedOrganization: Organization?
    @State private var store: StoreOf<OrganizationPickerFeature>

    init(
        selectedOrganization: Binding<Organization?>,
        store: StoreOf<OrganizationPickerFeature>
    ) {
        self._selectedOrganization = selectedOrganization
        self._store = State(initialValue: store)
    }

    private var sortedOrganizations: [Organization] {
        let none = organizationRecords.filter { $0.name == "None" }
        let others = organizationRecords.filter { $0.name != "None" }.sorted { $0.name < $1.name }
        return none + others
    }

    private var filteredOrganizations: [Organization] {
        guard !store.searchText.isEmpty else { return sortedOrganizations }
        return sortedOrganizations.filter {
            $0.name.localizedStandardContains(store.searchText)
        }
    }

    var body: some View {
        @Bindable var store = self.store

        VStack {
            SearchBarView(text: $store.searchText)

            List {
                ForEach(filteredOrganizations) { organization in
                    Button {
                        store.send(.organizationTapped(organization.id))
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(organization.name)
                                    .foregroundStyle(.primary)
                                if !organization.phone.isEmpty {
                                    Text(organization.phone)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if store.selectedOrganizationID == organization.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                if !store.searchText.isEmpty && !filteredOrganizations.contains(where: { $0.name.localizedStandardContains(store.searchText) }) {
                    Button {
                        store.send(.addNewTapped)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Add \"\(store.searchText)\"")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Button {
                    store.send(.addNewTapped)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                        Text("Add New Organization")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Organization")
        .inlineNavigationBarTitle()
        .toolbar {
            ToolbarItem(placement: .platformTrailing) {
                Button("Done") {
                    store.send(.doneTapped)
                }
                .disabled(store.selectedOrganizationID == nil)
            }
        }
        .navigationDestination(
            item: $store.scope(state: \.addOrganization, action: \.addOrganization)
        ) { addStore in
            AddOrganizationForm(store: addStore)
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            if let selectedID = store.selectedOrganizationID {
                selectedOrganization = organizationRecords.first(where: { $0.id == selectedID })
            }
            dismiss()
            store.send(.dismissHandled)
        }
    }
}

struct AddOrganizationForm: View {
    @Environment(\.dismiss) private var dismiss

    @State private var store: StoreOf<AddOrganizationFeature>

    init(store: StoreOf<AddOrganizationFeature>) {
        self._store = State(initialValue: store)
    }

    var body: some View {
        @Bindable var store = self.store
        NavigationStack {
            Form {
                Section("Organization Details") {
                    TextField("Organization Name", text: $store.name)
                    TextField("Phone", text: $store.phone)
                        .platformKeyboardType(.phonePad)
                    TextField("Email", text: $store.email)
                        .platformKeyboardType(.emailAddress)
                    TextField("Website", text: $store.website)
                        .platformKeyboardType(.URL)

                    HStack {
                        TextField("Logo URL", text: $store.logoURL)
                            .platformKeyboardType(.URL)
                            .noAutocapitalization()
                            .onChange(of: store.logoURL) { _, newValue in
                                store.send(.logoURLChanged(newValue))
                            }

                        securityIndicator(for: store.logoURLSecurityLevel)
                    }
                }

                Section("Address") {
                    AddressAutocompleteView(
                        selectedAddress: $store.selectedAddress,
                        placeholder: "Enter organization address"
                    )
                }
            }
            .navigationTitle("Add Organization")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .platformLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .platformTrailing) {
                    Button("Save") {
                        store.send(.saveTapped)
                    }
                    .disabled(!store.canSave)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .alert("Invalid URL", isPresented: $store.showBlockedURLAlert) {
                Button("OK") {
                    store.send(.dismissBlockedURLAlert)
                }
            } message: {
                Text(store.errorMessage)
            }
            .alert("Suspicious URL", isPresented: $store.showSuspiciousURLAlert) {
                Button("Cancel") {
                    store.send(.dismissSuspiciousURLAlert)
                }
                Button("Save Anyway") {
                    store.send(.saveConfirmedAfterWarning)
                }
            } message: {
                Text(store.errorMessage)
            }
            .alert("Save Error", isPresented: $store.showSaveErrorAlert) {
                Button("OK") {
                    store.send(.dismissSaveErrorAlert)
                }
            } message: {
                Text(store.errorMessage)
            }
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            store.send(.dismissHandled)
        }
    }

    private func securityIndicator(for level: SecureURLHandler.URLSecurityLevel) -> some View {
        Group {
            switch level {
            case .safe:
                if !store.logoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            case .suspicious:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .blocked:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 24, height: 24)
    }
}

#Preview {
    OrganizationPicker(
        selectedOrganization: .constant(nil),
        store: StoreOf<OrganizationPickerFeature>.init(initialState: OrganizationPickerFeature.State()) {
            OrganizationPickerFeature()
        }
    )
}
