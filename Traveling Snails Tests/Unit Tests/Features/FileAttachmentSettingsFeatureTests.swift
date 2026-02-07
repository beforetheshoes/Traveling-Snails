import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
import Clocks

@testable import Traveling_Snails

@Suite("FileAttachmentSettingsFeature Tests")
@MainActor
struct FileAttachmentSettingsFeatureTests {
    @Test("scan finds orphaned attachments")
    func scanFindsOrphanedAttachments() async throws {
        let database = try makeFileAttachmentSettingsTestDatabase()
        let clock = TestClock()
        let orphaned = EmbeddedFileAttachment(
            fileName: "orphaned",
            originalFileName: "orphaned.png",
            fileSize: 100,
            mimeType: "image/png",
            fileExtension: "png"
        )
        let linked = EmbeddedFileAttachment(
            fileName: "linked",
            originalFileName: "linked.pdf",
            fileSize: 200,
            mimeType: "application/pdf",
            fileExtension: "pdf",
            activityID: UUID()
        )

        let store = TestStore(initialState: FileAttachmentSettingsFeature.State()) {
            FileAttachmentSettingsFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.continuousClock = clock
        }

        await store.send(.findOrphanedTapped([orphaned, linked])) {
            $0.isScanning = true
        }
        await clock.advance(by: .seconds(1))

        await store.receive(.scanCompleted([orphaned.id])) {
            $0.isScanning = false
            $0.orphanedAttachmentIDs = [orphaned.id]
            $0.alertTitle = "Success"
            $0.alertMessage = "Scan complete. Found 1 orphaned file."
            $0.showingAlert = true
        }
    }

    @Test("cleanup orphaned confirmed deletes rows")
    func cleanupOrphanedDeletesRows() async throws {
        let database = try makeFileAttachmentSettingsTestDatabase()
        let clock = TestClock()
        let trip = Trip(name: "Linked Trip")
        let org = Organization(name: "Linked Org")
        let activity = Activity(
            name: "Linked Activity",
            start: Date(),
            end: Date(),
            trip: trip,
            organization: org
        )
        let orphaned = EmbeddedFileAttachment(
            fileName: "orphaned",
            originalFileName: "orphaned.png",
            fileSize: 100,
            mimeType: "image/png",
            fileExtension: "png"
        )
        let linked = EmbeddedFileAttachment(
            fileName: "linked",
            originalFileName: "linked.pdf",
            fileSize: 200,
            mimeType: "application/pdf",
            fileExtension: "pdf",
            activityID: activity.id
        )

        try await database.write { db in
            try Trip.upsert { trip }.execute(db)
            try Organization.upsert { org }.execute(db)
            try Activity.upsert { activity }.execute(db)
            try EmbeddedFileAttachment.upsert { orphaned }.execute(db)
            try EmbeddedFileAttachment.upsert { linked }.execute(db)
        }

        let store = TestStore(
            initialState: FileAttachmentSettingsFeature.State(orphanedAttachmentIDs: [orphaned.id])
        ) {
            FileAttachmentSettingsFeature()
        } withDependencies: {
            $0.defaultDatabase = database
            $0.continuousClock = clock
        }

        await store.send(.cleanupOrphanedConfirmed) {
            $0.showingCleanupConfirmation = false
            $0.isCleaning = true
        }
        await clock.advance(by: .seconds(1))
        await store.receive(.cleanupCompleted(1)) {
            $0.isCleaning = false
            $0.orphanedAttachmentIDs = []
            $0.alertTitle = "Success"
            $0.alertMessage = "Successfully cleaned up 1 orphaned file."
            $0.showingAlert = true
        }

        let remaining = try await database.read { db in
            try EmbeddedFileAttachment.fetchAll(db)
        }
        #expect(remaining.count == 1)
        #expect(remaining[0].id == linked.id)
    }
}

private func makeFileAttachmentSettingsTestDatabase() throws -> DatabaseQueue {
    let database = try DatabaseQueue(path: ":memory:")
    var migrator = makeMigrator()
    try migrator.migrate(database)
    DatabaseAccess.database = database
    return database
}
