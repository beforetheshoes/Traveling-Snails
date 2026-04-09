//
//  CollectionSharingTests.swift
//  Traveling Snails Tests
//

import CloudKit
import ComposableArchitecture
import Foundation
import SQLiteData
import Testing
@testable import Traveling_Snails

@Suite("Collection Sharing Tests", .serialized)
@MainActor
struct CollectionSharingTests {

    // MARK: - CollectionRow Model

    @Test("CollectionRow isShared returns false when share is nil", .tags(.unit, .fast, .sharing))
    func collectionRowNotShared() {
        let row = CollectionRow(
            collection: Collection(name: "Books", type: .book),
            share: nil
        )
        #expect(row.isShared == false)
        #expect(row.shareMessage == nil)
        #expect(row.canWrite == true)
    }

    @Test("CollectionRow id matches collection id", .tags(.unit, .fast, .sharing))
    func collectionRowId() {
        let collection = Collection(name: "Movies", type: .movie)
        let row = CollectionRow(collection: collection, share: nil)
        #expect(row.id == collection.id)
    }

    // MARK: - Database: Collection CRUD

    @Test("Collection can be created and read back", .tags(.unit, .fast, .sharing))
    func collectionCRUD() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        let collection = Collection(name: "My Books", type: .book)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }

        let fetched = try await db.read { db in
            try Collection.fetchAll(db)
        }
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "My Books")
        #expect(fetched.first?.type == .book)
    }

    @Test("Collection can be deleted", .tags(.unit, .fast, .sharing))
    func collectionDelete() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        let collection = Collection(name: "To Delete", type: .movie)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }
        try await db.write { db in
            try Collection.find(collection.id).delete().execute(db)
        }

        let remaining = try await db.read { db in
            try Collection.fetchAll(db)
        }
        #expect(remaining.isEmpty)
    }

    // MARK: - CollectionDetailFeature sharing actions

    @Test("Share tapped sets isPreparingShare", .tags(.unit, .fast, .sharing))
    func shareTappedSetsPreparingState() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        let collection = Collection(name: "Shared List", type: .restaurant)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }

        let store = TestStore(
            initialState: CollectionDetailFeature.State(collection: collection)
        ) {
            CollectionDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = db
        }
        store.exhaustivity = .off

        await store.send(.shareTapped) {
            $0.isPreparingShare = true
            $0.shareError = nil
        }
    }

    @Test("Share failed clears preparing state and sets error", .tags(.unit, .fast, .sharing))
    func shareFailedSetsError() async throws {
        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: Collection(name: "Test", type: .book)
            )
        ) {
            CollectionDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.shareFailed("Network error")) {
            $0.isPreparingShare = false
            $0.shareError = "Network error"
        }
    }

    @Test("Share dismissed clears share state and reloads status", .tags(.unit, .fast, .sharing))
    func shareDismissedClearsState() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        let collection = Collection(name: "Test", type: .book)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }

        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: collection
            )
        ) {
            CollectionDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = db
        }
        store.exhaustivity = .off

        await store.send(.shareDismissed) {
            $0.sharedRecord = nil
            $0.shareError = nil
        }
    }

    // MARK: - Share status loading

    @Test("Share status loaded updates state", .tags(.unit, .fast, .sharing))
    func shareStatusLoaded() async throws {
        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: Collection(name: "Test", type: .book)
            )
        ) {
            CollectionDetailFeature()
        }
        store.exhaustivity = .off

        let participants = [
            ShareParticipant(
                id: "owner-123",
                displayName: "Ryan",
                role: .owner,
                permission: .readWrite,
                acceptanceStatus: .accepted
            ),
            ShareParticipant(
                id: "member-456",
                displayName: "Heather",
                role: .privateUser,
                permission: .readWrite,
                acceptanceStatus: .accepted
            ),
        ]

        await store.send(.shareStatusLoaded(isShared: true, canWrite: true, isOwner: true, participants: participants)) {
            $0.isLoadingParticipants = false
            $0.isShared = true
            $0.canWrite = true
            $0.isOwner = true
            $0.participants = participants
        }
    }

    @Test("Share status loaded with read-only sets canWrite false", .tags(.unit, .fast, .sharing))
    func shareStatusReadOnly() async throws {
        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: Collection(name: "Test", type: .book)
            )
        ) {
            CollectionDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.shareStatusLoaded(isShared: true, canWrite: false, isOwner: false, participants: [])) {
            $0.isLoadingParticipants = false
            $0.isShared = true
            $0.canWrite = false
            $0.isOwner = false
        }
    }

    @Test("Manage share tapped as non-owner shows participants", .tags(.unit, .fast, .sharing))
    func manageShareNonOwner() async throws {
        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: Collection(name: "Test", type: .movie),
                isShared: true,
                isOwner: false
            )
        ) {
            CollectionDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.manageShareTapped) {
            $0.showingParticipants = true
        }
    }

    @Test("Manage share tapped as owner sets preparing state", .tags(.unit, .fast, .sharing))
    func manageShareOwner() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        let collection = Collection(name: "Test", type: .movie)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }

        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: collection,
                isShared: true,
                isOwner: true
            )
        ) {
            CollectionDetailFeature()
        } withDependencies: {
            $0.defaultDatabase = db
        }
        store.exhaustivity = .off

        await store.send(.manageShareTapped) {
            $0.isPreparingShare = true
        }
    }

    @Test("Toggle participant sheet toggles state", .tags(.unit, .fast, .sharing))
    func toggleParticipantSheet() async throws {
        let store = TestStore(
            initialState: CollectionDetailFeature.State(
                collection: Collection(name: "Test", type: .book)
            )
        ) {
            CollectionDetailFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleParticipantSheet) {
            $0.showingParticipants = true
        }

        await store.send(.toggleParticipantSheet) {
            $0.showingParticipants = false
        }
    }

    // MARK: - ShareParticipant model

    @Test("ShareParticipant owner is identified correctly", .tags(.unit, .fast, .sharing))
    func shareParticipantOwner() {
        let owner = ShareParticipant(
            id: "owner-1",
            displayName: "Ryan Smith",
            role: .owner,
            permission: .readWrite,
            acceptanceStatus: .accepted
        )
        #expect(owner.isOwner == true)
        #expect(owner.isPending == false)
        #expect(owner.isReadOnly == false)
        #expect(owner.roleLabel == "Owner")
        #expect(owner.permissionLabel == "Can Edit")
        #expect(owner.initials == "RS")
    }

    @Test("ShareParticipant pending read-only member", .tags(.unit, .fast, .sharing))
    func shareParticipantPendingReadOnly() {
        let member = ShareParticipant(
            id: "member-1",
            displayName: "Heather",
            role: .privateUser,
            permission: .readOnly,
            acceptanceStatus: .pending
        )
        #expect(member.isOwner == false)
        #expect(member.isPending == true)
        #expect(member.isReadOnly == true)
        #expect(member.roleLabel == "Member")
        #expect(member.permissionLabel == "View Only")
        #expect(member.initials == "HE")
    }

    // MARK: - Item Attribution

    @Test("Attribution migration adds columns", .tags(.unit, .fast, .sharing))
    func attributionMigration() async throws {
        let db = try DatabaseQueue(path: ":memory:")
        try makeMigrator().migrate(db)

        // Items should be creatable with attribution fields
        let collection = Collection(name: "Test", type: .book)
        try await db.write { db in
            try Collection.upsert { collection }.execute(db)
        }

        let book = BookItem(
            collectionID: collection.id,
            title: "Test Book",
            addedByUserRecordName: "user-123",
            lastEditedByUserRecordName: "user-456"
        )
        try await db.write { db in
            try BookItem.upsert { book }.execute(db)
        }

        let fetched = try await db.read { db in
            try BookItem.fetchAll(db)
        }
        #expect(fetched.first?.addedByUserRecordName == "user-123")
        #expect(fetched.first?.lastEditedByUserRecordName == "user-456")
    }

    @Test("Attribution defaults to empty string", .tags(.unit, .fast, .sharing))
    func attributionDefaults() {
        let item = RestaurantItem(collectionID: UUID(), title: "Test")
        #expect(item.addedByUserRecordName == "")
        #expect(item.lastEditedByUserRecordName == "")
    }

    @Test("CollectionItemProtocol exposes attribution", .tags(.unit, .fast, .sharing))
    func protocolAttribution() {
        let item: any CollectionItemProtocol = BookItem(
            collectionID: UUID(),
            title: "Book",
            addedByUserRecordName: "user-abc"
        )
        #expect(item.addedByUserRecordName == "user-abc")
        #expect(item.lastEditedByUserRecordName == "")
    }

    @Test("UserIdentityClient test value returns deterministic name", .tags(.unit, .fast, .sharing))
    func userIdentityTestValue() async throws {
        let client = UserIdentityClient.testValue
        let name = try await client.currentUserRecordName()
        #expect(name == "test-user-record-name")

        let displayName = await client.displayName("any-record-name")
        #expect(displayName == "Test User")
    }
}
