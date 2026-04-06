//
//  CollectionItemGridView.swift
//  Traveling Snails
//

import SwiftUI

struct CollectionItemGridView: View {
    let bookItems: [BookItem]
    let onItemSelected: (BookItem) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(bookItems) { item in
                BookItemGridCell(item: item)
                    .onTapGesture { onItemSelected(item) }
            }
        }
        .padding(.horizontal)
    }
}

struct BookItemGridCell: View {
    let item: BookItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverArtView(
                imageURL: item.coverImageURL,
                imageData: item.coverImageData,
                width: 120,
                height: 180
            )

            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(item.displaySubtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if item.rating > 0 {
                StaticRatingView(rating: item.rating, starSize: 10)
            }
        }
        .frame(width: 120)
    }
}

// MARK: - Book Item List Row

struct BookItemListRow: View {
    let item: BookItem

    var body: some View {
        HStack(spacing: 12) {
            CoverArtView(
                imageURL: item.coverImageURL,
                imageData: item.coverImageData,
                width: 50,
                height: 75,
                cornerRadius: 4
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if !item.author.isEmpty {
                    Text(item.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    StatusBadgeView(status: item.status)

                    if item.rating > 0 {
                        StaticRatingView(rating: item.rating, starSize: 10)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
