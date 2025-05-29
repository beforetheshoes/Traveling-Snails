//
//  AddOrganizationView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI

struct AddOrganizationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let prefilledName: String?
    let onSave: (Organization) -> Void
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var website: String = ""
    @State private var selectedAddress: Address?
    @State private var showMap = false
    
    var body: some View {
        Form {
            Section("Organization Details") {
                TextField("Name", text: $name)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Website", text: $website)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            
            Section("Address") {
                AddressAutocompleteView(
                    selectedAddress: $selectedAddress,
                    placeholder: "Enter organization address"
                )
                
                if selectedAddress != nil {
                    Button("View on Map") {
                        showMap = true
                    }
                    .foregroundColor(.blue)
                }
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
                    saveOrganization()
                }
                .disabled(name.isEmpty)
            }
        }
        .onAppear {
            if let prefilledName = prefilledName {
                name = prefilledName
            }
        }
        .sheet(isPresented: $showMap) {
            if let address = selectedAddress {
                NavigationStack {
                    AddressMapView(address: address)
                        .navigationTitle("Organization Location")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showMap = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func saveOrganization() {
        let organization = Organization(
            name: name,
            phone: phone,
            email: email,
            website: website,
            address: selectedAddress ?? nil
        )
        
        modelContext.insert(organization)
        
        if let address = selectedAddress {
            modelContext.insert(address)
        }
        
        do {
            try modelContext.save()
            onSave(organization)
            dismiss()
        } catch {
            print("Failed to save organization: \(error)")
        }
    }
}

#Preview {
    AddOrganizationView(prefilledName: "Example Organization", onSave: { _ in })
}
