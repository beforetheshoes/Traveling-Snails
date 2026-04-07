//
//  CollectionItemDeletionLogger.swift
//  Traveling Snails
//
//  Diagnostic tool: logs all deletions from collection item tables.
//  Helps identify if the SyncEngine or other code is unexpectedly removing records.

import Foundation
import SQLiteData

enum CollectionItemDeletionLogger {
    /// Tables to monitor for unexpected deletions.
    private static let monitoredTables = [
        "bookItems",
        "movieItems",
        "tVShowItems",
        "restaurantItems",
        "collections",
    ]

    /// Creates the `_collectionDeletionLog` table and installs AFTER DELETE triggers
    /// on each monitored table. Call once after database migration.
    static func install(on database: DatabaseWriter) throws {
        try database.write { db in
            // Persistent log table (survives app restarts so we can review history)
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS "_collectionDeletionLog" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "tableName" TEXT NOT NULL,
                  "recordID" TEXT NOT NULL,
                  "recordTitle" TEXT NOT NULL DEFAULT '',
                  "timestamp" TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
                )
                """)

            for table in monitoredTables {
                let triggerName = "_log_\(table)_delete"
                // Use the table's title column if available, otherwise empty
                let titleExpr: String
                switch table {
                case "bookItems", "movieItems", "tVShowItems", "restaurantItems", "collections":
                    titleExpr = "OLD.\"title\""
                default:
                    titleExpr = "''"
                }

                try db.execute(sql: """
                    CREATE TRIGGER IF NOT EXISTS "\(triggerName)"
                    AFTER DELETE ON "\(table)"
                    FOR EACH ROW
                    BEGIN
                      INSERT INTO "_collectionDeletionLog" ("tableName", "recordID", "recordTitle")
                      VALUES ('\(table)', OLD."id", \(titleExpr));
                    END
                    """)
            }
        }

        Logger.shared.info("CollectionItemDeletionLogger installed for \(monitoredTables.count) tables", category: .database)
    }

    /// Logs recent deletion entries to the console for diagnostic review.
    /// Query the `_collectionDeletionLog` table directly for full history.
    static func logRecentDeletions(from database: DatabaseReader) {
        do {
            try database.read { db in
                let count = try Int.fetchOne(db, sql: """
                    SELECT COUNT(*) FROM "_collectionDeletionLog"
                    """) ?? 0
                if count > 0 {
                    Logger.shared.warning(
                        "⚠️ Collection item deletion log has \(count) entries. Query _collectionDeletionLog for details.",
                        category: .database
                    )
                }
            }
        } catch {
            Logger.shared.error("Failed to read deletion log: \(error.localizedDescription)", category: .database)
        }
    }
}
