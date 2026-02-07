//
//  CKSyncEngineSharingService.swift
//  Traveling Snails
//

import CloudKit
import Dependencies
import Foundation
import SQLiteData

final class CKSyncEngineSharingService {
    @Dependency(\.defaultSyncEngine) private var syncEngine

    init() {}

    func getSharingInfo(for trip: Trip) async -> TripSharingInfo {
        TripSharingInfo(isShared: false, shareURL: nil, participants: [])
    }

    func createShare(for trip: Trip) async throws -> SharedRecord {
        try await syncEngine.share(record: trip) { share in
            share[CKShare.SystemFieldKey.title] = trip.name.isEmpty ? "Trip" : trip.name
        }
    }

    func removeShare(for trip: Trip) async throws {
        try await syncEngine.unshare(record: trip)
    }

    func acceptShare(with metadata: CKShare.Metadata) async throws -> Trip {
        try await syncEngine.acceptShare(metadata: metadata)
        guard let database = DatabaseAccess.database else {
            throw SyncError.unknown(NSError(domain: "SQLiteData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"]))
        }
        guard let trip = try await database.read({ db in
            try Trip.order { $0.createdDate.desc() }.fetchOne(db)
        }) else {
            throw SyncError.unknown(NSError(domain: "SQLiteData", code: 2, userInfo: [NSLocalizedDescriptionKey: "No trip found after accepting share"]))
        }
        return trip
    }
}

struct TripSharingInfo: Sendable {
    let isShared: Bool
    let shareURL: URL?
    let participants: [CKShare.Participant]
}
