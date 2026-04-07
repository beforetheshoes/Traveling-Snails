//
//  AppDatabase.swift
//  Traveling Snails
//

import Foundation
import SQLiteData

func appDatabase() throws -> DatabaseQueue {
    let fileManager = FileManager.default
    let baseURL = try fileManager.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    let directoryURL = baseURL.appendingPathComponent("TravelingSnails", isDirectory: true)

    if !fileManager.fileExists(atPath: directoryURL.path) {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    let databaseURL = directoryURL.appendingPathComponent("TravelingSnails.sqlite")
    let database = try DatabaseQueue(path: databaseURL.path)

    let migrator = makeMigrator()
    try migrator.migrate(database)

    try CollectionItemDeletionLogger.install(on: database)

    DatabaseAccess.database = database
    return database
}
