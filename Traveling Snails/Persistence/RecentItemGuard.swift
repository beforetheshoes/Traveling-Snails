//
//  RecentItemGuard.swift
//  Traveling Snails
//
//  Protects recently-added collection items from being deleted by
//  CKSyncEngine's automatic background processing. Items are cached
//  when added and a delayed check verifies they still exist. If deleted
//  by sync, they are re-inserted.

import Dependencies
import Foundation
import SQLiteData

actor RecentItemGuard {
    static let shared = RecentItemGuard()

    private struct GuardedItem: Sendable {
        enum ItemData: Sendable {
            case book(BookItem)
            case movie(MovieItem)
            case tvShow(TVShowItem)
            case restaurant(RestaurantItem)
        }

        let data: ItemData
        let addedAt: Date
        var checkCount: Int = 0

        var id: UUID {
            switch data {
            case .book(let i): return i.id
            case .movie(let i): return i.id
            case .tvShow(let i): return i.id
            case .restaurant(let i): return i.id
            }
        }

        var title: String {
            switch data {
            case .book(let i): return i.title
            case .movie(let i): return i.title
            case .tvShow(let i): return i.title
            case .restaurant(let i): return i.title
            }
        }

        var recordType: String {
            switch data {
            case .book: return "bookItems"
            case .movie: return "movieItems"
            case .tvShow: return "tVShowItems"
            case .restaurant: return "restaurantItems"
            }
        }
    }

    private var guardedItems: [UUID: GuardedItem] = [:]
    private var watchTask: Task<Void, Never>?

    private let maxChecks = 6

    func guardBook(_ item: BookItem) {
        guardedItems[item.id] = GuardedItem(data: .book(item), addedAt: Date())
        ensureWatching()
    }

    func guardMovie(_ item: MovieItem) {
        guardedItems[item.id] = GuardedItem(data: .movie(item), addedAt: Date())
        ensureWatching()
    }

    func guardTVShow(_ item: TVShowItem) {
        guardedItems[item.id] = GuardedItem(data: .tvShow(item), addedAt: Date())
        ensureWatching()
    }

    func guardRestaurant(_ item: RestaurantItem) {
        guardedItems[item.id] = GuardedItem(data: .restaurant(item), addedAt: Date())
        ensureWatching()
    }

    private func ensureWatching() {
        guard watchTask == nil else { return }
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { break }
                await self.checkGuardedItems()
                if await self.guardedItems.isEmpty {
                    break
                }
            }
            await self?.clearWatchTask()
        }
    }

    private func clearWatchTask() {
        watchTask = nil
    }

    private func checkGuardedItems() {
        @Dependency(\.defaultDatabase) var database

        // Phase 1: Identify which items are missing
        var missingItems: [GuardedItem] = []
        var toRemove: [UUID] = []

        for (id, var item) in guardedItems {
            item.checkCount += 1
            guardedItems[id] = item

            if item.checkCount >= maxChecks {
                toRemove.append(id)
                continue
            }

            let exists: Bool
            do {
                exists = try database.read { db in
                    switch item.data {
                    case .book:
                        return try BookItem.find(id).fetchOne(db) != nil
                    case .movie:
                        return try MovieItem.find(id).fetchOne(db) != nil
                    case .tvShow:
                        return try TVShowItem.find(id).fetchOne(db) != nil
                    case .restaurant:
                        return try RestaurantItem.find(id).fetchOne(db) != nil
                    }
                }
            } catch {
                continue
            }

            if !exists {
                missingItems.append(item)
            }
        }

        for id in toRemove {
            guardedItems.removeValue(forKey: id)
        }

        // Phase 2: Re-insert missing items (separate write transaction)
        for item in missingItems {
            do {
                try database.write { db in
                    switch item.data {
                    case .book(let bookItem):
                        try BookItem.upsert { bookItem }.execute(db)
                    case .movie(let movieItem):
                        try MovieItem.upsert { movieItem }.execute(db)
                    case .tvShow(let tvItem):
                        try TVShowItem.upsert { tvItem }.execute(db)
                    case .restaurant(let restaurantItem):
                        try RestaurantItem.upsert { restaurantItem }.execute(db)
                    }
                }
                Logger.shared.critical(
                    "RecentItemGuard: Re-inserted \(item.recordType) '\(item.title)' deleted by sync",
                    category: .sync
                )
            } catch {
                Logger.shared.error(
                    "RecentItemGuard: Failed to re-insert '\(item.title)': \(error.localizedDescription)",
                    category: .sync
                )
            }
        }

        // Phase 3: Log recoveries (separate from the write transaction)
        if !missingItems.isEmpty {
            for item in missingItems {
                SyncEventLogger.log(
                    on: database,
                    type: "ITEM_GUARD_RECOVERED",
                    recordType: item.recordType,
                    recordID: item.id.uuidString,
                    details: "Re-inserted '\(item.title)' after sync deletion (referenceViolation)"
                )
            }
        }
    }
}
