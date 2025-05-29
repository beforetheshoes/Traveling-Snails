//
//  ImageCacheManager.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import Foundation

class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()
    
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    
    private init() {
        // Create cache directory in Documents
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cacheImage(from urlString: String, for organizationId: UUID) async -> String? {
        // First check URL security
        let securityLevel = SecureURLHandler.evaluateURL(urlString)
        guard securityLevel != .blocked else {
            print("Blocked URL, not caching: \(urlString)")
            return nil
        }
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let mimeType = httpResponse.mimeType,
                  mimeType.hasPrefix("image/") else {
                print("Invalid image response")
                return nil
            }
            
            // Validate image data
            guard UIImage(data: data) != nil else {
                print("Invalid image data")
                return nil
            }
            
            // Create filename based on organization ID and URL hash
            let urlHash = urlString.hash
            let filename = "\(organizationId.uuidString)_\(urlHash).jpg"
            let fileURL = cacheDirectory.appendingPathComponent(filename)
            
            // Save to cache
            try data.write(to: fileURL)
            
            return fileURL.lastPathComponent
        } catch {
            print("Failed to cache image: \(error)")
            return nil
        }
    }
    
    func getCachedImageURL(filename: String) -> URL? {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    func deleteCachedImage(filename: String) {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let urlString: String?
    let organizationId: UUID
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var cachedImageURL: URL?
    @State private var isLoading = false
    @State private var showingSecurityAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @StateObject private var cacheManager = ImageCacheManager.shared
    
    init(
        url urlString: String?,
        organizationId: UUID,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlString = urlString
        self.organizationId = organizationId
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedURL = cachedImageURL {
                AsyncImage(url: cachedURL) { image in
                    content(image)
                } placeholder: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    } else {
                        placeholder()
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(width: 60, height: 60)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _, _ in
            cachedImageURL = nil
            loadImage()
        }
        .alert(alertTitle, isPresented: $showingSecurityAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Download Anyway") {
                downloadImage()
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadImage() {
        guard let urlString = urlString, !urlString.isEmpty else { return }
        
        // Check if already cached (based on URL hash)
        let urlHash = urlString.hash
        let filename = "\(organizationId.uuidString)_\(urlHash).jpg"
        
        if let existingURL = cacheManager.getCachedImageURL(filename: filename) {
            cachedImageURL = existingURL
            return
        }
        
        // Check URL security before downloading
        let securityLevel = SecureURLHandler.evaluateURL(urlString)
        
        switch securityLevel {
        case .safe:
            downloadImage()
            
        case .suspicious:
            alertTitle = "Suspicious Image URL"
            alertMessage = "This image URL appears suspicious:\n\n\(urlString)\n\nDo you want to download it anyway? The image will be cached locally."
            showingSecurityAlert = true
            
        case .blocked:
            alertTitle = "Blocked Image URL"
            alertMessage = "This image URL is blocked for security reasons and cannot be downloaded."
            showingSecurityAlert = true
        }
    }
    
    private func downloadImage() {
        guard let urlString = urlString else { return }
        
        isLoading = true
        
        Task {
            if let cachedFilename = await cacheManager.cacheImage(from: urlString, for: organizationId) {
                await MainActor.run {
                    cachedImageURL = cacheManager.getCachedImageURL(filename: cachedFilename)
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// Convenience initializer
extension CachedAsyncImage where Content == AnyView, Placeholder == AnyView {
    init(url urlString: String?, organizationId: UUID) {
        self.init(
            url: urlString,
            organizationId: organizationId,
            content: { image in
                AnyView(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
            },
            placeholder: {
                AnyView(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                        )
                )
            }
        )
    }
}
