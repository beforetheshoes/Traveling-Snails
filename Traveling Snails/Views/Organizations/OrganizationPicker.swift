//
//  OrganizationPicker.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

struct OrganizationPicker: View {
    private enum ActiveSheet: Identifiable {
        case addOrganization

        var id: Int { 0 }
    }

    @Environment(\.dismiss) private var dismiss
    @FetchAll private var organizations: [Organization]

    @Binding var selectedOrganization: Organization?
    @State private var store: StoreOf<OrganizationPickerFeature>

    init(
        selectedOrganization: Binding<Organization?>,
        store: StoreOf<OrganizationPickerFeature>? = nil
    ) {
        self._selectedOrganization = selectedOrganization
        let resolvedStore = store ?? Store(
            initialState: OrganizationPickerFeature.State(
                selectedOrganizationID: selectedOrganization.wrappedValue?.id
            )
        ) {
            OrganizationPickerFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    private var sortedOrganizations: [Organization] {
        let none = organizations.filter { $0.name == "None" }
        let others = organizations.filter { $0.name != "None" }.sorted { $0.name < $1.name }
        return none + others
    }

    private var filteredOrganizations: [Organization] {
        guard !store.searchText.isEmpty else { return sortedOrganizations }
        return sortedOrganizations.filter {
            $0.name.localizedCaseInsensitiveContains(store.searchText)
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

                if !store.searchText.isEmpty && !filteredOrganizations.contains(where: { $0.name.localizedCaseInsensitiveContains(store.searchText) }) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    store.send(.doneTapped)
                }
                .disabled(store.selectedOrganizationID == nil)
            }
        }
        .sheet(item: addOrganizationSheet) { sheet in
            switch sheet {
            case .addOrganization:
                AddOrganizationForm(
                    prefilledName: store.searchText.isEmpty ? nil : store.searchText
                ) { organizationID in
                    store.send(.organizationCreated(organizationID))
                }
            }
        }
        .onChange(of: store.shouldDismiss) { _, shouldDismiss in
            guard shouldDismiss else { return }
            if let selectedID = store.selectedOrganizationID {
                selectedOrganization = organizations.first(where: { $0.id == selectedID })
            }
            dismiss()
            store.send(.dismissHandled)
        }
    }

    private var addOrganizationSheet: Binding<ActiveSheet?> {
        Binding(
            get: {
                store.showingAddOrganization ? .addOrganization : nil
            },
            set: { newValue in
                store.send(.addSheetChanged(newValue != nil))
            }
        )
    }
}

struct AddOrganizationForm: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Organization.ID) -> Void
    @State private var store: StoreOf<AddOrganizationFeature>

    init(
        prefilledName: String? = nil,
        onSave: @escaping (Organization.ID) -> Void,
        store: StoreOf<AddOrganizationFeature>? = nil
    ) {
        self.onSave = onSave
        let resolvedStore = store ?? Store(initialState: AddOrganizationFeature.State(prefilledName: prefilledName)) {
            AddOrganizationFeature()
        }
        self._store = State(initialValue: resolvedStore)
    }

    var body: some View {
        @Bindable var store = self.store
        NavigationStack {
            Form {
                Section("Organization Details") {
                    TextField("Organization Name", text: $store.name)
                    TextField("Phone", text: $store.phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $store.email)
                        .keyboardType(.emailAddress)
                    TextField("Website", text: $store.website)
                        .keyboardType(.URL)

                    HStack {
                        TextField("Logo URL", text: $store.logoURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
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
            guard shouldDismiss, let organizationID = store.createdOrganizationID else { return }
            onSave(organizationID)
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
    OrganizationPicker(selectedOrganization: .constant(nil))
}
