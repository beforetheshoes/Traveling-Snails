import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
struct DataBrowserFeature {
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
            case .blankEntries: "doc.text"
            case .orphanedData: "link.badge.plus"
            case .duplicateRelationships: "arrow.triangle.2.circlepath"
            case .invalidTimezones: "clock.badge.exclamationmark"
            case .invalidDates: "calendar.badge.exclamationmark"
            case .missingOrganizations: "building.2.crop.circle.badge.plus"
            case .unusedAddresses: "mappin.slash"
            case .brokenAttachments: "paperclip.badge.ellipsis"
            }
        }

        var color: Color {
            switch self {
            case .blankEntries, .orphanedData: .red
            case .duplicateRelationships, .invalidTimezones, .invalidDates: .orange
            case .missingOrganizations, .unusedAddresses, .brokenAttachments: .yellow
            }
        }
    }

    struct DiagnosticResults {
        var totalTrips: Int = 0
        var totalTransportation: Int = 0
        var totalLodging: Int = 0
        var totalActivities: Int = 0
        var totalOrganizations: Int = 0
        var totalAddresses: Int = 0
        var totalAttachments: Int = 0

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
                blankTransportation.count + blankLodging.count + blankActivities.count
            case .orphanedData:
                orphanedTransportation.count + orphanedLodging.count + orphanedActivities.count + orphanedAddresses.count + orphanedAttachments.count
            case .duplicateRelationships:
                duplicateTransportation.count + duplicateLodging.count + duplicateActivities.count
            case .invalidTimezones:
                invalidTimezoneTransportation.count + invalidTimezoneLodging.count + invalidTimezoneActivities.count
            case .invalidDates:
                invalidDateTransportation.count + invalidDateLodging.count + invalidDateActivities.count
            case .missingOrganizations:
                activitiesWithoutOrganizations.count
            case .unusedAddresses:
                orphanedAddresses.count
            case .brokenAttachments:
                brokenAttachments.count
            }
        }
    }

    struct DataSnapshot {
        var trips: [Trip]
        var transportation: [Transportation]
        var lodging: [Lodging]
        var activities: [Activity]
        var organizations: [Organization]
        var addresses: [Address]
        var attachments: [EmbeddedFileAttachment]
    }

    @ObservableState
    struct State {
        var selectedTab = 0
        var diagnosticResults = DiagnosticResults()
        var isRunning = false
        var issueFixer: DataBrowserIssueFixerFeature.State?
        var databaseBrowser = DatabaseBrowserFeature.State()
        var tools = ToolsFeature.State()
    }

    enum Action {
        case runDiagnostic(DataSnapshot)
        case selectedTabChanged(Int)
        case fixOptionsChanged(Bool)
        case issueSelected(IssueType?)
        case issueFixerDismissed
        case issueFixer(DataBrowserIssueFixerFeature.Action)
        case databaseBrowser(DatabaseBrowserFeature.Action)
        case tools(ToolsFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.tools, action: \.tools) {
            ToolsFeature()
        }
        Scope(state: \.databaseBrowser, action: \.databaseBrowser) {
            DatabaseBrowserFeature()
        }
        .ifLet(\.issueFixer, action: \.issueFixer) {
            DataBrowserIssueFixerFeature()
        }
        Reduce { state, action in
            switch action {
            case .runDiagnostic(let snapshot):
                state.isRunning = true
                state.diagnosticResults = runDiagnostic(snapshot: snapshot)
                state.isRunning = false
                return .none

            case .selectedTabChanged(let tab):
                state.selectedTab = tab
                return .none

            case .fixOptionsChanged(let showing):
                if !showing {
                    state.issueFixer = nil
                } else {
                    state.issueFixer = .init(
                        results: state.diagnosticResults,
                        selectedIssue: nil
                    )
                }
                return .none

            case .issueSelected(let issue):
                state.issueFixer = issue.map {
                    .init(
                        results: state.diagnosticResults,
                        selectedIssue: $0
                    )
                }
                return .none

            case .issueFixerDismissed:
                state.issueFixer = nil
                return .none

            case .issueFixer:
                return .none

            case .databaseBrowser:
                return .none

            case .tools:
                return .none
            }
        }
    }

    private func runDiagnostic(snapshot: DataSnapshot) -> DiagnosticResults {
        var diagnostic = DiagnosticResults()

        diagnostic.totalTrips = snapshot.trips.count
        diagnostic.totalTransportation = snapshot.transportation.count
        diagnostic.totalLodging = snapshot.lodging.count
        diagnostic.totalActivities = snapshot.activities.count
        diagnostic.totalOrganizations = snapshot.organizations.count
        diagnostic.totalAddresses = snapshot.addresses.count
        diagnostic.totalAttachments = snapshot.attachments.count

        diagnostic.blankTransportation = snapshot.transportation.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        diagnostic.blankLodging = snapshot.lodging.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        diagnostic.blankActivities = snapshot.activities.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        diagnostic.orphanedTransportation = snapshot.transportation.filter { $0.trip == nil }
        diagnostic.orphanedLodging = snapshot.lodging.filter { $0.trip == nil }
        diagnostic.orphanedActivities = snapshot.activities.filter { $0.trip == nil }

        diagnostic.orphanedAddresses = snapshot.addresses.filter { address in
            address.organizations.isEmpty &&
                address.activities.isEmpty &&
                address.lodgings.isEmpty
        }

        diagnostic.orphanedAttachments = snapshot.attachments.filter { attachment in
            attachment.activity == nil &&
                attachment.lodging == nil &&
                attachment.transportation == nil
        }

        for trip in snapshot.trips {
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

        diagnostic.invalidTimezoneTransportation = snapshot.transportation.filter {
            TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
        }
        diagnostic.invalidTimezoneLodging = snapshot.lodging.filter {
            TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
        }
        diagnostic.invalidTimezoneActivities = snapshot.activities.filter {
            TimeZone(identifier: $0.startTZId) == nil || TimeZone(identifier: $0.endTZId) == nil
        }

        diagnostic.invalidDateTransportation = snapshot.transportation.filter { $0.start >= $0.end }
        diagnostic.invalidDateLodging = snapshot.lodging.filter { $0.start >= $0.end }
        diagnostic.invalidDateActivities = snapshot.activities.filter { $0.start >= $0.end }

        var activitiesWithoutOrgs: [String] = []
        for transportation in snapshot.transportation where transportation.organization == nil {
            activitiesWithoutOrgs.append("Transportation: \(transportation.name)")
        }
        for lodging in snapshot.lodging where lodging.organization == nil {
            activitiesWithoutOrgs.append("Lodging: \(lodging.name)")
        }
        for activity in snapshot.activities where activity.organization == nil {
            activitiesWithoutOrgs.append("Activity: \(activity.name)")
        }
        diagnostic.activitiesWithoutOrganizations = activitiesWithoutOrgs

        diagnostic.brokenAttachments = snapshot.attachments.filter {
            $0.fileData == nil || $0.fileData?.isEmpty == true
        }

        diagnostic.lastRunDate = Date()
        return diagnostic
    }
}
