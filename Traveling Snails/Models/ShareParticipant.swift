//
//  ShareParticipant.swift
//  Traveling Snails
//

import CloudKit
import Foundation

struct ShareParticipant: Identifiable, Equatable {
    let id: String
    let displayName: String
    let role: CKShare.ParticipantRole
    let permission: CKShare.ParticipantPermission
    let acceptanceStatus: CKShare.ParticipantAcceptanceStatus

    var isOwner: Bool { role == .owner }
    var isPending: Bool { acceptanceStatus == .pending }
    var isReadOnly: Bool { permission == .readOnly }

    var permissionLabel: String {
        switch permission {
        case .unknown: return "Unknown"
        case .none: return "No Access"
        case .readOnly: return "View Only"
        case .readWrite: return "Can Edit"
        @unknown default: return "Unknown"
        }
    }

    var roleLabel: String {
        isOwner ? "Owner" : "Member"
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    static func from(ckParticipant: CKShare.Participant) -> ShareParticipant {
        let name = ckParticipant.userIdentity.nameComponents
            .flatMap { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            ?? "Unknown"

        return ShareParticipant(
            id: ckParticipant.userIdentity.userRecordID?.recordName ?? UUID().uuidString,
            displayName: name,
            role: ckParticipant.role,
            permission: ckParticipant.permission,
            acceptanceStatus: ckParticipant.acceptanceStatus
        )
    }

    static func from(share: CKShare) -> [ShareParticipant] {
        share.participants
            .map { ShareParticipant.from(ckParticipant: $0) }
            .sorted { lhs, rhs in
                if lhs.isOwner != rhs.isOwner { return lhs.isOwner }
                if lhs.isPending != rhs.isPending { return !lhs.isPending }
                return lhs.displayName < rhs.displayName
            }
    }
}
