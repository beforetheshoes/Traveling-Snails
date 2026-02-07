import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct DebugDataFeature {
    @ObservableState
    struct State: Equatable {
        var operationStatus = ""
    }

    enum Action: Equatable {
        case createTestDataTapped
        case ensureNoneOrganizationTapped
        case operationCompleted(String)
    }

    @Dependency(\.defaultDatabase) private var database

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .createTestDataTapped:
                return .run { send in
                    do {
                        try await database.write { db in
                            let trip = Trip(name: "Debug Test Trip")
                            let noneOrg: Organization
                            if let existing = try Organization.where({ $0.name.eq("None") }).fetchOne(db) {
                                noneOrg = existing
                            } else {
                                let inserted = Organization(name: "None")
                                try Organization.insert { inserted }.execute(db)
                                noneOrg = inserted
                            }

                            let activity = Activity(
                                name: "Debug Test Activity",
                                start: Date(),
                                end: Date(),
                                trip: trip,
                                organization: noneOrg
                            )

                            try Trip.upsert { trip }.execute(db)
                            try Activity.upsert { activity }.execute(db)
                        }
                        await send(.operationCompleted("Created test data"))
                    } catch {
                        Logger.shared.error("Error creating test data: \(error.localizedDescription)", category: .debug)
                        await send(.operationCompleted("Failed to create test data"))
                    }
                }

            case .ensureNoneOrganizationTapped:
                return .run { send in
                    do {
                        try await database.write { db in
                            let existing = try Organization.where({ $0.name.eq("None") }).fetchOne(db)
                            if existing == nil {
                                let noneOrg = Organization(name: "None")
                                try Organization.insert { noneOrg }.execute(db)
                            }
                        }
                        await send(.operationCompleted("Ensured None organization exists"))
                    } catch {
                        Logger.shared.error("Error ensuring None organization: \(error.localizedDescription)", category: .database)
                        await send(.operationCompleted("Failed to ensure None organization"))
                    }
                }

            case .operationCompleted(let message):
                state.operationStatus = message
                return .none
            }
        }
    }
}
