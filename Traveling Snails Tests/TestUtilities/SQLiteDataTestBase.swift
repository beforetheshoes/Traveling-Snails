//
//  SQLiteDataTestBase.swift
//  Traveling Snails Tests
//

import Dependencies
import SQLiteData
import Testing
@testable import Traveling_Snails

@MainActor
final class SQLiteDataTestBase {
    let database: DatabaseQueue

    init() {
        do {
            database = try DatabaseQueue()
            var migrator = makeMigrator()
            try migrator.migrate(database)

            DatabaseAccess.database = database
            let db = database
            do {
                try prepareDependencies {
                    $0.defaultDatabase = db
                    $0.defaultSyncEngine = try SyncEngine(
                        for: db,
                        tables: Address.self,
                        Organization.self,
                        Trip.self,
                        Activity.self,
                        Lodging.self,
                        Transportation.self,
                        EmbeddedFileAttachment.self
                    )
                }
            } catch {
                print("SQLiteDataTestBase: prepareDependencies failed: \(error)")
            }
        } catch {
            fatalError("Failed to create test database: \(error)")
        }
    }

    func clearDatabase() throws {
        try database.write { db in
            try EmbeddedFileAttachment.delete().execute(db)
            try Activity.delete().execute(db)
            try Lodging.delete().execute(db)
            try Transportation.delete().execute(db)
            try Trip.delete().execute(db)
            try Organization.delete().execute(db)
            try Address.delete().execute(db)
        }
    }

    func verifyDatabaseEmpty() throws {
        let trips = try database.read { db in
            try Trip.fetchAll(db)
        }
        let lodgings = try database.read { db in
            try Lodging.fetchAll(db)
        }
        let transportation = try database.read { db in
            try Transportation.fetchAll(db)
        }
        let activities = try database.read { db in
            try Activity.fetchAll(db)
        }

        #expect(trips.isEmpty, "Trips should be empty at test start")
        #expect(lodgings.isEmpty, "Lodgings should be empty at test start")
        #expect(transportation.isEmpty, "Transportation should be empty at test start")
        #expect(activities.isEmpty, "Activities should be empty at test start")
    }
}

typealias SwiftDataTestBase = SQLiteDataTestBase
