//
//  OrganizationDetailView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI

struct OrganizationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let organization: Organization
    
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedPhone: String = ""
    @State private var editedEmail: String = ""
    @State private var editedWebsite: String = ""
    @State private var editedAddress: Address?
    @State private var editedLogoURL: String = ""
    @State private var showingSaveError = false
    @State private var saveErrorMessage = ""
    
    var relatedTrips: [Trip] {
        let allTrips = organization.transportation.map(\.trip) + organization.lodging.map(\.trip)
        return Array(Set(allTrips))
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
            
            HStack {
                CachedAsyncImage(url: organization.logoURL, organizationId: organization.id)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading) {
                    if isEditing {
                        TextField("Organization Name", text: $editedName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(organization.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text("\(organization.transportation.count + organization.lodging.count) activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Spacer()
            
            List {
                Section("Contact Information") {
                    if isEditing {
                        HStack {
                            Image(systemName: "photo")
                                .frame(width: 24, height: 24)
                                .padding(.horizontal, 4)
                            
                            TextField("Logo URL", text: $editedLogoURL)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    HStack {
                        Image(systemName: "phone")
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 4)
                        
                        if isEditing {
                            TextField("Phone", text: $editedPhone)
                                .keyboardType(.phonePad)
                        } else {
                            Group {
                                if !organization.phone.isEmpty {
                                    SecurePhoneLink(phoneNumber: organization.phone)
                                } else {
                                    Text("Not provided")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "envelope")
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 4)
                        
                        if isEditing {
                            TextField("Email", text: $editedEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        } else {
                            Group {
                                if !organization.email.isEmpty {
                                    SecureEmailLink(email: organization.email)
                                } else {
                                    Text("Not provided")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "globe")
                            .frame(width: 24, height: 24)
                            .padding(.horizontal, 4)
                        
                        if isEditing {
                            TextField("Website", text: $editedWebsite)
                                .keyboardType(.URL)
                                .autocapitalization(.none)
                        } else {
                            Group {
                                if !organization.website.isEmpty {
                                    SecureWebsiteLink(website: organization.website)
                                } else {
                                    Text("Not provided")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(
                                organization.address.formattedAddress == "" ? "Not provided": organization.address.formattedAddress
                            )
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                    .frame(width: 24, height: 24)
                                    .padding(.horizontal, 4)
                                
                                Text("Address")
                                    .font(.headline)
                            }
                            
                            AddressAutocompleteView(
                                selectedAddress: $editedAddress,
                                placeholder: "Enter organization address"
                            )
                            .padding(.vertical, 8)
                        }
                        .padding(.vertical, 8)
                    } else {
                        HStack(alignment: .top) {
                            Image(systemName: "mappin.and.ellipse")
                                .frame(width: 24, height: 24)
                                .padding(.horizontal, 4)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if !organization.address.isEmpty {
                                    Text(organization.address.displayAddress)
                                } else {
                                    Text("Not provided")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if !isEditing {
                        AddressMapView(address: organization.address)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            Spacer()
        }
        .navigationTitle(isEditing ? "Edit Organization" : "Organization")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    HStack {
                        Button("Cancel") {
                            cancelEditing()
                        }
                        
                        Button("Save") {
                            saveChanges()
                        }
                        .disabled(editedName.isEmpty)
                    }
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text(saveErrorMessage)
        }
    }
    
    private func startEditing() {
        editedName = organization.name
        editedPhone = organization.phone
        editedEmail = organization.email
        editedWebsite = organization.website
        editedLogoURL = organization.logoURL
        editedAddress = organization.address
        isEditing = true
    }
     
    private func cancelEditing() {
        isEditing = false
        
        editedName = ""
        editedPhone = ""
        editedEmail = ""
        editedWebsite = ""
        editedLogoURL = ""
        editedAddress = nil
    }
    
    private func saveChanges() {
        organization.name = editedName
        organization.phone = editedPhone
        organization.email = editedEmail
        organization.website = editedWebsite
        organization.logoURL = editedLogoURL
        
        if let newAddress = editedAddress {
            organization.address.street = newAddress.street
            organization.address.city = newAddress.city
            organization.address.state = newAddress.state
            organization.address.country = newAddress.country
            organization.address.postalCode = newAddress.postalCode
            organization.address.latitude = newAddress.latitude
            organization.address.longitude = newAddress.longitude
            organization.address.formattedAddress = newAddress.formattedAddress
        }
        
        do {
            try modelContext.save()
            isEditing = false
        } catch {
            saveErrorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingSaveError = true
        }
    }
}

#Preview {
    NavigationStack {
        OrganizationDetailView(organization: Organization(name: "Test Organization"))
            .modelContainer(for: Organization.self, inMemory: true)
    }
}
