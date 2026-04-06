//
//  StatusBadgeView.swift
//  Traveling Snails
//

import SwiftUI

struct StatusBadgeView: View {
    let status: BookStatus

    var body: some View {
        Label(status.displayName, systemImage: status.systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }
}
