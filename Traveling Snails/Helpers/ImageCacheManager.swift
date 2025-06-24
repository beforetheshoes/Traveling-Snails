//
//  ImageCacheManager.swift
//  Traveling Snails
//
//

import SwiftUI
import Foundation

@Observable
class ImageCacheManager {
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
        // Use SecureURLHandler for security evaluation instead of duplicating logic
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

// MARK: - Updated CachedAsyncImage using SecureURLHandler

struct CachedAsyncImage<Content: View & Sendable, Placeholder: View & Sendable>: View {
    let urlString: String?
    let organizationId: UUID
    let content: @Sendable (Image) -> Content
    let placeholder: @Sendable () -> Placeholder
    
    @State private var cachedImageURL: URL?
    @State private var isLoading = false
    @State private var showingSecurityAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isConfirmationAlert = false
    @State private var pendingDownloadAction: (() -> Void)?
    @State private var cacheManager = ImageCacheManager.shared
    
    init(
        url urlString: String?,
        organizationId: UUID,
        @ViewBuilder content: @escaping @Sendable (Image) -> Content,
        @ViewBuilder placeholder: @escaping @Sendable () -> Placeholder
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
            if isConfirmationAlert {
                Button("Cancel", role: .cancel) { }
                Button("Download Anyway") {
                    pendingDownloadAction?()
                }
            } else {
                Button("OK") { }
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
        
        // Use SecureURLHandler for consistent security handling
        SecureURLHandler.handleURL(
            urlString,
            action: .cache,
            onSafe: {
                downloadImage()
            },
            onSuspicious: { continueAction in
                alertTitle = SecureURLHandler.alertTitle(for: .suspicious, action: .cache)
                alertMessage = SecureURLHandler.alertMessage(for: .suspicious, action: .cache, url: urlString)
                isConfirmationAlert = true
                pendingDownloadAction = continueAction
                showingSecurityAlert = true
            },
            onBlocked: {
                alertTitle = SecureURLHandler.alertTitle(for: .blocked, action: .cache)
                alertMessage = SecureURLHandler.alertMessage(for: .blocked, action: .cache, url: urlString)
                isConfirmationAlert = false
                showingSecurityAlert = true
            }
        )
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

// MARK: - Sendable Wrapper (unchanged)

struct SendableAnyView: View, Sendable {
    private let viewBuilder: @Sendable () -> AnyView
    
    init<Content: View & Sendable>(_ content: @escaping @Sendable () -> Content) {
        self.viewBuilder = { AnyView(content()) }
    }
    
    var body: some View {
        viewBuilder()
    }
}

// MARK: - Convenience Initializer (unchanged)

extension CachedAsyncImage where Content == SendableAnyView, Placeholder == SendableAnyView {
    init(url urlString: String?, organizationId: UUID) {
        self.init(
            url: urlString,
            organizationId: organizationId,
            content: { image in
                SendableAnyView {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            },
            placeholder: {
                SendableAnyView {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.3))
                        .overlay(
                            Image(systemName: "building.2")
                                .foregroundColor(.secondary)
                        )
                }
            }
        )
    }
}
