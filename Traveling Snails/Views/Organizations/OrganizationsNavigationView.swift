//
//  OrganizationsNavigationView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import SwiftData

struct OrganizationsNavigationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var organizations: [Organization]
    @State private var selectedOrganization: Organization?
    @State private var showingAddOrganization = false
    @State private var navigationPath = NavigationPath()

    @Binding var selectedTab: Int
    let tabIndex: Int
    
    var body: some View {
        NavigationSplitView {
            NavigationStack(path: $navigationPath) {
                List(organizations, selection: $selectedOrganization) { organization in
                    NavigationLink(value: organization) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(organization.name)
                                .font(.headline)
                            
                            if !organization.phone.isEmpty {
                                Text(organization.phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            let transportCount = organization.transportation.count
                            let lodgingCount = organization.lodging.count
                            
                            if transportCount > 0 || lodgingCount > 0 {
                                HStack {
                                    Text("\(transportCount) transportation")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    Text("•")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    Text("\(lodgingCount) lodging")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Organizations")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingAddOrganization = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddOrganization) {
                    NavigationStack {
                        AddOrganizationView(prefilledName: nil, onSave: { _ in })
                    }
                }
            }
        } detail: {
            // Detail View - Selected Organization
            if let selectedOrganization = selectedOrganization {
                OrganizationDetailView(organization: selectedOrganization)
            } else {
                ContentUnavailableView(
                    "Select an Organization",
                    systemImage: "building.2",
                    description: Text("Choose an organization from the sidebar to view its details")
                )
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == tabIndex && oldValue == tabIndex {
                navigationPath = NavigationPath()
                selectedOrganization = nil
            }
        }
    }
}

