//
//  OrganizationPicker.swift
//  Traveling Snails
//
//

import SwiftUI
import SwiftData

struct OrganizationPicker: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var organizations: [Organization]
    
    @Binding var selectedOrganization: Organization?
    @State private var showingAddOrganization = false
    @State private var searchText = ""
    
    // Get sorted organizations with None first, then alphabetical
    var sortedOrganizations: [Organization] {
        // Separate None organization from others
        let none = organizations.filter { $0.name == "None" }
        let others = organizations.filter { $0.name != "None" }.sorted { $0.name < $1.name }
        
        return none + others
    }
    
    var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return sortedOrganizations
        } else {
            // Apply search filter but maintain None-first ordering if None matches
            return sortedOrganizations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search bar
            UnifiedSearchBar(text: $searchText)
            
            List {
                // All organizations (including None first, then alphabetical)
                ForEach(filteredOrganizations) { organization in
                    Button {
                        selectedOrganization = organization
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(organization.name)
                                    .foregroundColor(.primary)
                                if !organization.phone.isEmpty {
                                    Text(organization.phone)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if selectedOrganization?.id == organization.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // "Add New" option
                if !searchText.isEmpty && !filteredOrganizations.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) }) {
                    Button {
                        showingAddOrganization = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add \"\(searchText)\"")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // General "Add New" button
                Button {
                    showingAddOrganization = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        Text("Add New Organization")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Select Organization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .disabled(selectedOrganization == nil)
            }
        }
        .sheet(isPresented: $showingAddOrganization) {
            AddOrganizationForm(
                prefilledName: searchText.isEmpty ? nil : searchText,
                onSave: { newOrg in
                    selectedOrganization = newOrg
                    showingAddOrganization = false
                }
            )
        }
    }
}

// MARK: - Add Organization Form

struct AddOrganizationForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let prefilledName: String?
    let onSave: (Organization) -> Void
    
    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    
    init(prefilledName: String? = nil, onSave: @escaping (Organization) -> Void) {
        self.prefilledName = prefilledName
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Organization Details") {
                    TextField("Organization Name", text: $name)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Website", text: $website)
                        .keyboardType(.URL)
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
                        let organization = Organization(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            website: website.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        
                        modelContext.insert(organization)
                        
                        do {
                            try modelContext.save()
                            onSave(organization)
                            dismiss()
                        } catch {
                            // Handle error appropriately
                            print("Failed to save organization: \(error)")
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let prefilledName = prefilledName {
                    name = prefilledName
                }
            }
        }
    }
}

#Preview {
    OrganizationPicker(selectedOrganization: .constant(nil))
        .modelContainer(for: Organization.self, inMemory: true)
}
