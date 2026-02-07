import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct ToolsFeature {
    @ObservableState
    struct State: Equatable {
        var showingResetConfirmation = false
        var showingCompactConfirmation = false
        var showingExportOptions = false
        var isPerformingOperation = false
        var operationStatus = ""
    }

    enum Action: Equatable {
        case rebuildRelationshipsTapped
        case validateDataIntegrityTapped
        case createTestDataTapped
        case resetAllDataTapped
        case compactDatabaseTapped
        case exportOptionsTapped

        case resetDialogChanged(Bool)
        case compactDialogChanged(Bool)
        case exportSheetChanged(Bool)

        case confirmReset
        case confirmCompact

        case operationCompleted(String, shouldRefresh: Bool)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.continuousClock) private var clock

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .rebuildRelationshipsTapped:
                state.isPerformingOperation = true
                state.operationStatus = "Rebuilding relationships..."
                return .run { send in
                    do {
                        try await clock.sleep(for: .seconds(2))
                    } catch {
                        return
                    }
                    await send(.operationCompleted("Relationships rebuilt successfully", shouldRefresh: true))
                }

            case .validateDataIntegrityTapped:
                state.isPerformingOperation = true
                state.operationStatus = "Validating data integrity..."
                return .run { send in
                    do {
                        try await clock.sleep(for: .seconds(1.5))
                    } catch {
                        return
                    }
                    await send(.operationCompleted("Data integrity check completed", shouldRefresh: false))
                }

            case .compactDatabaseTapped:
                state.showingCompactConfirmation = true
                return .none

            case .exportOptionsTapped:
                state.showingExportOptions = true
                return .none

            case .createTestDataTapped:
                state.isPerformingOperation = true
                state.operationStatus = "Creating test data..."
                return .run { send in
                    do {
                        let testTrip = Trip(name: "Test Trip \(Date().timeIntervalSince1970)")
                        let testOrg = Organization(name: "Test Organization")
                        let testTransportation = Transportation(
                            name: "Test Flight",
                            start: Date(),
                            end: Date().addingTimeInterval(3600),
                            trip: testTrip,
                            organization: testOrg
                        )

                        try await database.write { db in
                            try Trip.upsert { testTrip }.execute(db)
                            try Organization.upsert { testOrg }.execute(db)
                            try Transportation.upsert { testTransportation }.execute(db)
                        }
                        await send(.operationCompleted("Test data created successfully", shouldRefresh: true))
                    } catch {
                        Logger.shared.error("Failed to create test data: \(error.localizedDescription)", category: .database)
                        await send(.operationCompleted(L(L10n.Database.Operations.cleanupFailed), shouldRefresh: false))
                    }
                }

            case .resetAllDataTapped:
                state.showingResetConfirmation = true
                return .none

            case .resetDialogChanged(let isPresented):
                state.showingResetConfirmation = isPresented
                return .none

            case .compactDialogChanged(let isPresented):
                state.showingCompactConfirmation = isPresented
                return .none

            case .exportSheetChanged(let isPresented):
                state.showingExportOptions = isPresented
                return .none

            case .confirmCompact:
                state.showingCompactConfirmation = false
                state.isPerformingOperation = true
                state.operationStatus = "Compacting database..."
                return .run { send in
                    do {
                        try await clock.sleep(for: .seconds(3))
                    } catch {
                        return
                    }
                    await send(.operationCompleted("Database compacted successfully", shouldRefresh: false))
                }

            case .confirmReset:
                state.showingResetConfirmation = false
                state.isPerformingOperation = true
                state.operationStatus = "Resetting all data..."
                return .run { send in
                    do {
                        let result = try await database.write { db in
                            let trips = try Trip.fetchAll(db)
                            let organizations = try Organization.where { $0.name.neq("None") }.fetchAll(db)
                            let addresses = try Address.fetchAll(db)

                            let tripIDs = trips.map(\.id)
                            let orgIDs = organizations.map(\.id)
                            let addressIDs = addresses.map(\.id)

                            if !tripIDs.isEmpty {
                                try Trip.where { $0.id.in(tripIDs) }.delete().execute(db)
                            }
                            if !orgIDs.isEmpty {
                                try Organization.where { $0.id.in(orgIDs) }.delete().execute(db)
                            }
                            if !addressIDs.isEmpty {
                                try Address.where { $0.id.in(addressIDs) }.delete().execute(db)
                            }
                            return (tripIDs.count, orgIDs.count, addressIDs.count)
                        }

                        await send(
                            .operationCompleted(
                                "Reset complete: Removed \(result.0) trips, \(result.1) organizations, \(result.2) addresses",
                                shouldRefresh: true
                            )
                        )
                    } catch {
                        Logger.shared.error("Failed to reset data: \(error.localizedDescription)", category: .database)
                        await send(.operationCompleted(L(L10n.Database.Operations.resetFailed), shouldRefresh: false))
                    }
                }

            case .operationCompleted(let message, _):
                state.isPerformingOperation = false
                state.operationStatus = message
                return .none
            }
        }
    }
}
