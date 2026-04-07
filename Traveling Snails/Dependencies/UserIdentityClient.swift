//
//  UserIdentityClient.swift
//  Traveling Snails
//

import CloudKit
import Dependencies
import Foundation

struct UserIdentityClient {
    /// Returns the current user's CloudKit record name.
    var currentUserRecordName: @Sendable () async throws -> String

    /// Resolves a user record name to a display name from cache.
    /// Returns "Unknown" if the record name hasn't been cached yet.
    var displayName: @Sendable (String) async -> String

    /// Caches display names from CKShare participants so they can be
    /// resolved later without a network call. This should be called
    /// whenever share participants are loaded.
    var cacheParticipantNames: @Sendable ([CKShare.Participant]) async -> Void
}

extension UserIdentityClient: DependencyKey {
    static let liveValue: UserIdentityClient = {
        let cache = DisplayNameCache()
        return UserIdentityClient(
            currentUserRecordName: {
                let recordID = try await CKContainer.default().userRecordID()
                return recordID.recordName
            },
            displayName: { userRecordName in
                await cache.resolve(userRecordName: userRecordName)
            },
            cacheParticipantNames: { participants in
                await cache.cacheParticipants(participants)
            }
        )
    }()

    static let testValue = UserIdentityClient(
        currentUserRecordName: { "test-user-record-name" },
        displayName: { _ in "Test User" },
        cacheParticipantNames: { _ in }
    )
}

extension DependencyValues {
    var userIdentityClient: UserIdentityClient {
        get { self[UserIdentityClient.self] }
        set { self[UserIdentityClient.self] = newValue }
    }
}

// MARK: - Display name cache

/// Caches user record name -> display name mappings.
/// Populated from CKShare.Participant data when shares are loaded,
/// avoiding the need for deprecated user identity discovery APIs.
private actor DisplayNameCache {
    private var cache: [String: String] = [:]

    func resolve(userRecordName: String) -> String {
        cache[userRecordName] ?? "Unknown"
    }

    func cacheParticipants(_ participants: [CKShare.Participant]) {
        for participant in participants {
            guard let recordName = participant.userIdentity.userRecordID?.recordName else {
                continue
            }
            if let nameComponents = participant.userIdentity.nameComponents {
                let name = PersonNameComponentsFormatter.localizedString(
                    from: nameComponents, style: .default
                )
                cache[recordName] = name
            }
        }
    }
}
