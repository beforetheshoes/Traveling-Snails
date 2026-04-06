//
//  SettingsFeature.swift
//  Traveling Snails
//

import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct SettingsFeature {
    enum ActiveSheet: String, Equatable, Identifiable {
        case dataBrowser
        case exportView
        case fileAttachmentSettings
        case databaseImportProgress
        case databaseCleanup

        var id: String { rawValue }
    }

    @ObservableState
    struct State {
        var activeSheet: ActiveSheet?
        var showingImportPicker = false

        var fileAttachmentSettings = FileAttachmentSettingsFeature.State()
        var databaseImport = DatabaseImportFeature.State()
        var databaseCleanup = DatabaseCleanupFeature.State()
        var dataBrowser = DataBrowserFeature.State()
        var databaseExport = DatabaseExportFeature.State()
        var syncDiagnostic = SyncDiagnosticFeature.State()
        var importResult: DatabaseImportManager.ImportResult?
        var importError: String?
        var showingImportError = false

        var showingOrganizationCleanupAlert = false
        var organizationCleanupMessage = ""

        var allTripsLocked = false
        var canUseBiometrics = false
        var isFaceID = false
        var colorSchemePreference: ColorSchemePreference = .system
        var biometricTimeoutMinutes: Int = 5

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
        case activeSheetChanged(ActiveSheet?)
        case openDataBrowser
        case openExportView
        case openImportPicker
        case openFileAttachmentSettings
        case openDatabaseCleanup
        case lockAllProtectedTripsTapped
        case cleanupNoneOrganizationsTapped
        case organizationCleanupCompleted(String)
        case importPickerResult(Result<[URL], Error>)
        case dismissImportError
        case setAllTripsLocked(Bool)
        case biometricAvailabilityLoaded(canUseBiometrics: Bool, isFaceID: Bool)
        case fileAttachmentSettings(FileAttachmentSettingsFeature.Action)
        case databaseImport(DatabaseImportFeature.Action)
        case databaseCleanup(DatabaseCleanupFeature.Action)
        case dataBrowser(DataBrowserFeature.Action)
        case databaseExport(DatabaseExportFeature.Action)
        case syncDiagnostic(SyncDiagnosticFeature.Action)
        case settingsLoaded(SettingsSnapshot)
        case colorSchemeChanged(ColorSchemePreference)
        case biometricTimeoutChanged(Int)
        case binding(BindingAction<State>)
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.authenticationClient) private var authenticationClient
    @Dependency(\.biometricAuthClient) private var biometricAuthClient
    @Dependency(\.settingsClient) private var settingsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.fileAttachmentSettings, action: \.fileAttachmentSettings) {
            FileAttachmentSettingsFeature()
        }
        Scope(state: \.databaseImport, action: \.databaseImport) {
            DatabaseImportFeature()
        }
        Scope(state: \.databaseCleanup, action: \.databaseCleanup) {
            DatabaseCleanupFeature()
        }
        Scope(state: \.dataBrowser, action: \.dataBrowser) {
            DataBrowserFeature()
        }
        Scope(state: \.databaseExport, action: \.databaseExport) {
            DatabaseExportFeature()
        }
        Scope(state: \.syncDiagnostic, action: \.syncDiagnostic) {
            SyncDiagnosticFeature()
        }
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let locked = await authenticationClient.allTripsLocked()
                    let canUseBiometrics = await biometricAuthClient.canUseBiometrics()
                    let biometricType = await biometricAuthClient.biometricType()
                    let settings = await settingsClient.load()
                    await send(.setAllTripsLocked(locked))
                    await send(
                        .biometricAvailabilityLoaded(
                            canUseBiometrics: canUseBiometrics,
                            isFaceID: biometricType == .faceID
                        )
                    )
                    await send(.settingsLoaded(settings))
                }
            case .settingsLoaded(let snapshot):
                state.colorSchemePreference = snapshot.colorSchemePreference
                state.biometricTimeoutMinutes = snapshot.biometricTimeoutMinutes
                return .none
            case .colorSchemeChanged(let preference):
                state.colorSchemePreference = preference
                return .run { _ in
                    await settingsClient.saveColorScheme(preference)
                }
            case .biometricTimeoutChanged(let minutes):
                state.biometricTimeoutMinutes = minutes
                return .run { _ in
                    await settingsClient.saveBiometricTimeout(minutes)
                }
            case .activeSheetChanged(let sheet):
                state.activeSheet = sheet
                return .none
            case .openDataBrowser:
                state.activeSheet = .dataBrowser
                return .none
            case .openExportView:
                state.activeSheet = .exportView
                return .none
            case .openImportPicker:
                state.showingImportPicker = true
                return .none
            case .openFileAttachmentSettings:
                state.activeSheet = .fileAttachmentSettings
                return .none
            case .openDatabaseCleanup:
                state.activeSheet = .databaseCleanup
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
                                        $0.organizationID = #bind(noneOrganizations[0].id)
                                    }.execute(db)
                                    try Lodging.where { $0.organizationID.in(optionalIDs) }.update {
                                        $0.organizationID = #bind(noneOrganizations[0].id)
                                    }.execute(db)
                                    try Activity.where { $0.organizationID.in(optionalIDs) }.update {
                                        $0.organizationID = #bind(noneOrganizations[0].id)
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
                state.activeSheet = .databaseImportProgress
                return .send(.databaseImport(.startImport(url)))
            case .importPickerResult(.failure(let error)):
                state.importError = error.localizedDescription
                state.showingImportError = true
                return .none
            case .dismissImportError:
                state.showingImportError = false
                state.importError = nil
                return .none
            case .setAllTripsLocked(let locked):
                state.allTripsLocked = locked
                return .none
            case .biometricAvailabilityLoaded(let canUseBiometrics, let isFaceID):
                state.canUseBiometrics = canUseBiometrics
                state.isFaceID = isFaceID
                return .none
            case .organizationCleanupCompleted(let message):
                state.organizationCleanupMessage = message
                state.showingOrganizationCleanupAlert = true
                return .none
            case .databaseImport(.delegate(.finished(let result))):
                state.importResult = result
                return .none
            case .databaseImport(.delegate(.closeRequested)):
                if state.activeSheet == .databaseImportProgress {
                    state.activeSheet = nil
                }
                return .none
            case .databaseCleanup:
                return .none
            case .dataBrowser:
                return .none
            case .databaseExport:
                return .none
            case .fileAttachmentSettings:
                return .none
            case .syncDiagnostic:
                return .none
            case .databaseImport:
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
