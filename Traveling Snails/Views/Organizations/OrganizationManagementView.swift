//
//  OrganizationManagementView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import SwiftData

struct OrganizationManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var organizations: [Organization]
    
    @State private var showingAddOrganization = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    
    var body: some View {
        List {
            ForEach(organizations) { organization in
                OrganizationRowView(organization: organization)
            }
            .onDelete(perform: deleteOrganizations)
        }
        .navigationTitle("Organizations")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add") {
                    showingAddOrganization = true
                }
            }
        }
        .sheet(isPresented: $showingAddOrganization) {
            AddOrganizationView(prefilledName: "", onSave: { _ in })
        }
        .alert("Cannot Delete", isPresented: $showDeleteError) {
            Button("OK") { }
        } message: {
            Text(deleteErrorMessage)
        }
    }
    
    private func deleteOrganizations(offsets: IndexSet) {
        for index in offsets {
            let organization = organizations[index]
            deleteOrganizationSafely(organization)
        }
    }
    
    private func deleteOrganizationSafely(_ organization: Organization) {
        if canDeleteOrganization(organization) {
            modelContext.delete(organization)
            try? modelContext.save()
        } else {
            let transportCount = organization.transportation.count
            let lodgingCount = organization.lodging.count
            deleteErrorMessage = "Cannot delete '\(organization.name)'. It's used by \(transportCount) transportation and \(lodgingCount) lodging records."
            showDeleteError = true
        }
    }
    
    private func canDeleteOrganization(_ organization: Organization) -> Bool {
        return organization.transportation.isEmpty && organization.lodging.isEmpty
    }
}

// Separate view component to break up complexity
struct OrganizationRowView: View {
    let organization: Organization
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            organizationName
            phoneNumber
            usageInfo
        }
    }
    
    private var organizationName: some View {
        Text(organization.name)
            .font(.headline)
    }
    
    @ViewBuilder
    private var phoneNumber: some View {
        if !organization.phone.isEmpty {
            Text(organization.phone)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var usageInfo: some View {
        let transportCount = organization.transportation.count
        let lodgingCount = organization.lodging.count
        
        if transportCount > 0 || lodgingCount > 0 {
            Text("Used by \(transportCount) transportation, \(lodgingCount) lodging")
                .font(.caption2)
                .foregroundColor(.blue)
        }
    }
}
