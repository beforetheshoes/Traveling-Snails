//
//  OrganizationPicker.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
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
    
    var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return organizations
        } else {
            return organizations.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack {
            // Search bar
            SearchBar(text: $searchText)
            
            List {
                // Existing organizations
                ForEach(filteredOrganizations) { organization in
                    Button {
                        selectedOrganization = organization
                        //dismiss()
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
            NavigationStack {
                AddOrganizationView(
                    prefilledName: searchText.isEmpty ? nil : searchText,
                    onSave: { newOrg in
                        selectedOrganization = newOrg
                        //dismiss()
                    }
                )
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search organizations...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}


#Preview {
    OrganizationPicker(selectedOrganization: .constant(nil))
        .modelContainer(for: Organization.self, inMemory: true)
}
