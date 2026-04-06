//
//  MediaCacheService.swift
//  Traveling Snails
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

actor MediaCacheService {
    static let shared = MediaCacheService()

    private struct CacheEntry<T> {
        let value: T
        let expiration: Date
    }

    private var searchCache: [String: CacheEntry<[BookSearchResult]>] = [:]
    private var detailCache: [String: CacheEntry<BookSearchResult>] = [:]
    private var imageCache: [String: CacheEntry<Data>] = [:]

    private let searchCacheDuration: TimeInterval = 3600       // 1 hour
    private let detailCacheDuration: TimeInterval = 86400      // 24 hours
    private let imageCacheDuration: TimeInterval = 86400       // 24 hours
    private let maxImageSize = 500_000                         // 500KB

    // MARK: - Search Cache

    func cachedSearchResults(for query: String) -> [BookSearchResult]? {
        guard let entry = searchCache[query.lowercased()],
              entry.expiration > Date() else {
            return nil
        }
        return entry.value
    }

    func cacheSearchResults(_ results: [BookSearchResult], for query: String) {
        searchCache[query.lowercased()] = CacheEntry(
            value: results,
            expiration: Date().addingTimeInterval(searchCacheDuration)
        )
    }

    // MARK: - Detail Cache

    func cachedDetail(for id: String) -> BookSearchResult? {
        guard let entry = detailCache[id],
              entry.expiration > Date() else {
            return nil
        }
        return entry.value
    }

    func cacheDetail(_ result: BookSearchResult, for id: String) {
        detailCache[id] = CacheEntry(
            value: result,
            expiration: Date().addingTimeInterval(detailCacheDuration)
        )
    }

    // MARK: - Image Download

    func downloadCoverImage(from urlString: String) async -> Data? {
        let cacheKey = urlString

        if let entry = imageCache[cacheKey], entry.expiration > Date() {
            return entry.value
        }

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let finalData: Data
            if data.count > maxImageSize {
                #if os(iOS)
                if let image = UIImage(data: data),
                   let compressed = image.jpegData(compressionQuality: 0.7),
                   compressed.count <= maxImageSize {
                    finalData = compressed
                } else {
                    finalData = data
                }
                #elseif os(macOS)
                if let image = NSImage(data: data),
                   let tiffData = image.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let compressed = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]),
                   compressed.count <= maxImageSize {
                    finalData = compressed
                } else {
                    finalData = data
                }
                #endif
            } else {
                finalData = data
            }

            imageCache[cacheKey] = CacheEntry(
                value: finalData,
                expiration: Date().addingTimeInterval(imageCacheDuration)
            )
            return finalData
        } catch {
            return nil
        }
    }

    // MARK: - Cleanup

    func clearExpired() {
        let now = Date()
        searchCache = searchCache.filter { $0.value.expiration > now }
        detailCache = detailCache.filter { $0.value.expiration > now }
        imageCache = imageCache.filter { $0.value.expiration > now }
    }

    func clearAll() {
        searchCache.removeAll()
        detailCache.removeAll()
        imageCache.removeAll()
    }
}
