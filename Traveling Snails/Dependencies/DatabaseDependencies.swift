//
//  DatabaseDependencies.swift
//  Traveling Snails
//

import Dependencies
import SQLiteData

extension DependencyValues {
    mutating func bootstrapDatabase(
        syncEngineDelegate: (any SyncEngineDelegate)? = nil
    ) throws {
        defaultDatabase = try appDatabase()
        defaultSyncEngine = try SyncEngine(
            for: defaultDatabase,
            tables: Address.self,
            Organization.self,
            Trip.self,
            Activity.self,
            Lodging.self,
            Transportation.self,
            EmbeddedFileAttachment.self,
            delegate: syncEngineDelegate
        )

    }
}
