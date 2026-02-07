import Dependencies
import Foundation
import SQLiteData

struct DatabaseImportProgressSnapshot: Sendable, Equatable {
    var progress: Double
    var status: String
    var isImporting: Bool
    var importError: String?
    var importSuccess: Bool
}

enum DatabaseImportEvent: Sendable, Equatable {
    case progress(DatabaseImportProgressSnapshot)
    case finished(DatabaseImportManager.ImportResult)
}

struct DatabaseImportClient: Sendable {
    var importDatabase: @Sendable (URL, DatabaseWriter) -> AsyncStream<DatabaseImportEvent>
}

extension DatabaseImportClient: DependencyKey {
    static let liveValue = Self(
        importDatabase: { url, database in
            AsyncStream { continuation in
                let workTask = Task {
                    let manager = await MainActor.run { DatabaseImportManager() }

                    let pollTask = Task {
                        while !Task.isCancelled {
                            let snapshot = await MainActor.run {
                                DatabaseImportProgressSnapshot(
                                    progress: manager.importProgress,
                                    status: manager.importStatus,
                                    isImporting: manager.isImporting,
                                    importError: manager.importError,
                                    importSuccess: manager.importSuccess
                                )
                            }
                            continuation.yield(.progress(snapshot))

                            do {
                                try await Task.sleep(for: .milliseconds(150))
                            } catch {
                                break
                            }
                        }
                    }

                    let result = await manager.importDatabase(from: url, into: database)
                    let finalSnapshot = await MainActor.run {
                        DatabaseImportProgressSnapshot(
                            progress: manager.importProgress,
                            status: manager.importStatus,
                            isImporting: manager.isImporting,
                            importError: manager.importError,
                            importSuccess: manager.importSuccess
                        )
                    }
                    continuation.yield(.progress(finalSnapshot))
                    continuation.yield(.finished(result))
                    pollTask.cancel()
                    continuation.finish()
                }

                continuation.onTermination = { _ in
                    workTask.cancel()
                }
            }
        }
    )

    static let testValue = Self(
        importDatabase: { _, _ in
            let result = DatabaseImportManager.ImportResult(
                tripsImported: 0,
                organizationsImported: 0,
                addressesImported: 0,
                attachmentsImported: 0,
                transportationImported: 0,
                lodgingImported: 0,
                activitiesImported: 0,
                organizationsMerged: 0,
                errors: []
            )

            return AsyncStream { continuation in
                continuation.yield(
                    .progress(
                        DatabaseImportProgressSnapshot(
                            progress: 1,
                            status: "Import completed successfully!",
                            isImporting: false,
                            importError: nil,
                            importSuccess: true
                        )
                    )
                )
                continuation.yield(.finished(result))
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var databaseImportClient: DatabaseImportClient {
        get { self[DatabaseImportClient.self] }
        set { self[DatabaseImportClient.self] = newValue }
    }
}
