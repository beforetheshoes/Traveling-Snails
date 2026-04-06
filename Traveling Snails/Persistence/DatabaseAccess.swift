//
//  DatabaseAccess.swift
//  Traveling Snails
//

import SQLiteData
import os.lock

enum DatabaseAccess {
    @TaskLocal
    static var scopedDatabase: DatabaseWriter?
    private static let globalDatabaseState = OSAllocatedUnfairLock(initialState: Optional<DatabaseWriter>.none)

    static var database: DatabaseWriter? {
        get {
            if let scopedDatabase {
                return scopedDatabase
            }
            return globalDatabaseState.withLock { $0 }
        }
        set {
            globalDatabaseState.withLock { state in
                state = newValue
            }
        }
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
