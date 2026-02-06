//
//  DatabaseAccess.swift
//  Traveling Snails
//

import SQLiteData

enum DatabaseAccess {
    @TaskLocal
    static var scopedDatabase: DatabaseWriter?
    private static var globalDatabase: DatabaseWriter?

    static var database: DatabaseWriter? {
        get { scopedDatabase ?? globalDatabase }
        set { globalDatabase = newValue }
    }

    static func withDatabase<R>(
        _ database: DatabaseWriter,
        operation: () throws -> R
    ) rethrows -> R {
        try $scopedDatabase.withValue(database) {
            try operation()
        }
    }

    static func withDatabase<R>(
        _ database: DatabaseWriter,
        operation: () async throws -> R
    ) async rethrows -> R {
        try await $scopedDatabase.withValue(database) {
            try await operation()
        }
    }
}
