//
//  StatusBadgeView.swift
//  Traveling Snails
//

import SwiftUI

struct StatusBadgeView: View {
    let displayName: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(displayName, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    init(status: BookStatus) {
        self.displayName = status.displayName
        self.systemImage = status.systemImage
        self.color = status.color
    }

    init(status: MovieStatus) {
        self.displayName = status.displayName
        self.systemImage = status.systemImage
        self.color = status.color
    }

    init(status: TVShowStatus) {
        self.displayName = status.displayName
        self.systemImage = status.systemImage
        self.color = status.color
    }

    init(status: RestaurantStatus) {
        self.displayName = status.displayName
        self.systemImage = status.systemImage
        self.color = status.color
    }
}
