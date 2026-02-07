//
//  DataBrowserView.swift
//  Traveling Snails
//
//

import ComposableArchitecture
import SQLiteData
import SwiftUI

/// Comprehensive data browser and troubleshooting suite for SQLiteData
struct DataBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: StoreOf<DataBrowserFeature>

    @FetchAll private var allTrips: [Trip]
    @FetchAll private var allTransportation: [Transportation]
    @FetchAll private var allLodging: [Lodging]
    @FetchAll private var allActivities: [Activity]
    @FetchAll private var allOrganizations: [Organization]
    @FetchAll private var allAddresses: [Address]
    @FetchAll private var allAttachments: [EmbeddedFileAttachment]

    typealias IssueType = DataBrowserFeature.IssueType
    typealias DiagnosticResults = DataBrowserFeature.DiagnosticResults

    private var snapshot: DataBrowserFeature.DataSnapshot {
        .init(
            trips: allTrips,
            transportation: allTransportation,
            lodging: allLodging,
            activities: allActivities,
            organizations: allOrganizations,
            addresses: allAddresses,
            attachments: allAttachments
        )
    }

    var body: some View {
        NavigationStack {
            TabView(selection: Binding(
                get: { store.selectedTab },
                set: { store.send(.selectedTabChanged($0)) }
            )) {
                // Overview Tab
                DataBrowserOverviewTab(
                    results: store.diagnosticResults,
                    isRunning: store.isRunning,
                    onRunDiagnostic: { store.send(.runDiagnostic(snapshot)) },
                    onShowFixes: { store.send(.fixOptionsChanged(true)) }
                )
                .tabItem {
                    Label("Overview", systemImage: "chart.pie")
                }
                .tag(0)

                // Database Browser Tab
                DatabaseBrowserTab(
                    store: store.scope(state: \.databaseBrowser, action: \.databaseBrowser)
                )
                .tabItem {
                    Label("Browse", systemImage: "folder")
                }
                .tag(1)

                // Issues Tab
                DataBrowserIssuesTab(results: store.diagnosticResults) { issue in
                    store.send(.issueSelected(issue))
                }
                .tabItem {
                    Label("Issues", systemImage: "exclamationmark.triangle")
                }
                .tag(2)
                .badge(store.diagnosticResults.hasIssues ? store.diagnosticResults.totalIssues : 0)

                // Tools Tab
                ToolsTab(
                    onDataChanged: { store.send(.runDiagnostic(snapshot)) },
                    store: store.scope(state: \.tools, action: \.tools)
                )
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
            .sheet(item: Binding(
                get: { store.issueFixer },
                set: { issueFixer in
                    if issueFixer == nil {
                        store.send(.issueFixerDismissed)
                    }
                }
            )) {
                _ in
                if let issueFixerStore = store.scope(state: \.issueFixer, action: \.issueFixer) {
                    DataBrowserIssueFixerSheet(onFixed: {
                        store.send(.fixOptionsChanged(false))
                        store.send(.runDiagnostic(snapshot))
                    }, store: issueFixerStore)
                }
            }
        }
        .onAppear {
            store.send(.runDiagnostic(snapshot))
        }
    }
}

// MARK: - Overview Tab
private struct DataBrowserOverviewTab: View {
    let results: DataBrowserView.DiagnosticResults
    let isRunning: Bool
    let onRunDiagnostic: () -> Void
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
                    onRunDiagnostic()
                } label: {
                    HStack {
                        Image(systemName: isRunning ? "clock" : "stethoscope")
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading) {
                            Text("Run Full Diagnostic")
                            if let lastRun = results.lastRunDate {
                                Text("Last run: \(lastRun, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading) {
                                Text("Fix Issues")
                                Text("\(results.totalIssues) issues found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                                    .foregroundStyle(issueType.color)

                                Text(issueType.rawValue)

                                Spacer()

                                Text("\(count)")
                                    .font(.headline)
                                    .foregroundStyle(issueType.color)
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
            GridItem(.flexible()),
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
                .foregroundStyle(color)

            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 12))
    }
}

// MARK: - Issues Tab
private struct DataBrowserIssuesTab: View {
    let results: DataBrowserView.DiagnosticResults
    let onSelectIssue: (DataBrowserView.IssueType) -> Void

    @State private var expandedIssues: Set<DataBrowserView.IssueType> = []

    var body: some View {
        List {
            if !results.hasIssues {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("No Issues Found")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Your database is in good shape! All relationships are properly connected and no orphaned data was found.")
                            .font(.body)
                            .foregroundStyle(.secondary)
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
                        let isExpanded = expandedIssues.contains(issueType)
                        Section {
                            VStack(alignment: .leading, spacing: 0) {
                                // Main issue row with expand/collapse functionality
                                IssueRowWithDetailsView(
                                    type: issueType,
                                    count: count,
                                    description: getIssueDescription(for: issueType, results: results),
                                    isExpanded: isExpanded,
                                    onToggleExpanded: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            if isExpanded {
                                                expandedIssues.remove(issueType)
                                            } else {
                                                expandedIssues.insert(issueType)
                                            }
                                        }
                                    },
                                    onSelectIssue: {
                                        onSelectIssue(issueType)
                                    }
                                )

                                // Expandable detailed items list
                                if isExpanded {
                                    IssueDetailsList(
                                        issueType: issueType,
                                        results: results
                                    )
                                    .padding(.top, 8)
                                }
                            }
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
                .foregroundStyle(type.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline)

                    Spacer()

                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(type.color)
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct DataBrowserIssueFixerSheet: View {
    let onFixed: () -> Void

    @Bindable var store: StoreOf<DataBrowserIssueFixerFeature>
    @Environment(\.dismiss) private var dismiss

    init(
        onFixed: @escaping () -> Void,
        store: StoreOf<DataBrowserIssueFixerFeature>
    ) {
        self.onFixed = onFixed
        self.store = store
    }

    var body: some View {
        NavigationStack {
            VStack {
                if let issue = store.selectedIssue {
                    IssueFixerContent(
                        issue: issue,
                        results: store.results,
                        isFixing: store.isFixing,
                        fixResults: store.fixResults
                    ) {
                        store.send(.fixIssueTapped(issue))
                    }
                } else {
                    AllIssuesFixerContent(
                        results: store.results,
                        isFixing: store.isFixing,
                        fixResults: store.fixResults
                    ) {
                        store.send(.fixAllTapped)
                    }
                }
            }
            .navigationTitle(store.selectedIssue?.rawValue ?? "Fix All Issues")
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
                    .disabled(store.isFixing)
                }
            }
        }
    }
}

private struct IssueFixerContent: View {
    let issue: DataBrowserView.IssueType
    let results: DataBrowserView.DiagnosticResults
    let isFixing: Bool
    let fixResults: [String]
    let onFix: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Issue description
            VStack(spacing: 12) {
                Image(systemName: issue.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(issue.color)

                Text(issue.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(results.issueCount(for: issue)) issues found")
                    .font(.headline)
                    .foregroundStyle(issue.color)
            }

            // Fix button
            if !isFixing && fixResults.isEmpty {
                Button(action: onFix) {
                    Text("Fix \(issue.rawValue)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(issue.color)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 12))
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
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12))
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
    let onFixAll: () -> Void
    @State private var showingDetails = false

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("Fix All Issues")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(results.totalIssues) total issues found")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }

            if !isFixing && fixResults.isEmpty {
                VStack(spacing: 12) {
                    Button {
                        showingDetails.toggle()
                    } label: {
                        HStack {
                            Text(showingDetails ? "Hide Details" : "Show Details")
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    if showingDetails {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(DataBrowserView.IssueType.allCases, id: \.self) { issueType in
                                    let count = results.issueCount(for: issueType)
                                    if count > 0 {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Image(systemName: issueType.icon)
                                                    .foregroundStyle(issueType.color)
                                                Text(issueType.rawValue)
                                                    .font(.headline)
                                                Spacer()
                                                Text("\(count)")
                                                    .font(.headline)
                                                    .foregroundStyle(issueType.color)
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(getDetailedItems(for: issueType), id: \.self) { item in
                                                    Text("• \(item)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .padding(.leading, 24)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(issueType.color.opacity(0.1))
                                        .clipShape(.rect(cornerRadius: 8))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 250)
                        .background(Color(.systemGray6))
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    Button(action: onFixAll) {
                        Text("Fix All Issues")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 12))
                    }
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
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 12))
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
    }

    private func getDetailedItems(for type: DataBrowserView.IssueType) -> [String] {
        switch type {
        case .blankEntries:
            var items: [String] = []
            items.append(contentsOf: results.blankTransportation.map { "Transportation: \($0.type.rawValue) (no name)" })
            items.append(contentsOf: results.blankLodging.map { _ in "Lodging: (no name)" })
            items.append(contentsOf: results.blankActivities.map { _ in "Activity: (no name)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .orphanedData:
            var items: [String] = []
            items.append(contentsOf: results.orphanedTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name)" })
            items.append(contentsOf: results.orphanedLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name)" })
            items.append(contentsOf: results.orphanedActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name)" })
            items.append(contentsOf: results.orphanedAddresses.map { "Address: \($0.displayAddress)" })
            items.append(contentsOf: results.orphanedAttachments.map { "Attachment: \($0.fileName)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .duplicateRelationships:
            var items: [String] = []
            for (trip, duplicates) in results.duplicateTransportation {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate transportation entries")
            }
            for (trip, duplicates) in results.duplicateLodging {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate lodging entries")
            }
            for (trip, duplicates) in results.duplicateActivities {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate activity entries")
            }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .invalidTimezones:
            var items: [String] = []
            items.append(contentsOf: results.invalidTimezoneTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name) (timezone: \($0.startTZId))" })
            items.append(contentsOf: results.invalidTimezoneLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name) (timezone: \($0.checkInTZId))" })
            items.append(contentsOf: results.invalidTimezoneActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name) (timezone: \($0.startTZId))" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .invalidDates:
            var items: [String] = []
            items.append(contentsOf: results.invalidDateTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name) (end before start)" })
            items.append(contentsOf: results.invalidDateLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name) (end before start)" })
            items.append(contentsOf: results.invalidDateActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name) (end before start)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .missingOrganizations:
            return Array(results.activitiesWithoutOrganizations.prefix(10)) +
                   (results.activitiesWithoutOrganizations.count > 10 ? ["... and \(results.activitiesWithoutOrganizations.count - 10) more"] : [])

        case .unusedAddresses:
            let items = results.orphanedAddresses.map { "Address: \($0.displayAddress) - \($0.city)" }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .brokenAttachments:
            let items = results.brokenAttachments.map { "Attachment: \($0.fileName) (size: \($0.fileSize) bytes)" }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])
        }
    }
}

// MARK: - Enhanced Issue Detail Components

private struct IssueRowWithDetailsView: View {
    let type: DataBrowserView.IssueType
    let count: Int
    let description: String
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSelectIssue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main issue header
            Button(action: onToggleExpanded) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundStyle(type.color)
                                .font(.headline)

                            Text(type.rawValue)
                                .font(.headline)
                                .fontWeight(.semibold)

                            Spacer()

                            Text("\(count)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(type.color)
                        }

                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide" : "Show")
                            .font(.caption)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            // Fix button
            HStack {
                Spacer()
                Button("Fix Issues") {
                    onSelectIssue()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(type.color.opacity(0.2))
                .foregroundStyle(type.color)
                .clipShape(.rect(cornerRadius: 8))
            }
            .padding(.top, 4)
        }
    }
}

private struct IssueDetailsList: View {
    let issueType: DataBrowserView.IssueType
    let results: DataBrowserView.DiagnosticResults

    var body: some View {
        let detailedItems = getDetailedItems(for: issueType)

        if !detailedItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Affected Items:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(detailedItems, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 32)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(issueType.color.opacity(0.05))
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func getDetailedItems(for type: DataBrowserView.IssueType) -> [String] {
        switch type {
        case .blankEntries:
            var items: [String] = []
            items.append(contentsOf: results.blankTransportation.map { "Transportation: \($0.type.rawValue) (no name)" })
            items.append(contentsOf: results.blankLodging.map { _ in "Lodging: (no name)" })
            items.append(contentsOf: results.blankActivities.map { _ in "Activity: (no name)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .orphanedData:
            var items: [String] = []
            items.append(contentsOf: results.orphanedTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name)" })
            items.append(contentsOf: results.orphanedLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name)" })
            items.append(contentsOf: results.orphanedActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name)" })
            items.append(contentsOf: results.orphanedAddresses.map { "Address: \($0.displayAddress)" })
            items.append(contentsOf: results.orphanedAttachments.map { "Attachment: \($0.fileName)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .duplicateRelationships:
            var items: [String] = []
            for (trip, duplicates) in results.duplicateTransportation {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate transportation entries")
            }
            for (trip, duplicates) in results.duplicateLodging {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate lodging entries")
            }
            for (trip, duplicates) in results.duplicateActivities {
                items.append("Trip '\(trip.name)': \(duplicates.count) duplicate activity entries")
            }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .invalidTimezones:
            var items: [String] = []
            items.append(contentsOf: results.invalidTimezoneTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name) (timezone: \($0.startTZId))" })
            items.append(contentsOf: results.invalidTimezoneLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name) (timezone: \($0.checkInTZId))" })
            items.append(contentsOf: results.invalidTimezoneActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name) (timezone: \($0.startTZId))" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .invalidDates:
            var items: [String] = []
            items.append(contentsOf: results.invalidDateTransportation.map { "Transportation: \($0.name.isEmpty ? $0.type.rawValue : $0.name) (end before start)" })
            items.append(contentsOf: results.invalidDateLodging.map { "Lodging: \($0.name.isEmpty ? "Unnamed" : $0.name) (end before start)" })
            items.append(contentsOf: results.invalidDateActivities.map { "Activity: \($0.name.isEmpty ? "Unnamed" : $0.name) (end before start)" })
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .missingOrganizations:
            return Array(results.activitiesWithoutOrganizations.prefix(10)) +
                   (results.activitiesWithoutOrganizations.count > 10 ? ["... and \(results.activitiesWithoutOrganizations.count - 10) more"] : [])

        case .unusedAddresses:
            let items = results.orphanedAddresses.map { "Address: \($0.displayAddress) - \($0.city)" }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])

        case .brokenAttachments:
            let items = results.brokenAttachments.map { "Attachment: \($0.fileName) (size: \($0.fileSize) bytes)" }
            return Array(items.prefix(10)) + (items.count > 10 ? ["... and \(items.count - 10) more"] : [])
        }
    }
}
