import Clocks
import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("EmbeddedFileAttachmentListFeature Tests")
@MainActor
struct EmbeddedFileAttachmentListFeatureTests {
    @Test("remove attachment deletes from database")
    func removeAttachmentDeletesFromDatabase() async throws {
        let database = try makeAttachmentListTestDatabase()
        let attachment = EmbeddedFileAttachment(fileName: "delete-me.pdf", fileData: Data("abc".utf8))

        try await database.write { db in
            try EmbeddedFileAttachment.insert { attachment }.execute(db)
        }

        let store = TestStore(initialState: EmbeddedFileAttachmentListFeature.State()) {
            EmbeddedFileAttachmentListFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.removeAttachmentTapped(attachment)) {
            $0.isProcessing = true
        }
        await store.receive(.removeAttachmentSucceeded) {
            $0.isProcessing = false
        }

        let count = try await database.read { db in
            try EmbeddedFileAttachment.fetchCount(db)
        }
        #expect(count == 0)
    }

    @Test("show error auto clears with clock")
    func showErrorAutoClears() async {
        let clock = TestClock()
        let store = TestStore(initialState: EmbeddedFileAttachmentListFeature.State()) {
            EmbeddedFileAttachmentListFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.showError("boom")) {
            $0.errorMessage = "boom"
        }

        await clock.advance(by: .seconds(5))
        await store.receive(.clearError) {
            $0.errorMessage = nil
        }
    }
}

private func makeAttachmentListTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
