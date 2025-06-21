//
//  DataBrowserView.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 6/2/25.
//

import SwiftUI
import SwiftData

/// Comprehensive data browser and troubleshooting suite for SwiftData
struct DataBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allTrips: [Trip]
    @Query private var allTransportation: [Transportation]
    @Query private var allLodging: [Lodging]
    @Query private var allActivities: [Activity]
    @Query private var allOrganizations: [Organization]
    @Query private var allAddresses: [Address]
    @Query private var allAttachments: [EmbeddedFileAttachment]
    
    @State private var selectedTab = 0
    @State private var diagnosticResults: DiagnosticResults = DiagnosticResults()
    @State private var isRunning = false
    @State private var showingFixOptions = false
    @State private var selectedIssue: IssueType?
    
    enum IssueType: String, CaseIterable {
        case blankEntries = "Blank Entries"
        case orphanedData = "Orphaned Data"
        case duplicateRelationships = "Duplicate Relationships"
        case invalidTimezones = "Invalid Timezones"
        case invalidDates = "Invalid Dates"
        case missingOrganizations = "Missing Organizations"
        case unusedAddresses = "Unused Addresses"
        case brokenAttachments = "Broken Attachments"
        
        var icon: String {
            switch self {
            case .blankEntries: return "doc.text"
            case .orphanedData: return "link.badge.plus"
            case .duplicateRelationships: return "arrow.triangle.2.circlepath"
            case .invalidTimezones: return "clock.badge.exclamationmark"
            case .invalidDates: return "calendar.badge.exclamationmark"
            case .missingOrganizations: return "building.2.crop.circle.badge.plus"
            case .unusedAddresses: return "mappin.slash"
            case .brokenAttachments: return "paperclip.badge.ellipsis"
            }
        }
        
        var color: Color {
            switch self {
            case .blankEntries, .orphanedData: return .red
            case .duplicateRelationships, .invalidTimezones, .invalidDates: return .orange
            case .missingOrganizations, .unusedAddresses, .brokenAttachments: return .yellow
            }
        }
    }
    
    struct DiagnosticResults {
        // Data counts
        var totalTrips: Int = 0
        var totalTransportation: Int = 0
        var totalLodging: Int = 0
        var totalActivities: Int = 0
        var totalOrganizations: Int = 0
        var totalAddresses: Int = 0
        var totalAttachments: Int = 0
        
        // Issues
        var blankTransportation: [Transportation] = []
        var blankLodging: [Lodging] = []
        var blankActivities: [Activity] = []
        
        var orphanedTransportation: [Transportation] = []
        var orphanedLodging: [Lodging] = []
        var orphanedActivities: [Activity] = []
        var orphanedAddresses: [Address] = []
        var orphanedAttachments: [EmbeddedFileAttachment] = []
        
        var duplicateTransportation: [(Trip, [Transportation])] = []
        var duplicateLodging: [(Trip, [Lodging])] = []
        var duplicateActivities: [(Trip, [Activity])] = []
        
        var invalidTimezoneTransportation: [Transportation] = []
        var invalidTimezoneLodging: [Lodging] = []
        var invalidTimezoneActivities: [Activity] = []
        
        var invalidDateTransportation: [Transportation] = []
        var invalidDateLodging: [Lodging] = []
        var invalidDateActivities: [Activity] = []
        
        var activitiesWithoutOrganizations: [String] = []
        var brokenAttachments: [EmbeddedFileAttachment] = []
        
        var lastRunDate: Date?
        
        var totalIssues: Int {
            blankTransportation.count + blankLodging.count + blankActivities.count +
            orphanedTransportation.count + orphanedLodging.count + orphanedActivities.count +
            orphanedAddresses.count + orphanedAttachments.count +
            duplicateTransportation.count + duplicateLodging.count + duplicateActivities.count +
            invalidTimezoneTransportation.count + invalidTimezoneLodging.count + invalidTimezoneActivities.count +
            invalidDateTransportation.count + invalidDateLodging.count + invalidDateActivities.count +
            activitiesWithoutOrganizations.count + brokenAttachments.count
        }
        
        var hasIssues: Bool { totalIssues > 0 }
        
        func issueCount(for type: IssueType) -> Int {
            switch type {
            case .blankEntries:
                return blankTransportation.count + blankLodging.count + blankActivities.count
            case .orphanedData:
                return orphanedTransportation.count + orphanedLodging.count + orphanedActivities.count + orphanedAddresses.count + orphanedAttachments.count
            case .duplicateRelationships:
                return duplicateTransportation.count + duplicateLodging.count + duplicateActivities.count
            case .invalidTimezones:
                return invalidTimezoneTransportation.count + invalidTimezoneLodging.count + invalidTimezoneActivities.count
            case .invalidDates:
                return invalidDateTransportation.count + invalidDateLodging.count + invalidDateActivities.count
            case .missingOrganizations:
                return activitiesWithoutOrganizations.count
            case .unusedAddresses:
                return orphanedAddresses.count
            case .brokenAttachments:
                return brokenAttachments.count
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Overview Tab
                DataBrowserOverviewTab(
                    results: diagnosticResults,
                    isRunning: isRunning,
                    onRunDiagnostic: runComprehensiveDiagnostic,
                    onShowFixes: { showingFixOptions = true }
                )
                .tabItem {
                    Label("Overview", systemImage: "chart.pie")
                }
                .tag(0)
                
                // Database Browser Tab
                DatabaseBrowserTab()
                .tabItem {
                    Label("Browse", systemImage: "folder")
                }
                .tag(1)
                
                // Issues Tab
                DataBrowserIssuesTab(results: diagnosticResults, onSelectIssue: { issue in
                    selectedIssue = issue
                    showingFixOptions = true
                })
                .tabItem {
                    Label("Issues", systemImage: "exclamationmark.triangle")
                }
                .tag(2)
                .badge(diagnosticResults.hasIssues ? diagnosticResults.totalIssues : 0)
                
                // Tools Tab
                ToolsTab(modelContext: modelContext, onDataChanged: {
                    Task { await runComprehensiveDiagnostic() }
                })
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                }
                .tag(3)
            }
            .navigationTitle("Data Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFixOptions) {
                DataBrowserIssueFixerSheet(
                    results: diagnosticResults,
                    selectedIssue: selectedIssue,
                    modelContext: modelContext,
                    onFixed: {
                        showingFixOptions = false
                        selectedIssue = nil
                        Task { await runComprehensiveDiagnostic() }
                    }
                )
            }
        }
        .onAppear {
            Task { await runComprehensiveDiagnostic() }
        }
    }
    
    private func runComprehensiveDiagnostic() async {
        await MainActor.run { isRunning = true }
        
        let results = await withCheckedContinuation { continuation in
            Task {
                var diagnostic = DiagnosticResults()
                
                // Count totals
                diagnostic.totalTrips = allTrips.count
                diagnostic.totalTransportation = allTransportation.count
                diagnostic.totalLodging = allLodging.count
                diagnostic.totalActivities = allActivities.count
                diagnostic.totalOrganizations = allOrganizations.count
                diagnostic.totalAddresses = allAddresses.count
                diagnostic.totalAttachments = allAttachments.count
                
                // Find blank entries
                diagnostic.blankTransportation = allTransportation.filter {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                diagnostic.blankLodging = allLodging.filter {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                diagnostic.blankActivities = allActivities.filter {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                
                // Find orphaned entries
                diagnostic.orphanedTransportation = allTransportation.filter { $0.trip == nil }
                diagnostic.orphanedLodging = allLodging.filter { $0.trip == nil }
                diagnostic.orphanedActivities = allActivities.filter { $0.trip == nil }
                
                // Find orphaned addresses
                diagnostic.orphanedAddresses = allAddresses.filter { address in
                    (address.organizations?.isEmpty ?? true) &&
                    (address.activities?.isEmpty ?? true) &&
                    (address.lodgings?.isEmpty ?? true)
                }
                
                // Find orphaned attachments
                diagnostic.orphanedAttachments = allAttachments.filter { attachment in
                    attachment.activity == nil &&
                    attachment.lodging == nil &&
                    attachment.transportation == nil
                }
                
                // Check for duplicate relationships
                for trip in allTrips {
                    let transportationUniqueIds = Set(trip.transportation.map { $0.id })
                    if transportationUniqueIds.count != trip.transportation.count {
                        diagnostic.duplicateTransportation.append((trip, trip.transportation))
                    }
                    
                    let lodgingUniqueIds = Set(trip.lodging.map { $0.id })
                    if lodgingUniqueIds.count != trip.lodging.count {
                        diagnostic.duplicateLodging.append((trip, trip.lodging))
                    }
                    
                    let activityUniqueIds = Set(trip.activity.map { $0.id })
                    if activityUniqueIds.count != trip.activity.count {
                        diagnostic.duplicateActivities.append((trip, trip.activity))
                    }
                }
                
                // Check for invalid timezones
                diagnostic.invalidTimezoneTransportation = allTransportation.filter {
                    TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
                }
                diagnostic.invalidTimezoneLodging = allLodging.filter {
                    TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
                }
                diagnostic.invalidTimezoneActivities = allActivities.filter {
                    TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
                }
                
                // Check for invalid dates
                diagnostic.invalidDateTransportation = allTransportation.filter { $0.start >= $0.end }
                diagnostic.invalidDateLodging = allLodging.filter { $0.start >= $0.end }
                diagnostic.invalidDateActivities = allActivities.filter { $0.start >= $0.end }
                
                // Check for activities without organizations
                var activitiesWithoutOrgs: [String] = []
                for transportation in allTransportation {
                    if transportation.organization == nil {
                        activitiesWithoutOrgs.append("Transportation: \(transportation.name)")
                    }
                }
                for lodging in allLodging {
                    if lodging.organization == nil {
                        activitiesWithoutOrgs.append("Lodging: \(lodging.name)")
                    }
                }
                for activity in allActivities {
                    if activity.organization == nil {
                        activitiesWithoutOrgs.append("Activity: \(activity.name)")
                    }
                }
                diagnostic.activitiesWithoutOrganizations = activitiesWithoutOrgs
                
                // Check for broken attachments
                diagnostic.brokenAttachments = allAttachments.filter {
                    $0.fileData == nil || $0.fileData?.isEmpty == true
                }
                
                diagnostic.lastRunDate = Date()
                continuation.resume(returning: diagnostic)
            }
        }
        
        await MainActor.run {
            diagnosticResults = results
            isRunning = false
        }
    }
}

// MARK: - Overview Tab
private struct DataBrowserOverviewTab: View {
    let results: DataBrowserView.DiagnosticResults
    let isRunning: Bool
    let onRunDiagnostic: () async -> Void
    let onShowFixes: () -> Void
    
    var body: some View {
        List {
            Section("Database Summary") {
                DatabaseSummaryGrid(results: results)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            Section("Diagnostic Actions") {
                Button {
                    Task { await onRunDiagnostic() }
                } label: {
                    HStack {
                        Image(systemName: isRunning ? "clock" : "stethoscope")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Run Full Diagnostic")
                            if let lastRun = results.lastRunDate {
                                Text("Last run: \(lastRun, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isRunning)
                
                if results.hasIssues {
                    Button {
                        onShowFixes()
                    } label: {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading) {
                                Text("Fix Issues")
                                Text("\(results.totalIssues) issues found")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            if results.hasIssues {
                Section("Quick Issue Summary") {
                    ForEach(DataBrowserView.IssueType.allCases, id: \.self) { issueType in
                        let count = results.issueCount(for: issueType)
                        if count > 0 {
                            HStack {
                                Image(systemName: issueType.icon)
                                    .foregroundColor(issueType.color)
                                
                                Text(issueType.rawValue)
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.headline)
                                    .foregroundColor(issueType.color)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Database Summary Grid
private struct DatabaseSummaryGrid: View {
    let results: DataBrowserView.DiagnosticResults
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            DatabaseStatCard(title: "Trips", count: results.totalTrips, icon: "airplane", color: .blue)
            DatabaseStatCard(title: "Transportation", count: results.totalTransportation, icon: "car", color: .green)
            DatabaseStatCard(title: "Lodging", count: results.totalLodging, icon: "bed.double", color: .orange)
            DatabaseStatCard(title: "Activities", count: results.totalActivities, icon: "ticket", color: .purple)
            DatabaseStatCard(title: "Organizations", count: results.totalOrganizations, icon: "building.2", color: .red)
            DatabaseStatCard(title: "Addresses", count: results.totalAddresses, icon: "mappin", color: .cyan)
            DatabaseStatCard(title: "Attachments", count: results.totalAttachments, icon: "paperclip", color: .brown)
            DatabaseStatCard(
                title: "Issues",
                count: results.totalIssues,
                icon: results.hasIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
                color: results.hasIssues ? .red : .green
            )
        }
        .padding()
    }
}

// MARK: - Database Stat Card
private struct DatabaseStatCard: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Issues Tab
private struct DataBrowserIssuesTab: View {
    let results: DataBrowserView.DiagnosticResults
    let onSelectIssue: (DataBrowserView.IssueType) -> Void
    
    var body: some View {
        List {
            if !results.hasIssues {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("No Issues Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your database is in good shape! All relationships are properly connected and no orphaned data was found.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(DataBrowserView.IssueType.allCases, id: \.self) { issueType in
                    let count = results.issueCount(for: issueType)
                    if count > 0 {
                        Section {
                            Button {
                                onSelectIssue(issueType)
                            } label: {
                                IssueRowView(
                                    type: issueType,
                                    count: count,
                                    description: getIssueDescription(for: issueType, results: results)
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
    }
    
    private func getIssueDescription(for type: DataBrowserView.IssueType, results: DataBrowserView.DiagnosticResults) -> String {
        switch type {
        case .blankEntries:
            var items: [String] = []
            if !results.blankTransportation.isEmpty { items.append("\(results.blankTransportation.count) transportation") }
            if !results.blankLodging.isEmpty { items.append("\(results.blankLodging.count) lodging") }
            if !results.blankActivities.isEmpty { items.append("\(results.blankActivities.count) activities") }
            return "Entries with no name: " + items.joined(separator: ", ")
            
        case .orphanedData:
            var items: [String] = []
            if !results.orphanedTransportation.isEmpty { items.append("\(results.orphanedTransportation.count) transportation") }
            if !results.orphanedLodging.isEmpty { items.append("\(results.orphanedLodging.count) lodging") }
            if !results.orphanedActivities.isEmpty { items.append("\(results.orphanedActivities.count) activities") }
            if !results.orphanedAddresses.isEmpty { items.append("\(results.orphanedAddresses.count) addresses") }
            if !results.orphanedAttachments.isEmpty { items.append("\(results.orphanedAttachments.count) attachments") }
            return "Data not linked to trips: " + items.joined(separator: ", ")
            
        case .duplicateRelationships:
            var items: [String] = []
            if !results.duplicateTransportation.isEmpty { items.append("\(results.duplicateTransportation.count) trip transportation") }
            if !results.duplicateLodging.isEmpty { items.append("\(results.duplicateLodging.count) trip lodging") }
            if !results.duplicateActivities.isEmpty { items.append("\(results.duplicateActivities.count) trip activities") }
            return "Duplicate relationships: " + items.joined(separator: ", ")
            
        case .invalidTimezones:
            var items: [String] = []
            if !results.invalidTimezoneTransportation.isEmpty { items.append("\(results.invalidTimezoneTransportation.count) transportation") }
            if !results.invalidTimezoneLodging.isEmpty { items.append("\(results.invalidTimezoneLodging.count) lodging") }
            if !results.invalidTimezoneActivities.isEmpty { items.append("\(results.invalidTimezoneActivities.count) activities") }
            return "Invalid timezone identifiers: " + items.joined(separator: ", ")
            
        case .invalidDates:
            var items: [String] = []
            if !results.invalidDateTransportation.isEmpty { items.append("\(results.invalidDateTransportation.count) transportation") }
            if !results.invalidDateLodging.isEmpty { items.append("\(results.invalidDateLodging.count) lodging") }
            if !results.invalidDateActivities.isEmpty { items.append("\(results.invalidDateActivities.count) activities") }
            return "End dates before start dates: " + items.joined(separator: ", ")
            
        case .missingOrganizations:
            return "Activities without organizations assigned"
            
        case .unusedAddresses:
            return "Addresses not referenced by any items"
            
        case .brokenAttachments:
            return "File attachments with missing or corrupted data"
        }
    }
}

private struct IssueRowView: View {
    let type: DataBrowserView.IssueType
    let count: Int
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundColor(type.color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(type.color)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Issue Fixer Sheet
struct DataBrowserIssueFixerSheet: View {
    let results: DataBrowserView.DiagnosticResults
    let selectedIssue: DataBrowserView.IssueType?
    let modelContext: ModelContext
    let onFixed: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isFixing = false
    @State private var fixResults: [String] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                if let issue = selectedIssue {
                    IssueFixerContent(
                        issue: issue,
                        results: results,
                        isFixing: isFixing,
                        fixResults: fixResults,
                        onFix: { await fixIssue(issue) }
                    )
                } else {
                    AllIssuesFixerContent(
                        results: results,
                        isFixing: isFixing,
                        fixResults: fixResults,
                        onFixAll: { await fixAllIssues() }
                    )
                }
            }
            .navigationTitle(selectedIssue?.rawValue ?? "Fix All Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onFixed()
                        dismiss()
                    }
                    .disabled(isFixing)
                }
            }
        }
    }
    
    private func fixIssue(_ issue: DataBrowserView.IssueType) async {
        await MainActor.run {
            isFixing = true
            fixResults = []
        }
        
        var results: [String] = []
        
        switch issue {
        case .blankEntries:
            results.append("Deleting blank entries...")
            
            for transportation in self.results.blankTransportation {
                modelContext.delete(transportation)
                results.append("Deleted blank transportation")
            }
            
            for lodging in self.results.blankLodging {
                modelContext.delete(lodging)
                results.append("Deleted blank lodging")
            }
            
            for activity in self.results.blankActivities {
                modelContext.delete(activity)
                results.append("Deleted blank activity")
            }
            
        case .orphanedData:
            results.append("Deleting orphaned data...")
            
            for item in self.results.orphanedTransportation {
                modelContext.delete(item)
                results.append("Deleted orphaned transportation: \(item.name)")
            }
            
            for item in self.results.orphanedLodging {
                modelContext.delete(item)
                results.append("Deleted orphaned lodging: \(item.name)")
            }
            
            for item in self.results.orphanedActivities {
                modelContext.delete(item)
                results.append("Deleted orphaned activity: \(item.name)")
            }
            
            for item in self.results.orphanedAddresses {
                modelContext.delete(item)
                results.append("Deleted orphaned address")
            }
            
            for item in self.results.orphanedAttachments {
                modelContext.delete(item)
                results.append("Deleted orphaned attachment: \(item.originalFileName)")
            }
            
        case .duplicateRelationships:
            results.append("Fixing duplicate relationships...")
            
            for (trip, transportation) in self.results.duplicateTransportation {
                let unique = Array(Set(transportation))
                trip.transportation = unique
                results.append("Fixed duplicate transportation in trip: \(trip.name)")
            }
            
            for (trip, lodging) in self.results.duplicateLodging {
                let unique = Array(Set(lodging))
                trip.lodging = unique
                results.append("Fixed duplicate lodging in trip: \(trip.name)")
            }
            
            for (trip, activities) in self.results.duplicateActivities {
                let unique = Array(Set(activities))
                trip.activity = unique
                results.append("Fixed duplicate activities in trip: \(trip.name)")
            }
            
        case .invalidTimezones:
            results.append("Fixing invalid timezones...")
            
            let defaultTZ = TimeZone.current.identifier
            
            for transportation in self.results.invalidTimezoneTransportation {
                if TimeZone(identifier: transportation.startTZId) == nil {
                    transportation.startTZId = defaultTZ
                }
                if TimeZone(identifier: transportation.endTZId) == nil {
                    transportation.endTZId = defaultTZ
                }
                results.append("Fixed timezone for transportation: \(transportation.name)")
            }
            
            for lodging in self.results.invalidTimezoneLodging {
                if TimeZone(identifier: lodging.startTZId) == nil {
                    lodging.startTZId = defaultTZ
                }
                if TimeZone(identifier: lodging.endTZId) == nil {
                    lodging.endTZId = defaultTZ
                }
                results.append("Fixed timezone for lodging: \(lodging.name)")
            }
            
            for activity in self.results.invalidTimezoneActivities {
                if TimeZone(identifier: activity.startTZId) == nil {
                    activity.startTZId = defaultTZ
                }
                if TimeZone(identifier: activity.endTZId) == nil {
                    activity.endTZId = defaultTZ
                }
                results.append("Fixed timezone for activity: \(activity.name)")
            }
            
        case .invalidDates:
            results.append("Fixing invalid dates...")
            
            for transportation in self.results.invalidDateTransportation {
                transportation.end = transportation.start.addingTimeInterval(3600) // Add 1 hour
                results.append("Fixed dates for transportation: \(transportation.name)")
            }
            
            for lodging in self.results.invalidDateLodging {
                lodging.end = lodging.start.addingTimeInterval(24 * 3600) // Add 1 day
                results.append("Fixed dates for lodging: \(lodging.name)")
            }
            
            for activity in self.results.invalidDateActivities {
                activity.end = activity.start.addingTimeInterval(3600) // Add 1 hour
                results.append("Fixed dates for activity: \(activity.name)")
            }
            
        case .missingOrganizations, .unusedAddresses, .brokenAttachments:
            results.append("This fix is not yet implemented")
        }
        
        do {
            try modelContext.save()
            results.append("✅ All changes saved successfully")
        } catch {
            results.append("❌ Error saving changes: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            fixResults = results
            isFixing = false
        }
    }
    
    private func fixAllIssues() async {
        await MainActor.run {
            isFixing = true
            fixResults = ["Starting to fix all issues..."]
        }
        
        // Fix each issue type
        for issueType in DataBrowserView.IssueType.allCases {
            if results.issueCount(for: issueType) > 0 {
                await fixIssue(issueType)
            }
        }
        
        await MainActor.run {
            fixResults.append("✅ All issues have been processed")
            isFixing = false
        }
    }
}

private struct IssueFixerContent: View {
    let issue: DataBrowserView.IssueType
    let results: DataBrowserView.DiagnosticResults
    let isFixing: Bool
    let fixResults: [String]
    let onFix: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Issue description
            VStack(spacing: 12) {
                Image(systemName: issue.icon)
                    .font(.system(size: 60))
                    .foregroundColor(issue.color)
                
                Text(issue.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(results.issueCount(for: issue)) issues found")
                    .font(.headline)
                    .foregroundColor(issue.color)
            }
            
            // Fix button
            if !isFixing && fixResults.isEmpty {
                Button {
                    Task { await onFix() }
                } label: {
                    Text("Fix \(issue.rawValue)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(issue.color)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            // Progress or results
            if isFixing {
                VStack {
                    ProgressView("Fixing issues...")
                        .padding()
                }
            } else if !fixResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(fixResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

private struct AllIssuesFixerContent: View {
    let results: DataBrowserView.DiagnosticResults
    let isFixing: Bool
    let fixResults: [String]
    let onFixAll: () async -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("Fix All Issues")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(results.totalIssues) total issues found")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            if !isFixing && fixResults.isEmpty {
                Button {
                    Task { await onFixAll() }
                } label: {
                    Text("Fix All Issues")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            if isFixing {
                VStack {
                    ProgressView("Fixing all issues...")
                        .padding()
                }
            } else if !fixResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(fixResults, id: \.self) { result in
                            Text(result)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}
