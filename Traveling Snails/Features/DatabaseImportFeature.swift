import ComposableArchitecture
import Foundation
import SQLiteData

@Reducer
struct DatabaseImportFeature {
    struct ProgressSnapshot: Sendable, Equatable {
        var progress: Double
        var status: String
        var isImporting: Bool
        var importError: String?
        var importSuccess: Bool
    }

    @ObservableState
    struct State: Equatable {
        var importProgress: Double = 0
        var importStatus = ""
        var isImporting = false
        var importError: String?
        var importSuccess = false
        var importResult: DatabaseImportManager.ImportResult?

        static func == (lhs: State, rhs: State) -> Bool {
            lhs.importProgress == rhs.importProgress &&
            lhs.importStatus == rhs.importStatus &&
            lhs.isImporting == rhs.isImporting &&
            lhs.importError == rhs.importError &&
            lhs.importSuccess == rhs.importSuccess &&
            lhs.importResult == rhs.importResult
        }
    }

    enum Action: Equatable {
        case startImport(URL)
        case progressUpdated(ProgressSnapshot)
        case importFinished(DatabaseImportManager.ImportResult)
        case doneTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case finished(DatabaseImportManager.ImportResult)
        case closeRequested
    }

    private enum CancelID {
        case importWork
    }

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.databaseImportClient) private var databaseImportClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startImport(let url):
                state.importProgress = 0
                state.importStatus = "Preparing import..."
                state.isImporting = true
                state.importError = nil
                state.importSuccess = false
                state.importResult = nil

                return .run { [databaseImportClient, database] send in
                    let stream = databaseImportClient.importDatabase(url, database)
                    for await event in stream {
                        switch event {
                        case .progress(let snapshot):
                            await send(
                                .progressUpdated(
                                    ProgressSnapshot(
                                        progress: snapshot.progress,
                                        status: snapshot.status,
                                        isImporting: snapshot.isImporting,
                                        importError: snapshot.importError,
                                        importSuccess: snapshot.importSuccess
                                    )
                                )
                            )
                        case .finished(let result):
                            await send(.importFinished(result))
                        }
                    }
                }
                .cancellable(id: CancelID.importWork, cancelInFlight: true)

            case .progressUpdated(let snapshot):
                state.importProgress = snapshot.progress
                state.importStatus = snapshot.status
                state.isImporting = snapshot.isImporting
                state.importError = snapshot.importError
                state.importSuccess = snapshot.importSuccess
                return .none

            case .importFinished(let result):
                state.importResult = result
                state.isImporting = false
                state.importSuccess = state.importError == nil && result.errors.isEmpty
                if !result.errors.isEmpty && state.importError == nil {
                    state.importError = result.errors[0]
                }
                if state.importStatus.isEmpty {
                    state.importStatus = state.importError == nil ? "Import completed successfully!" : "Import finished with errors."
                }
                return .send(.delegate(.finished(result)))

            case .doneTapped:
                return .send(.delegate(.closeRequested))

            case .delegate:
                return .none
            }
        }
    }
}
