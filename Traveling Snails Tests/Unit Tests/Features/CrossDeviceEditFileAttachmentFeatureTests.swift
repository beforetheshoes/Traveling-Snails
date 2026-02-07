import ComposableArchitecture
import Foundation
import SQLiteData
import Testing

@testable import Traveling_Snails

@Suite("CrossDeviceEditFileAttachmentFeature Tests")
@MainActor
struct CrossDeviceEditFileAttachmentFeatureTests {
    @Test("save updates attachment description")
    func saveUpdatesDescription() async throws {
        let database = try makeAttachmentTestDatabase()
        let attachment = EmbeddedFileAttachment(
            fileName: "test.pdf",
            fileDescription: "before",
            fileData: Data("abc".utf8)
        )

        try await database.write { db in
            try EmbeddedFileAttachment.insert { attachment }.execute(db)
        }

        let store = TestStore(
            initialState: CrossDeviceEditFileAttachmentFeature.State(attachment: attachment)
        ) {
            CrossDeviceEditFileAttachmentFeature()
        } withDependencies: {
            $0.defaultDatabase = database
        }

        await store.send(.binding(.set(\.editedDescription, "after"))) {
            $0.editedDescription = "after"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.shouldDismiss = true
        }

        let saved = try await database.read { db in
            try EmbeddedFileAttachment.find(attachment.id).fetchOne(db)
        }
        #expect(saved?.fileDescription == "after")
    }
}

private func makeAttachmentTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
