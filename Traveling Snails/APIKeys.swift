//
//  APIKeys.swift
//  Traveling Snails
//
//  Convenience accessors for API keys managed by APIKeyManager.
//  Keys are fetched from CloudKit and cached in Keychain.
//

import Foundation

enum APIKeys {
    static func googleBooks() async -> String {
        await APIKeyManager.shared.key(for: "googleBooks")
    }

    static func tmdb() async -> String {
        await APIKeyManager.shared.key(for: "tmdb")
    }

    static func tvdb() async -> String {
        await APIKeyManager.shared.key(for: "tvdb")
    }
}
