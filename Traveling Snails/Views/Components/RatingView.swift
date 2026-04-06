//
//  RatingView.swift
//  Traveling Snails
//

import SwiftUI

struct RatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5
    var starSize: CGFloat = 20
    var interactive: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(index <= rating ? .yellow : .secondary.opacity(0.4))
                    .onTapGesture {
                        guard interactive else { return }
                        if rating == index {
                            rating = 0
                        } else {
                            rating = index
                        }
                    }
            }
        }
    }
}

struct StaticRatingView: View {
    let rating: Int
    var maxRating: Int = 5
    var starSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(index <= rating ? .yellow : .secondary.opacity(0.4))
            }
        }
    }
}
