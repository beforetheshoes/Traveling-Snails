import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct DatabaseCleanupFeature {
    @ObservableState
    struct State: Equatable {
        var tripCount = 0
        var organizationCount = 0
        var addressCount = 0

        var showingDeleteConfirmation = false
        var showingTestDataConfirmation = false
        var isDeleting = false
        var deleteResult = ""
    }

    enum Action: Equatable {
        case onAppear
        case countsLoaded(trips: Int, organizations: Int, addresses: Int)

        case removeTestDataTapped
        case resetAllDataTapped
        case testDataDialogChanged(Bool)
        case deleteDialogChanged(Bool)
        case testDataConfirmed
        case resetAllConfirmed

        case cleanupCompleted(String)
        case cleanupFailed(String)
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    do {
                        let counts = try await database.read { db in
                            (
                                try Trip.fetchCount(db),
                                try Organization.fetchCount(db),
                                try Address.fetchCount(db)
                            )
                        }
                        await send(.countsLoaded(
                            trips: counts.0,
                            organizations: counts.1,
                            addresses: counts.2
                        ))
                    } catch {
                        await send(.cleanupFailed(L(L10n.Database.Operations.cleanupFailed)))
                    }
                }

            case .countsLoaded(let trips, let organizations, let addresses):
                state.tripCount = trips
                state.organizationCount = organizations
                state.addressCount = addresses
                return .none

            case .removeTestDataTapped:
                state.showingTestDataConfirmation = true
                return .none

            case .resetAllDataTapped:
                state.showingDeleteConfirmation = true
                return .none

            case .testDataDialogChanged(let isPresented):
                state.showingTestDataConfirmation = isPresented
                return .none

            case .deleteDialogChanged(let isPresented):
                state.showingDeleteConfirmation = isPresented
                return .none

            case .testDataConfirmed:
                state.showingTestDataConfirmation = false
                state.isDeleting = true
                state.deleteResult = ""
                return .run { send in
                    do {
                        let (deletedTrips, deletedOrganizations) = try await removeTestData(in: database)
                        await send(.cleanupCompleted("Removed \(deletedTrips) test trips and \(deletedOrganizations) test organizations"))
                        await send(.onAppear)
                    } catch {
                        await send(.cleanupFailed(L(L10n.Database.Operations.cleanupFailed)))
                    }
                }

            case .resetAllConfirmed:
                state.showingDeleteConfirmation = false
                state.isDeleting = true
                state.deleteResult = ""
                return .run { send in
                    do {
                        let result = try await resetAllData(in: database)
                        await send(
                            .cleanupCompleted(
                                "Reset complete: Removed \(result.trips) trips, \(result.organizations) organizations, \(result.addresses) addresses"
                            )
                        )
                        await send(.onAppear)
                    } catch {
                        await send(.cleanupFailed(L(L10n.Database.Operations.resetFailed)))
                    }
                }

            case .cleanupCompleted(let message):
                state.isDeleting = false
                state.deleteResult = message
                return .none

            case .cleanupFailed(let message):
                state.isDeleting = false
                state.deleteResult = message
                return .none
            }
        }
    }
}

private func removeTestData(in database: DatabaseWriter) async throws -> (Int, Int) {
    let testTripPatterns = [
        "test trip", "debug", "sample", "demo", "example",
        "Trip 0", "Trip 1", "Trip 2", "Trip 3", "Trip 4", "Trip 5",
        "Performance Test", "Query Trip", "Infinite Recreation",
        "Relationship Test", "Complex Trip", "Large Trip",
        "Sync Test", "Pattern Test", "Environment Test",
        "Activity \\d+", "Hotel \\d+", "Flight \\d+",
    ]

    let testOrgPatterns = [
        "test", "debug", "sample", "demo", "example",
        "Org 0", "Org 1", "Org 2", "Org 3", "Org 4", "Org 5",
        "Performance", "Large Org", "Sync Test", "Hotel", "Airline",
    ]

    return try await database.write { db in
        let trips = try Trip.fetchAll(db)
        let organizations = try Organization.fetchAll(db)

        let exactTestNames = ["unprotected trip", "protected trip"]

        let tripIDsToDelete = trips.filter { trip in
            let tripName = trip.name.lowercased()
            let isExactMatch = exactTestNames.contains(tripName)
            let isPatternMatch = testTripPatterns.contains { pattern in
                if pattern.contains("\\d+") {
                    return tripName.range(of: pattern, options: .regularExpression) != nil
                }
                return tripName.contains(pattern.lowercased())
            }
            return isExactMatch || isPatternMatch
        }.map(\.id)

        let orgIDsToDelete = organizations.filter { org in
            let orgName = org.name.lowercased()
            return testOrgPatterns.contains(where: { orgName.contains($0.lowercased()) }) && !org.isNone
        }.map(\.id)

        if !tripIDsToDelete.isEmpty {
            try Trip.where { $0.id.in(tripIDsToDelete) }.delete().execute(db)
        }
        if !orgIDsToDelete.isEmpty {
            try Organization.where { $0.id.in(orgIDsToDelete) }.delete().execute(db)
        }

        return (tripIDsToDelete.count, orgIDsToDelete.count)
    }
}

private func resetAllData(in database: DatabaseWriter) async throws -> (trips: Int, organizations: Int, addresses: Int) {
    try await database.write { db in
        let trips = try Trip.fetchAll(db)
        let organizations = try Organization.where { $0.name.neq("None") }.fetchAll(db)
        let addresses = try Address.fetchAll(db)

        let tripIDs = trips.map(\.id)
        let organizationIDs = organizations.map(\.id)
        let addressIDs = addresses.map(\.id)

        if !tripIDs.isEmpty {
            try Trip.where { $0.id.in(tripIDs) }.delete().execute(db)
        }
        if !organizationIDs.isEmpty {
            try Organization.where { $0.id.in(organizationIDs) }.delete().execute(db)
        }
        if !addressIDs.isEmpty {
            try Address.where { $0.id.in(addressIDs) }.delete().execute(db)
        }

        return (trips.count, organizations.count, addresses.count)
    }
}
