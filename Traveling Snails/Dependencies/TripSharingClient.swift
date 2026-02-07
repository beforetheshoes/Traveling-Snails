import Dependencies
import Foundation
@preconcurrency import CloudKit

struct TripSharingParticipant: Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let permissionDescription: String
    let isOwner: Bool
}

struct TripSharingSnapshot: Equatable, Sendable {
    var isShared: Bool
    var shareURL: URL?
    var participants: [TripSharingParticipant]
}

struct TripSharingClient: Sendable {
    var sharingInfo: @Sendable (Trip) async -> TripSharingSnapshot
    var createShare: @Sendable (Trip) async throws -> TripSharingSnapshot
    var removeShare: @Sendable (Trip) async throws -> Void
    var acceptShare: @Sendable (CKShare.Metadata) async throws -> Trip
}

extension TripSharingClient: DependencyKey {
    static let liveValue = Self(
        sharingInfo: { trip in
            let service = CKSyncEngineSharingService()
            let info = await service.getSharingInfo(for: trip)
            return Self.snapshot(from: info)
        },
        createShare: { trip in
            let service = CKSyncEngineSharingService()
            let sharedRecord = try await service.createShare(for: trip)
            return Self.snapshot(from: sharedRecord.share)
        },
        removeShare: { trip in
            let service = CKSyncEngineSharingService()
            try await service.removeShare(for: trip)
        },
        acceptShare: { metadata in
            let service = CKSyncEngineSharingService()
            return try await service.acceptShare(with: metadata)
        }
    )

    static let testValue = Self(
        sharingInfo: { _ in
            TripSharingSnapshot(isShared: false, shareURL: nil, participants: [])
        },
        createShare: { _ in
            TripSharingSnapshot(isShared: true, shareURL: nil, participants: [])
        },
        removeShare: { _ in },
        acceptShare: { _ in Trip(name: "Accepted Trip") }
    )
}

extension DependencyValues {
    var tripSharingClient: TripSharingClient {
        get { self[TripSharingClient.self] }
        set { self[TripSharingClient.self] = newValue }
    }
}

private extension TripSharingClient {
    static func snapshot(from info: TripSharingInfo) -> TripSharingSnapshot {
        TripSharingSnapshot(
            isShared: info.isShared,
            shareURL: info.shareURL,
            participants: info.participants.enumerated().map { index, participant in
                mapParticipant(participant, fallbackOwner: index == 0)
            }
        )
    }

    static func snapshot(from share: CKShare) -> TripSharingSnapshot {
        TripSharingSnapshot(
            isShared: true,
            shareURL: share.url,
            participants: share.participants.enumerated().map { index, participant in
                mapParticipant(participant, fallbackOwner: index == 0)
            }
        )
    }

    static func mapParticipant(
        _ participant: CKShare.Participant,
        fallbackOwner: Bool
    ) -> TripSharingParticipant {
        let formatter = PersonNameComponentsFormatter()
        let displayName: String = {
            guard let components = participant.userIdentity.nameComponents else {
                return fallbackOwner ? "You" : "Unknown User"
            }
            let formatted = formatter.string(from: components)
            if formatted.isEmpty {
                return fallbackOwner ? "You" : "Unknown User"
            }
            return formatted
        }()

        let isOwner = participant.role == .owner || fallbackOwner
        let permissionDescription: String = {
            switch participant.permission {
            case .readOnly:
                return "Can view"
            case .readWrite:
                return "Can edit"
            default:
                return "Full access"
            }
        }()

        return TripSharingParticipant(
            id: participant.userIdentity.lookupInfo?.emailAddress
                ?? participant.userIdentity.lookupInfo?.phoneNumber
                ?? participant.userIdentity.lookupInfo?.userRecordID?.recordName
                ?? UUID().uuidString,
            displayName: displayName,
            permissionDescription: permissionDescription,
            isOwner: isOwner
        )
    }
}
