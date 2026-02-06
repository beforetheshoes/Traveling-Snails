//
//  SettingsFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State {
        var showingDataBrowser = false
        var showingExportView = false
        var showingImportPicker = false
        var showingFileAttachmentSettings = false
        var showingImportProgress = false
        var showingDatabaseCleanup = false

        var importManager = DatabaseImportManager()
        var importResult: DatabaseImportManager.ImportResult?
        var importError: String?
        var showingImportError = false

        var showingOrganizationCleanupAlert = false
        var organizationCleanupMessage = ""

        var allTripsLocked = false

        var appVersion: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }

        var buildNumber: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case onAppear
        case openDataBrowser
        case openExportView
        case openImportPicker
        case openFileAttachmentSettings
        case openDatabaseCleanup
        case lockAllProtectedTripsTapped
        case cleanupNoneOrganizationsTapped
        case organizationCleanupCompleted(String)
        case importPickerResult(Result<[URL], Error>)
        case importCompleted(DatabaseImportManager.ImportResult)
        case importFailed(String)
        case dismissImportError
        case dismissImportProgress
        case setAllTripsLocked(Bool)
        case binding(BindingAction<State>)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.authenticationClient) private var authenticationClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let locked = await authenticationClient.allTripsLocked()
                    await send(.setAllTripsLocked(locked))
                }
            case .openDataBrowser:
                state.showingDataBrowser = true
                return .none
            case .openExportView:
                state.showingExportView = true
                return .none
            case .openImportPicker:
                state.showingImportPicker = true
                return .none
            case .openFileAttachmentSettings:
                state.showingFileAttachmentSettings = true
                return .none
            case .openDatabaseCleanup:
                state.showingDatabaseCleanup = true
                return .none
            case .lockAllProtectedTripsTapped:
                return .run { send in
                    await authenticationClient.lockAllTrips()
                    let locked = await authenticationClient.allTripsLocked()
                    await send(.setAllTripsLocked(locked))
                }
            case .cleanupNoneOrganizationsTapped:
                return .run { send in
                    let message: String
                    do {
                        let noneOrganizations = try await database.read { db in
                            try Organization.where { $0.name.eq("None") }.fetchAll(db)
                        }
                        if noneOrganizations.isEmpty {
                            let noneOrg = Organization(name: "None")
                            try await database.write { db in
                                try Organization.insert { noneOrg }.execute(db)
                            }
                            message = "No duplicate organizations found"
                        } else if noneOrganizations.count == 1 {
                            message = "No duplicate organizations found"
                        } else {
                            let duplicateIDs = noneOrganizations.dropFirst().map(\.id)
                            let optionalIDs = duplicateIDs.map(Optional.some)
                            try await database.write { db in
                                if !duplicateIDs.isEmpty {
                                    try Transportation.where { $0.organizationID.in(optionalIDs) }.update {
                                        $0.organizationID = noneOrganizations[0].id
                                    }.execute(db)
                                    try Lodging.where { $0.organizationID.in(optionalIDs) }.update {
                                        $0.organizationID = noneOrganizations[0].id
                                    }.execute(db)
                                    try Activity.where { $0.organizationID.in(optionalIDs) }.update {
                                        $0.organizationID = noneOrganizations[0].id
                                    }.execute(db)
                                    try Organization.where { $0.id.in(duplicateIDs) }.delete().execute(db)
                                }
                            }
                            message = "Successfully removed \(noneOrganizations.count - 1) duplicate organization\(noneOrganizations.count - 1 == 1 ? "" : "s")"
                        }
                    } catch {
                        message = "No duplicate organizations found"
                    }

                    await send(.organizationCleanupCompleted(message))
                }
            case .importPickerResult(.success(let urls)):
                guard let url = urls.first else { return .none }
                state.showingImportProgress = true
                let importManager = state.importManager
                return .run { send in
                    let result = await importManager.importDatabase(from: url, into: database)
                    await send(.importCompleted(result))
                }
            case .importPickerResult(.failure(let error)):
                state.importError = error.localizedDescription
                state.showingImportError = true
                return .none
            case .importCompleted(let result):
                state.importResult = result
                state.showingImportProgress = false
                return .none
            case .importFailed(let message):
                state.importError = message
                state.showingImportError = true
                return .none
            case .dismissImportError:
                state.showingImportError = false
                state.importError = nil
                return .none
            case .dismissImportProgress:
                state.showingImportProgress = false
                return .none
            case .setAllTripsLocked(let locked):
                state.allTripsLocked = locked
                return .none
            case .organizationCleanupCompleted(let message):
                state.organizationCleanupMessage = message
                state.showingOrganizationCleanupAlert = true
                return .none
            case .binding:
                return .none
            }
        }
    }
}

enum SettingsTimeoutOption: TimeInterval, CaseIterable {
    case immediately = 0
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case oneHour = 3600
    case never = -1

    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .never: return "Never"
        }
    }

    static func from(_ timeInterval: TimeInterval) -> SettingsTimeoutOption {
        allCases.first { $0.rawValue == timeInterval } ?? .fifteenMinutes
    }
}
