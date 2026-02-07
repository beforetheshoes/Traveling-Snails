import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct DataBrowserIssueFixerFeature {
    @ObservableState
    struct State: Identifiable {
        let id = UUID()
        let results: DataBrowserFeature.DiagnosticResults
        let selectedIssue: DataBrowserFeature.IssueType?
        var isFixing = false
        var fixResults: [String] = []
    }

    enum Action: Equatable {
        case fixIssueTapped(DataBrowserFeature.IssueType)
        case fixAllTapped
        case fixCompleted([String])
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fixIssueTapped(let issue):
                state.isFixing = true
                state.fixResults = []
                let results = state.results
                return .run { send in
                    let output = await fix(issue: issue, with: results, using: database)
                    await send(.fixCompleted(output))
                }

            case .fixAllTapped:
                state.isFixing = true
                state.fixResults = ["Starting to fix all issues..."]
                let results = state.results
                return .run { send in
                    var allOutputs = ["Starting to fix all issues..."]
                    for issue in DataBrowserFeature.IssueType.allCases where results.issueCount(for: issue) > 0 {
                        let output = await fix(issue: issue, with: results, using: database)
                        allOutputs.append(contentsOf: output)
                    }
                    allOutputs.append("✅ All issues have been processed")
                    await send(.fixCompleted(allOutputs))
                }

            case .fixCompleted(let outputs):
                state.isFixing = false
                state.fixResults = outputs
                return .none
            }
        }
    }

    private func fix(
        issue: DataBrowserFeature.IssueType,
        with results: DataBrowserFeature.DiagnosticResults,
        using database: DatabaseWriter
    ) async -> [String] {
        var output: [String] = []

        switch issue {
        case .blankEntries:
            output.append("Deleting blank entries...")
            do {
                let transportationIDs = results.blankTransportation.map(\.id)
                let lodgingIDs = results.blankLodging.map(\.id)
                let activityIDs = results.blankActivities.map(\.id)

                try await database.write { db in
                    if !transportationIDs.isEmpty {
                        try Transportation.where { $0.id.in(transportationIDs) }.delete().execute(db)
                    }
                    if !lodgingIDs.isEmpty {
                        try Lodging.where { $0.id.in(lodgingIDs) }.delete().execute(db)
                    }
                    if !activityIDs.isEmpty {
                        try Activity.where { $0.id.in(activityIDs) }.delete().execute(db)
                    }
                }
                output.append("Deleted blank transportation, lodging, and activity entries")
            } catch {
                Logger.shared.error("Failed to delete blank entries: \(error.localizedDescription)", category: .database)
                output.append("❌ \(L(L10n.Database.Operations.cleanupFailed))")
            }

        case .orphanedData:
            output.append("Deleting orphaned data...")
            do {
                let transportationIDs = results.orphanedTransportation.map(\.id)
                let lodgingIDs = results.orphanedLodging.map(\.id)
                let activityIDs = results.orphanedActivities.map(\.id)
                let addressIDs = results.orphanedAddresses.map(\.id)
                let attachmentIDs = results.orphanedAttachments.map(\.id)

                try await database.write { db in
                    if !transportationIDs.isEmpty {
                        try Transportation.where { $0.id.in(transportationIDs) }.delete().execute(db)
                    }
                    if !lodgingIDs.isEmpty {
                        try Lodging.where { $0.id.in(lodgingIDs) }.delete().execute(db)
                    }
                    if !activityIDs.isEmpty {
                        try Activity.where { $0.id.in(activityIDs) }.delete().execute(db)
                    }
                    if !addressIDs.isEmpty {
                        try Address.where { $0.id.in(addressIDs) }.delete().execute(db)
                    }
                    if !attachmentIDs.isEmpty {
                        try EmbeddedFileAttachment.where { $0.id.in(attachmentIDs) }.delete().execute(db)
                    }
                }
                output.append("Deleted orphaned transportation, lodging, activities, addresses, and attachments")
            } catch {
                Logger.shared.error("Failed to delete orphaned data: \(error.localizedDescription)", category: .database)
                output.append("❌ \(L(L10n.Database.Operations.cleanupFailed))")
            }

        case .duplicateRelationships:
            output.append("Duplicate relationship repair is not supported in SQLiteData")

        case .invalidTimezones:
            output.append("Fixing invalid timezones...")
            let defaultTZ = TimeZone.current.identifier
            do {
                try await database.write { db in
                    for transportation in results.invalidTimezoneTransportation {
                        try Transportation.find(transportation.id).update {
                            $0.startTZId = defaultTZ
                            $0.endTZId = defaultTZ
                        }.execute(db)
                    }
                    for lodging in results.invalidTimezoneLodging {
                        try Lodging.find(lodging.id).update {
                            $0.checkInTZId = defaultTZ
                            $0.checkOutTZId = defaultTZ
                        }.execute(db)
                    }
                    for activity in results.invalidTimezoneActivities {
                        try Activity.find(activity.id).update {
                            $0.startTZId = defaultTZ
                            $0.endTZId = defaultTZ
                        }.execute(db)
                    }
                }
                output.append("Fixed timezones for transportation, lodging, and activities")
            } catch {
                Logger.shared.error("Failed to fix timezones: \(error.localizedDescription)", category: .database)
                output.append("❌ \(L(L10n.Database.Operations.cleanupFailed))")
            }

        case .invalidDates:
            output.append("Fixing invalid dates...")
            do {
                try await database.write { db in
                    for transportation in results.invalidDateTransportation {
                        try Transportation.find(transportation.id).update {
                            $0.end = transportation.start.addingTimeInterval(3600)
                        }.execute(db)
                    }
                    for lodging in results.invalidDateLodging {
                        try Lodging.find(lodging.id).update {
                            $0.end = lodging.start.addingTimeInterval(24 * 3600)
                        }.execute(db)
                    }
                    for activity in results.invalidDateActivities {
                        try Activity.find(activity.id).update {
                            $0.end = activity.start.addingTimeInterval(3600)
                        }.execute(db)
                    }
                }
                output.append("Fixed invalid dates for transportation, lodging, and activities")
            } catch {
                Logger.shared.error("Failed to fix dates: \(error.localizedDescription)", category: .database)
                output.append("❌ \(L(L10n.Database.Operations.cleanupFailed))")
            }

        case .missingOrganizations, .unusedAddresses, .brokenAttachments:
            output.append("This fix is not yet implemented")
        }

        return output
    }
}
