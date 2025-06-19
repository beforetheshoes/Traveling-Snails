//
//  OrganizationManager.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/10/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Centralized manager for organization operations, especially handling the "None" organization
final class OrganizationManager {
    static let shared = OrganizationManager()
    
    private init() {}
    
    // MARK: - None Organization Management
    
    /// Get or create the unique "None" organization
    func ensureNoneOrganization(in context: ModelContext) -> AppResult<Organization> {
        do {
            let predicate = #Predicate<Organization> { org in
                org.name == "None"
            }
            let descriptor = FetchDescriptor<Organization>(predicate: predicate)
            let noneOrganizations = try context.fetch(descriptor)
            
            if noneOrganizations.isEmpty {
                Logger.shared.logDatabase("Creating None organization", success: true)
                return createNoneOrganization(in: context)
            } else if noneOrganizations.count == 1 {
                Logger.shared.logDatabase("Found existing None organization", success: true)
                return .success(noneOrganizations[0])
            } else {
                Logger.shared.warning("Found multiple None organizations, consolidating", category: .organization)
                return consolidateNoneOrganizations(noneOrganizations, in: context)
            }
        } catch {
            Logger.shared.logError(error, message: "Failed to fetch None organizations", category: .organization)
            return .failure(.databaseLoadFailed("Failed to fetch None organizations: \(error.localizedDescription)"))
        }
    }
    
    private func createNoneOrganization(in context: ModelContext) -> AppResult<Organization> {
        let noneOrg = Organization(name: "None")
        context.insert(noneOrg)
        
        return context.safeSave(context: "Creating None organization")
            .map { noneOrg }
    }
    
    private func consolidateNoneOrganizations(
        _ noneOrganizations: [Organization],
        in context: ModelContext
    ) -> AppResult<Organization> {
        guard let primaryNone = noneOrganizations.first else {
            return .failure(.organizationNotFound("None organization"))
        }
        
        // Move all relationships to the primary None organization
        for duplicate in noneOrganizations.dropFirst() {
            // Transportation relationships
            for transport in duplicate.transportation {
                transport.organization = primaryNone
            }
            
            // Lodging relationships
            for lodging in duplicate.lodging {
                lodging.organization = primaryNone
            }
            
            // Activity relationships
            for activity in duplicate.activity {
                activity.organization = primaryNone
            }
            
            // Delete the duplicate
            context.delete(duplicate)
        }
        
        return context.safeSave(context: "Consolidating None organizations")
            .map { primaryNone }
    }
    
    // MARK: - Organization Validation
    
    /// Check if an organization can be safely deleted
    func canDelete(_ organization: Organization) -> AppResult<Bool> {
        // Cannot delete None organization
        if organization.name == "None" {
            return .failure(.cannotDeleteNoneOrganization)
        }
        
        // Check if organization is in use
        let totalUsage = organization.transportation.count +
                        organization.lodging.count +
                        organization.activity.count
        
        if totalUsage > 0 {
            return .failure(.organizationInUse(organization.name, totalUsage))
        }
        
        return .success(true)
    }
    
    /// Safely delete an organization with validation
    func delete(_ organization: Organization, from context: ModelContext) -> AppResult<Void> {
        // Validate deletion
        switch canDelete(organization) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        
        // Perform deletion
        return context.safeDelete(organization, context: "Deleting organization: \(organization.name)")
    }
    
    // MARK: - Organization Creation and Updates
    
    /// Create a new organization with validation
    func create(
        name: String,
        phone: String = "",
        email: String = "",
        website: String = "",
        logoURL: String = "",
        address: Address? = nil,
        in context: ModelContext
    ) -> AppResult<Organization> {
        // Validate input
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure(.missingRequiredField("Organization name"))
        }
        
        // Check for duplicates
        if findOrganization(named: trimmedName, in: context) != nil {
            return .failure(.duplicateEntry("Organization with name '\(trimmedName)' already exists"))
        }
        
        // Validate email format if provided
        if !email.isEmpty && !isValidEmail(email) {
            return .failure(.invalidInput("Email address"))
        }
        
        // Validate website URL if provided
        if !website.isEmpty && !isValidURL(website) {
            return .failure(.invalidInput("Website URL"))
        }
        
        // Create organization
        let organization = Organization(
            name: trimmedName,
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            website: website.trimmingCharacters(in: .whitespacesAndNewlines),
            logoURL: logoURL.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address
        )
        
        context.insert(organization)
        
        if let address = address {
            context.insert(address)
        }
        
        return context.safeSave(context: "Creating organization: \(trimmedName)")
            .map { organization }
    }
    
    /// Update an existing organization with validation
    func update(
        _ organization: Organization,
        name: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoURL: String? = nil,
        address: Address? = nil,
        in context: ModelContext
    ) -> AppResult<Void> {
        // Update fields if provided
        if let name = name {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                return .failure(.missingRequiredField("Organization name"))
            }
            
            // Check for duplicates (excluding current organization)
            if let existingOrg = findOrganization(named: trimmedName, in: context),
               existingOrg.id != organization.id {
                return .failure(.duplicateEntry("Organization with name '\(trimmedName)' already exists"))
            }
            
            organization.name = trimmedName
        }
        
        if let phone = phone {
            organization.phone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if let email = email {
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEmail.isEmpty && !isValidEmail(trimmedEmail) {
                return .failure(.invalidInput("Email address"))
            }
            organization.email = trimmedEmail
        }
        
        if let website = website {
            let trimmedWebsite = website.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedWebsite.isEmpty && !isValidURL(trimmedWebsite) {
                return .failure(.invalidInput("Website URL"))
            }
            organization.website = trimmedWebsite
        }
        
        if let logoURL = logoURL {
            let trimmedLogoURL = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLogoURL.isEmpty && !isValidURL(trimmedLogoURL) {
                return .failure(.invalidInput("Logo URL"))
            }
            organization.logoURL = trimmedLogoURL
        }
        
        if let address = address {
            if organization.address == nil {
                context.insert(address)
            }
            organization.address = address
        }
        
        return context.safeSave(context: "Updating organization: \(organization.name)")
    }
    
    // MARK: - Organization Search and Retrieval
    
    /// Find an organization by name
    func findOrganization(named name: String, in context: ModelContext) -> Organization? {
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchName = trimmedName // Capture in local variable for predicate
            let predicate = #Predicate<Organization> { org in
                org.name.localizedStandardContains(searchName)
            }
            let descriptor = FetchDescriptor<Organization>(predicate: predicate, sortBy: [SortDescriptor(\.name)])
            let organizations = try context.fetch(descriptor)
            
            // Look for exact match first
            return organizations.first { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
        } catch {
            Logger.shared.logError(error, message: "Failed to search for organization", category: .organization)
            return nil
        }
    }
    
    /// Search organizations by text
    func searchOrganizations(
        query: String,
        in context: ModelContext,
        limit: Int = 50
    ) -> AppResult<[Organization]> {
        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedQuery.isEmpty {
                // Return all organizations
                var descriptor = FetchDescriptor<Organization>(
                    sortBy: [SortDescriptor(\.name)]
                )
                descriptor.fetchLimit = limit
                let organizations = try context.fetch(descriptor)
                return .success(organizations)
            } else {
                // Search by name, phone, email, or website
                let searchQuery = trimmedQuery // Capture in local variable for predicate
                let predicate = #Predicate<Organization> { org in
                    org.name.localizedStandardContains(searchQuery) ||
                    org.phone.localizedStandardContains(searchQuery) ||
                    org.email.localizedStandardContains(searchQuery) ||
                    org.website.localizedStandardContains(searchQuery)
                }
                var descriptor = FetchDescriptor<Organization>(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.name)]
                )
                descriptor.fetchLimit = limit
                let organizations = try context.fetch(descriptor)
                return .success(organizations)
            }
        } catch {
            Logger.shared.logError(error, message: "Failed to search organizations", category: .organization)
            return .failure(.databaseLoadFailed("Failed to search organizations: \(error.localizedDescription)"))
        }
    }
    
    /// Get organization usage statistics
    func getUsageStatistics(for organization: Organization) -> OrganizationUsage {
        return OrganizationUsage(
            transportationCount: organization.transportation.count,
            lodgingCount: organization.lodging.count,
            activityCount: organization.activity.count
        )
    }
    
    /// Get all organizations with their usage statistics
    func getAllOrganizationsWithUsage(in context: ModelContext) -> AppResult<[OrganizationWithUsage]> {
        do {
            let descriptor = FetchDescriptor<Organization>(
                sortBy: [SortDescriptor(\.name)]
            )
            let organizations = try context.fetch(descriptor)
            
            let organizationsWithUsage = organizations.map { org in
                OrganizationWithUsage(
                    organization: org,
                    usage: getUsageStatistics(for: org)
                )
            }
            
            return .success(organizationsWithUsage)
        } catch {
            Logger.shared.logError(error, message: "Failed to fetch organizations with usage", category: .organization)
            return .failure(.databaseLoadFailed("Failed to fetch organizations: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - Data Cleanup and Maintenance
    
    /// Find and clean up orphaned organizations (not used by any activities)
    func findOrphanedOrganizations(in context: ModelContext) -> AppResult<[Organization]> {
        do {
            let descriptor = FetchDescriptor<Organization>()
            let organizations = try context.fetch(descriptor)
            
            let orphaned = organizations.filter { org in
                // Don't consider "None" as orphaned
                guard org.name != "None" else { return false }
                
                // Check if organization is used
                let totalUsage = org.transportation.count + org.lodging.count + org.activity.count
                return totalUsage == 0
            }
            
            return .success(orphaned)
        } catch {
            Logger.shared.logError(error, message: "Failed to find orphaned organizations", category: .organization)
            return .failure(.databaseLoadFailed("Failed to find orphaned organizations: \(error.localizedDescription)"))
        }
    }
    
    /// Clean up orphaned organizations
    func cleanupOrphanedOrganizations(in context: ModelContext) -> AppResult<Int> {
        switch findOrphanedOrganizations(in: context) {
        case .success(let orphaned):
            var deletedCount = 0
            
            for org in orphaned {
                context.delete(org)
                deletedCount += 1
            }
            
            return context.safeSave(context: "Cleaning up \(deletedCount) orphaned organizations")
                .map { deletedCount }
                
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // MARK: - Validation Helpers
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme != nil && url.host != nil
    }
}

// MARK: - Supporting Types

struct OrganizationUsage {
    let transportationCount: Int
    let lodgingCount: Int
    let activityCount: Int
    
    var totalCount: Int {
        transportationCount + lodgingCount + activityCount
    }
    
    var isEmpty: Bool {
        totalCount == 0
    }
    
    var description: String {
        var components: [String] = []
        if transportationCount > 0 {
            components.append("\(transportationCount) transportation")
        }
        if lodgingCount > 0 {
            components.append("\(lodgingCount) lodging")
        }
        if activityCount > 0 {
            components.append("\(activityCount) activities")
        }
        
        return components.isEmpty ? "No usage" : components.joined(separator: ", ")
    }
}

struct OrganizationWithUsage {
    let organization: Organization
    let usage: OrganizationUsage
    
    var isOrphaned: Bool {
        usage.isEmpty && organization.name != "None"
    }
}

// MARK: - Organization Extension

extension Organization {
    /// Convenience method to get the None organization
    static func getNoneOrganization(in context: ModelContext) -> Organization? {
        switch OrganizationManager.shared.ensureNoneOrganization(in: context) {
        case .success(let org):
            return org
        case .failure(let error):
            Logger.shared.logError(error, message: "Failed to get None organization", category: .organization)
            return nil
        }
    }
    
    /// Check if this is the None organization
    var isNoneOrganization: Bool {
        name == "None"
    }
    
    /// Get usage statistics for this organization
    var usageStatistics: OrganizationUsage {
        OrganizationManager.shared.getUsageStatistics(for: self)
    }
    
    /// Check if this organization can be deleted safely
    var canBeDeletedSafely: Bool {
        switch OrganizationManager.shared.canDelete(self) {
        case .success(let canDelete):
            return canDelete
        case .failure:
            return false
        }
    }
    
    /// Safely delete this organization
    func safeDelete(from context: ModelContext) -> AppResult<Void> {
        OrganizationManager.shared.delete(self, from: context)
    }
    
    /// Update this organization with validation
    func safeUpdate(
        name: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoURL: String? = nil,
        address: Address? = nil,
        in context: ModelContext
    ) -> AppResult<Void> {
        OrganizationManager.shared.update(
            self,
            name: name,
            phone: phone,
            email: email,
            website: website,
            logoURL: logoURL,
            address: address,
            in: context
        )
    }
}

// MARK: - SwiftUI Integration

@Observable
@MainActor
final class OrganizationStore {
    var organizations: [Organization] = []
    var searchText = ""
    var isLoading = false
    var errorMessage: String?
    
    private let modelContext: ModelContext
    private let manager = OrganizationManager.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadOrganizations()
    }
    
    var filteredOrganizations: [Organization] {
        if searchText.isEmpty {
            return organizations
        } else {
            return organizations.filter { org in
                org.name.localizedCaseInsensitiveContains(searchText) ||
                org.phone.localizedCaseInsensitiveContains(searchText) ||
                org.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func loadOrganizations() {
        isLoading = true
        errorMessage = nil
        
        manager.getAllOrganizationsWithUsage(in: modelContext).handleResult(
            context: "Loading organizations",
            onSuccess: { [weak self] organizationsWithUsage in
                self?.organizations = organizationsWithUsage.map(\.organization)
                self?.isLoading = false
            },
            onFailure: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
    }
    
    func createOrganization(
        name: String,
        phone: String = "",
        email: String = "",
        website: String = "",
        logoURL: String = ""
    ) {
        isLoading = true
        errorMessage = nil
        
        manager.create(
            name: name,
            phone: phone,
            email: email,
            website: website,
            logoURL: logoURL,
            in: modelContext
        ).handleResult(
            context: "Creating organization",
            onSuccess: { [weak self] _ in
                self?.loadOrganizations() // Refresh list
            },
            onFailure: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
    }
    
    func deleteOrganization(_ organization: Organization) {
        isLoading = true
        errorMessage = nil
        
        organization.safeDelete(from: modelContext).handleResult(
            context: "Deleting organization",
            onSuccess: { [weak self] _ in
                self?.loadOrganizations() // Refresh list
            },
            onFailure: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
    }
    
    func getNoneOrganization() -> Organization? {
        Organization.getNoneOrganization(in: modelContext)
    }
    
    func searchOrganizations(query: String) {
        manager.searchOrganizations(query: query, in: modelContext).handleResult(
            context: "Searching organizations",
            onSuccess: { [weak self] results in
                self?.organizations = results
            },
            onFailure: { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
        )
    }
    
    func cleanupOrphanedOrganizations() {
        isLoading = true
        errorMessage = nil
        
        manager.cleanupOrphanedOrganizations(in: modelContext).handleResult(
            context: "Cleaning up orphaned organizations",
            onSuccess: { [weak self] deletedCount in
                Logger.shared.info("Deleted \(deletedCount) orphaned organizations", category: .organization)
                self?.loadOrganizations() // Refresh list
            },
            onFailure: { [weak self] error in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        )
    }
}

// MARK: - Organization Picker View

struct OrganizationPickerView: View {
    @Binding var selectedOrganization: Organization?
    @State private var store: OrganizationStore
    @State private var showingAddOrganization = false
    
    init(selectedOrganization: Binding<Organization?>, modelContext: ModelContext) {
        self._selectedOrganization = selectedOrganization
        self._store = State(wrappedValue: OrganizationStore(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                UnifiedSearchBar.organizations(text: $store.searchText)
                    .onChange(of: store.searchText) { _, newValue in
                        if !newValue.isEmpty {
                            store.searchOrganizations(query: newValue)
                        } else {
                            store.loadOrganizations()
                        }
                    }
                
                // Organizations list
                if store.isLoading {
                    ProgressView("Loading organizations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.filteredOrganizations.isEmpty {
                    ContentUnavailableView(
                        "No Organizations",
                        systemImage: "building.2",
                        description: Text(store.searchText.isEmpty ?
                            "Add your first organization" :
                            "No organizations match your search")
                    )
                } else {
                    List(store.filteredOrganizations) { organization in
                        OrganizationRowView(
                            organization: organization,
                            isSelected: selectedOrganization?.id == organization.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedOrganization = organization
                        }
                    }
                }
            }
            .navigationTitle("Select Organization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Organization") {
                        showingAddOrganization = true
                    }
                }
            }
            .sheet(isPresented: $showingAddOrganization) {
                AddOrganizationView { newOrganization in
                    store.createOrganization(name: newOrganization.name)
                    showingAddOrganization = false
                }
            }
            .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
                Button("OK") {
                    store.errorMessage = nil
                }
            } message: {
                if let error = store.errorMessage {
                    Text(error)
                }
            }
            .onAppear {
                if store.organizations.isEmpty {
                    store.loadOrganizations()
                }
            }
        }
    }
}

struct OrganizationRowView: View {
    let organization: Organization
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(organization.name)
                    .font(.headline)
                
                if !organization.phone.isEmpty || !organization.email.isEmpty {
                    HStack {
                        if !organization.phone.isEmpty {
                            Label(organization.phone, systemImage: "phone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if !organization.email.isEmpty {
                            Label(organization.email, systemImage: "envelope")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !organization.usageStatistics.isEmpty {
                    Text(organization.usageStatistics.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddOrganizationView: View {
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
                            // Handle error - could show an alert
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
    
