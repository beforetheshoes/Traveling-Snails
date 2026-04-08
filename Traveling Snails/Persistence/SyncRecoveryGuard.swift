//
//  SyncRecoveryGuard.swift
//  Traveling Snails
//
//  Takes a snapshot of collection items before sync and re-inserts any
//  that disappear during the sync cycle. This prevents data loss while
//  the root cause of sync-driven deletions is being diagnosed.

import Foundation
import SQLiteData

enum SyncRecoveryGuard {
    struct Snapshot: Sendable {
        let bookItems: [BookItem]
        let movieItems: [MovieItem]
        let tvShowItems: [TVShowItem]
        let restaurantItems: [RestaurantItem]

        var totalCount: Int {
            bookItems.count + movieItems.count + tvShowItems.count + restaurantItems.count
        }

        var countsByTable: [String: Int] {
            [
                "bookItems": bookItems.count,
                "movieItems": movieItems.count,
                "tVShowItems": tvShowItems.count,
                "restaurantItems": restaurantItems.count,
            ]
        }
    }

    static func takeSnapshot(database: DatabaseReader) async throws -> Snapshot {
        try await database.read { db in
            Snapshot(
                bookItems: try BookItem.fetchAll(db),
                movieItems: try MovieItem.fetchAll(db),
                tvShowItems: try TVShowItem.fetchAll(db),
                restaurantItems: try RestaurantItem.fetchAll(db)
            )
        }
    }

    static func currentCounts(database: DatabaseReader) async throws -> [String: Int] {
        try await database.read { db in
            [
                "bookItems": try BookItem.fetchCount(db),
                "movieItems": try MovieItem.fetchCount(db),
                "tVShowItems": try TVShowItem.fetchCount(db),
                "restaurantItems": try RestaurantItem.fetchCount(db),
            ]
        }
    }

    @discardableResult
    static func recoverIfNeeded(
        database: DatabaseWriter,
        snapshot: Snapshot
    ) async throws -> Int {
        let recoveredCount = try await database.write { db -> Int in
            var count = 0
            let currentBookIDs = Set(try BookItem.select(\.id).fetchAll(db))
            let currentMovieIDs = Set(try MovieItem.select(\.id).fetchAll(db))
            let currentTVShowIDs = Set(try TVShowItem.select(\.id).fetchAll(db))
            let currentRestaurantIDs = Set(try RestaurantItem.select(\.id).fetchAll(db))

            for item in snapshot.bookItems where !currentBookIDs.contains(item.id) {
                try BookItem.upsert { item }.execute(db)
                count += 1
                Logger.shared.critical(
                    "SyncRecoveryGuard: Recovered deleted BookItem '\(item.title)' (id: \(item.id))",
                    category: .sync
                )
            }

            for item in snapshot.movieItems where !currentMovieIDs.contains(item.id) {
                try MovieItem.upsert { item }.execute(db)
                count += 1
                Logger.shared.critical(
                    "SyncRecoveryGuard: Recovered deleted MovieItem '\(item.title)' (id: \(item.id))",
                    category: .sync
                )
            }

            for item in snapshot.tvShowItems where !currentTVShowIDs.contains(item.id) {
                try TVShowItem.upsert { item }.execute(db)
                count += 1
                Logger.shared.critical(
                    "SyncRecoveryGuard: Recovered deleted TVShowItem '\(item.title)' (id: \(item.id))",
                    category: .sync
                )
            }

            for item in snapshot.restaurantItems where !currentRestaurantIDs.contains(item.id) {
                try RestaurantItem.upsert { item }.execute(db)
                count += 1
                Logger.shared.critical(
                    "SyncRecoveryGuard: Recovered deleted RestaurantItem '\(item.title)' (id: \(item.id))",
                    category: .sync
                )
            }

            return count
        }

        return recoveredCount
    }
}
