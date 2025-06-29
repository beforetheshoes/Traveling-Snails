//
//  ActivityHeaderView.swift
//  Traveling Snails
//
//

import SwiftUI

/// Reusable header component for activity forms showing large icon and title
struct ActivityHeaderView: View {
    let icon: String
    let color: Color
    let title: String?

    var body: some View {
        VStack(spacing: 12) {
            // Activity Icon with colored background
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)
                .padding(8)
                .background(color.opacity(0.1))
                .clipShape(Circle())

            // Optional title (for activity name or type)
            if let title = title {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ActivityHeaderView(
            icon: "bed.double.fill",
            color: .blue,
            title: "Test Lodging"
        )

        ActivityHeaderView(
            icon: "figure.walk",
            color: .green,
            title: "Activity"
        )

        ActivityHeaderView(
            icon: "airplane",
            color: .orange,
            title: nil
        )
    }
    .padding()
}
