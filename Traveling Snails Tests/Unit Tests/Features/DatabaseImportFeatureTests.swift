import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("DatabaseImportFeature Tests")
@MainActor
struct DatabaseImportFeatureTests {
    @Test("progress update maps manager snapshot to state")
    func progressUpdateMapsState() async {
        let store = TestStore(initialState: DatabaseImportFeature.State()) {
            DatabaseImportFeature()
        } withDependencies: {
            $0.defaultDatabase = try! makeDatabaseImportTestDatabase()
        }

        let snapshot = DatabaseImportFeature.ProgressSnapshot(
            progress: 0.45,
            status: "Importing trips...",
            isImporting: true,
            importError: nil,
            importSuccess: false
        )

        await store.send(.progressUpdated(snapshot)) {
            $0.importProgress = 0.45
            $0.importStatus = "Importing trips..."
            $0.isImporting = true
            $0.importError = nil
            $0.importSuccess = false
        }
    }

    @Test("done tapped requests close")
    func doneTappedRequestsClose() async {
        let store = TestStore(initialState: DatabaseImportFeature.State()) {
            DatabaseImportFeature()
        } withDependencies: {
            $0.defaultDatabase = try! makeDatabaseImportTestDatabase()
        }

        await store.send(.doneTapped)
        await store.receive(.delegate(.closeRequested))
    }

    @Test("import finished stores result and notifies parent")
    func importFinishedStoresResultAndNotifiesParent() async {
        let store = TestStore(initialState: DatabaseImportFeature.State()) {
            DatabaseImportFeature()
        } withDependencies: {
            $0.defaultDatabase = try! makeDatabaseImportTestDatabase()
        }

        let result = DatabaseImportManager.ImportResult(
            tripsImported: 1,
            organizationsImported: 2,
            addressesImported: 3,
            attachmentsImported: 4,
            transportationImported: 5,
            lodgingImported: 6,
            activitiesImported: 7,
            organizationsMerged: 1,
            errors: []
        )

        await store.send(.importFinished(result)) {
            $0.importResult = result
            $0.isImporting = false
            $0.importSuccess = true
            $0.importStatus = "Import completed successfully!"
        }
        await store.receive(.delegate(.finished(result)))
    }

    @Test("start import streams progress and completion")
    func startImportStreamsProgressAndCompletion() async {
        let result = DatabaseImportManager.ImportResult(
            tripsImported: 1,
            organizationsImported: 0,
            addressesImported: 0,
            attachmentsImported: 0,
            transportationImported: 0,
            lodgingImported: 0,
            activitiesImported: 0,
            organizationsMerged: 0,
            errors: []
        )

        let store = TestStore(initialState: DatabaseImportFeature.State()) {
            DatabaseImportFeature()
        } withDependencies: {
            $0.defaultDatabase = try! makeDatabaseImportTestDatabase()
            $0.databaseImportClient.importDatabase = { _, _ in
                AsyncStream { continuation in
                    continuation.yield(
                        .progress(
                            DatabaseImportProgressSnapshot(
                                progress: 0.5,
                                status: "Importing...",
                                isImporting: true,
                                importError: nil,
                                importSuccess: false
                            )
                        )
                    )
                    continuation.yield(.finished(result))
                    continuation.finish()
                }
            }
        }

        await store.send(.startImport(URL(fileURLWithPath: "/tmp/mock.json"))) {
            $0.importProgress = 0
            $0.importStatus = "Preparing import..."
            $0.isImporting = true
            $0.importError = nil
            $0.importSuccess = false
            $0.importResult = nil
        }

        await store.receive(
            .progressUpdated(
                .init(
                    progress: 0.5,
                    status: "Importing...",
                    isImporting: true,
                    importError: nil,
                    importSuccess: false
                )
            )
        ) {
            $0.importProgress = 0.5
            $0.importStatus = "Importing..."
            $0.isImporting = true
            $0.importError = nil
            $0.importSuccess = false
        }

        await store.receive(.importFinished(result)) {
            $0.importResult = result
            $0.isImporting = false
            $0.importSuccess = true
        }
        await store.receive(.delegate(.finished(result)))
    }
}

private func makeDatabaseImportTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    let migrator = makeMigrator()
    try migrator.migrate(database)
    return database
}
