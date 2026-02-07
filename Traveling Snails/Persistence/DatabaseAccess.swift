//
//  DatabaseAccess.swift
//  Traveling Snails
//

import SQLiteData

enum DatabaseAccess {
    @TaskLocal
    static var scopedDatabase: DatabaseWriter?
    nonisolated(unsafe) private static var globalDatabase: DatabaseWriter?

    static var database: DatabaseWriter? {
        get { scopedDatabase ?? globalDatabase }
        set { globalDatabase = newValue }
    }

    @MainActor
    static func withDatabase<R>(
        _ database: DatabaseWriter,
        operation: @MainActor () throws -> R
    ) rethrows -> R {
        try $scopedDatabase.withValue(database) {
            try operation()
        }
    }

    @MainActor
    static func withDatabase<R>(
        _ database: DatabaseWriter,
        operation: @MainActor () async throws -> R
    ) async rethrows -> R {
        try await $scopedDatabase.withValue(database) {
            try await operation()
        }
    }
}
