//
//  CoverArtView.swift
//  Traveling Snails
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct CoverArtView: View {
    let imageURL: String
    let imageData: Data?
    var width: CGFloat = 120
    var height: CGFloat = 180
    var cornerRadius: CGFloat = 8
    var placeholderIcon: String = "book.closed"
    var imageContentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let imageData, let image = platformImage(from: imageData) {
                if imageContentMode == .fit {
                    Color.systemGray6
                        .overlay {
                            image
                                .resizable()
                                .interpolation(.high)
                                .antialiased(true)
                                .aspectRatio(contentMode: .fit)
                                .padding(8)
                        }
                } else {
                    image
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                }
            } else if let url = URL(string: imageURL), !imageURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: imageContentMode)
                    case .failure:
                        placeholderView
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(iOS)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #elseif os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #endif
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.systemGray5)
            .overlay {
                Image(systemName: placeholderIcon)
                    .font(.system(size: width * 0.3))
                    .foregroundStyle(.secondary)
            }
    }
}
