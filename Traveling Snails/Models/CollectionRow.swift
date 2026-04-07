//
//  CollectionRow.swift
//  Traveling Snails
//

import CloudKit
import SQLiteData

@Selection
struct CollectionRow: Identifiable {
    var id: Collection.ID { collection.id }
    var collection: Collection
    @Column(as: CKShare?.SystemFieldsRepresentation.self)
    var share: CKShare?

    var isShared: Bool { share != nil }

    var shareMessage: String? {
        guard let share else { return nil }
        if share.owner == share.currentUserParticipant {
            let participantNames = share.participants
                .filter { $0 != share.currentUserParticipant }
                .compactMap { $0.userIdentity.nameComponents?.formatted() }
                .joined(separator: ", ")
            if !participantNames.isEmpty {
                return "Shared with \(participantNames)"
            } else {
                return "Shared"
            }
        } else if let ownerName = share.owner.userIdentity.nameComponents?.formatted() {
            return "Shared by \(ownerName)"
        } else {
            return nil
        }
    }

    var canWrite: Bool {
        guard let share else { return true }
        let participant = share.currentUserParticipant
        return participant?.permission == .readWrite
            || share.owner == participant
    }
}
