//
//  SyncEventLogger.swift
//  Traveling Snails
//
//  Persistent sync event log that works in all builds (not just DEBUG).
//  Captures sync lifecycle events, errors, and item count changes to
//  diagnose issues like items disappearing during CloudKit sync.

import Foundation
import GRDB
import SQLiteData

struct SyncEventEntry: Equatable, Identifiable, Sendable {
    let id: Int
    let timestamp: String
    let eventType: String
    let recordType: String
    let recordID: String
    let errorCode: String
    let details: String
}

enum SyncEventLogger {
    static func install(on database: DatabaseWriter) throws {
        try database.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS "_syncEventLog" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "timestamp" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime')),
                  "eventType" TEXT NOT NULL,
                  "recordType" TEXT NOT NULL DEFAULT '',
                  "recordID" TEXT NOT NULL DEFAULT '',
                  "errorCode" TEXT NOT NULL DEFAULT '',
                  "details" TEXT NOT NULL DEFAULT ''
                )
                """)
        }
        Logger.shared.info("SyncEventLogger installed", category: .database)
    }

    static func log(
        on database: DatabaseWriter,
        type eventType: String,
        recordType: String = "",
        recordID: String = "",
        errorCode: String = "",
        details: String = ""
    ) {
        do {
            try database.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO "_syncEventLog" ("eventType", "recordType", "recordID", "errorCode", "details")
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [eventType, recordType, recordID, errorCode, details]
                )
            }
        } catch {
            Logger.shared.error("SyncEventLogger.log failed: \(error.localizedDescription)", category: .sync)
        }
    }

    static func recentEvents(from database: DatabaseReader, limit: Int = 50) throws -> [SyncEventEntry] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT "id", "timestamp", "eventType", "recordType", "recordID", "errorCode", "details"
                FROM "_syncEventLog"
                ORDER BY "id" DESC
                LIMIT ?
                """, arguments: [limit])
            return rows.map { row in
                SyncEventEntry(
                    id: row["id"],
                    timestamp: row["timestamp"],
                    eventType: row["eventType"],
                    recordType: row["recordType"],
                    recordID: row["recordID"],
                    errorCode: row["errorCode"],
                    details: row["details"]
                )
            }
        }
    }

    static func purge(from database: DatabaseWriter, olderThanDays days: Int = 7) throws {
        try database.write { db in
            try db.execute(sql: """
                DELETE FROM "_syncEventLog"
                WHERE "timestamp" < strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime', '-\(days) days')
                """)
        }
    }

    static func clear(on database: DatabaseWriter) throws {
        try database.write { db in
            try db.execute(sql: """
                DELETE FROM "_syncEventLog"
                """)
        }
    }
}
