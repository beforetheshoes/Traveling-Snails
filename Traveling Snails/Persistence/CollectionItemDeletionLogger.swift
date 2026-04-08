//
//  CollectionItemDeletionLogger.swift
//  Traveling Snails
//
//  Diagnostic tool: logs all deletions from collection item tables.
//  Helps identify if the SyncEngine or other code is unexpectedly removing records.

import Foundation
import GRDB
import SQLiteData

struct DeletionLogEntry: Equatable, Identifiable, Sendable {
    let id: Int
    let tableName: String
    let recordID: String
    let recordTitle: String
    let collectionID: String
    let timestamp: String
}

enum CollectionItemDeletionLogger {
    private static let monitoredTables = [
        "bookItems",
        "movieItems",
        "tVShowItems",
        "restaurantItems",
        "collections",
    ]

    static func install(on database: DatabaseWriter) throws {
        try database.write { db in
            // Drop and recreate the log table to pick up schema changes
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS "_collectionDeletionLog" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "tableName" TEXT NOT NULL,
                  "recordID" TEXT NOT NULL,
                  "recordTitle" TEXT NOT NULL DEFAULT '',
                  "collectionID" TEXT NOT NULL DEFAULT '',
                  "timestamp" TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%f', 'now', 'localtime'))
                )
                """)

            // Add collectionID column if missing (existing installs)
            let columns = try Row.fetchAll(db, sql: "PRAGMA table_info(\"_collectionDeletionLog\")")
            let columnNames = Set(columns.map { $0["name"] as String })
            if !columnNames.contains("collectionID") {
                try db.execute(sql: """
                    ALTER TABLE "_collectionDeletionLog"
                    ADD COLUMN "collectionID" TEXT NOT NULL DEFAULT ''
                    """)
            }

            // Upgrade timestamp precision if needed (old installs used datetime() which is second-level)
            // New installs already use strftime with milliseconds via the CREATE TABLE above.

            for table in monitoredTables {
                let triggerName = "_log_\(table)_delete"

                let titleExpr: String
                let collectionIDExpr: String

                switch table {
                case "collections":
                    titleExpr = "OLD.\"name\""
                    collectionIDExpr = "OLD.\"id\""
                case "bookItems", "movieItems", "tVShowItems", "restaurantItems":
                    titleExpr = "OLD.\"title\""
                    collectionIDExpr = "OLD.\"collectionID\""
                default:
                    titleExpr = "''"
                    collectionIDExpr = "''"
                }

                // Drop and recreate to pick up schema changes
                try db.execute(sql: "DROP TRIGGER IF EXISTS \"\(triggerName)\"")

                try db.execute(sql: """
                    CREATE TRIGGER "\(triggerName)"
                    AFTER DELETE ON "\(table)"
                    FOR EACH ROW
                    BEGIN
                      INSERT INTO "_collectionDeletionLog" ("tableName", "recordID", "recordTitle", "collectionID")
                      VALUES ('\(table)', OLD."id", \(titleExpr), \(collectionIDExpr));
                    END
                    """)
            }
        }

        Logger.shared.info("CollectionItemDeletionLogger installed for \(monitoredTables.count) tables", category: .database)
    }

    static func recentDeletions(from database: DatabaseReader, limit: Int = 50) throws -> [DeletionLogEntry] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT "id", "tableName", "recordID", "recordTitle",
                       COALESCE("collectionID", '') as "collectionID", "timestamp"
                FROM "_collectionDeletionLog"
                ORDER BY "id" DESC
                LIMIT ?
                """, arguments: [limit])
            return rows.map { row in
                DeletionLogEntry(
                    id: row["id"],
                    tableName: row["tableName"],
                    recordID: row["recordID"],
                    recordTitle: row["recordTitle"],
                    collectionID: row["collectionID"],
                    timestamp: row["timestamp"]
                )
            }
        }
    }

    static func clear(on database: DatabaseWriter) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM \"_collectionDeletionLog\"")
        }
    }

    static func logRecentDeletions(from database: DatabaseReader) {
        do {
            try database.read { db in
                let count = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM "_collectionDeletionLog"
                    """) ?? 0
                if count > 0 {
                    Logger.shared.warning(
                        "Collection item deletion log has \(count) entries. Query _collectionDeletionLog for details.",
                        category: .database
                    )
                }
            }
        } catch {
            Logger.shared.error("Failed to read deletion log: \(error.localizedDescription)", category: .database)
        }
    }
}
