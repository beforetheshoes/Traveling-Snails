//
//  ParticipantListView.swift
//  Traveling Snails
//

import SwiftUI

struct ParticipantListView: View {
    let participants: [ShareParticipant]
    let onManageSharing: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(participants) { participant in
                participantRow(participant)
                if participant.id != participants.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }

            Divider()
                .padding(.vertical, 8)

            Button(action: onManageSharing) {
                Label("Manage Sharing", systemImage: "person.badge.plus")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func participantRow(_ participant: ShareParticipant) -> some View {
        HStack(spacing: 12) {
            // Initials avatar
            Text(participant.initials)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    participant.isOwner
                        ? Color.blue
                        : Color.gray
                )
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(participant.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if participant.isOwner {
                        Text("Owner")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                Text(participant.permissionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if participant.isPending {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(participant.isPending ? 0.6 : 1.0)
    }
}

// MARK: - Compact participant indicator for toolbar

struct ParticipantAvatarsView: View {
    let participants: [ShareParticipant]

    private var displayCount: Int {
        min(participants.count, 3)
    }

    var body: some View {
        HStack(spacing: -6) {
            ForEach(participants.prefix(displayCount)) { participant in
                Text(participant.initials)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(participant.isOwner ? Color.blue : Color.gray)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.clear, lineWidth: 1.5)
                    )
            }

            if participants.count > 3 {
                Text("+\(participants.count - 3)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(.quaternary)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.clear, lineWidth: 1.5)
                    )
            }
        }
    }
}
