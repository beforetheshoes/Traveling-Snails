//
//  SecureURLHandler.swift
//  Traveling Snails
//
//  Created by Ryan Williams on 5/26/25.
//

import SwiftUI
import UIKit

struct SecureURLHandler {
    
    enum URLSecurityLevel {
        case safe
        case suspicious
        case blocked
    }
    
    enum URLAction {
        case open
        case download
        case cache
    }
    
    // MARK: - Core Security Evaluation
    
    static func evaluateURL(_ urlString: String) -> URLSecurityLevel {
        guard let url = URL(string: urlString) else { return .blocked }
        
        // Check scheme
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto", "tel"].contains(scheme) else {
            return .blocked
        }
        
        // For web URLs, check for suspicious patterns
        if scheme == "http" || scheme == "https" {
            guard let host = url.host?.lowercased() else { return .blocked }
            
            // Suspicious indicators
            let suspiciousPatterns = [
                "bit.ly", "tinyurl.com", "t.co", // URL shorteners
                "000webhostapp.com", "herokuapp.com", // Free hosting
                "ngrok.io", "localhost" // Development/tunneling
            ]
            
            if suspiciousPatterns.contains(where: { host.contains($0) }) {
                return .suspicious
            }
            
            // Check for suspicious characters in domain
            if host.contains("xn--") || // Punycode (internationalized domains)
               host.count > 50 ||       // Extremely long domains
               host.components(separatedBy: ".").count > 5 { // Too many subdomains
                return .suspicious
            }
        }
        
        return .safe
    }
    
    // MARK: - URL Opening
    
    static func openURLDirectly(_ urlString: String) {
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        
        UIApplication.shared.open(url)
    }
    
    // MARK: - Secure URL Handling with User Confirmation
    
    /// Handle URL with appropriate security checks and user prompts
    static func handleURL(
        _ urlString: String,
        action: URLAction = .open,
        onSafe: @escaping () -> Void,
        onSuspicious: @escaping (@escaping () -> Void) -> Void,
        onBlocked: @escaping () -> Void
    ) {
        let securityLevel = evaluateURL(urlString)
        
        switch securityLevel {
        case .safe:
            onSafe()
            
        case .suspicious:
            onSuspicious(onSafe)
            
        case .blocked:
            onBlocked()
        }
    }
    
    // MARK: - Alert Message Helpers
    
    static func alertTitle(for level: URLSecurityLevel, action: URLAction) -> String {
        switch (level, action) {
        case (.blocked, .open):
            return "Invalid URL"
        case (.blocked, .download), (.blocked, .cache):
            return "Blocked Image URL"
        case (.suspicious, .open):
            return "External Link"
        case (.suspicious, .download), (.suspicious, .cache):
            return "Suspicious Image URL"
        case (.safe, _):
            return ""
        }
    }
    
    static func alertMessage(for level: URLSecurityLevel, action: URLAction, url: String) -> String {
        switch (level, action) {
        case (.blocked, .open):
            return "This URL cannot be opened for security reasons."
        case (.blocked, .download), (.blocked, .cache):
            return "This image URL is blocked for security reasons and cannot be downloaded."
        case (.suspicious, .open):
            return "This link will open in an external app or browser:\n\n\(url)\n\nDo you want to continue?"
        case (.suspicious, .download), (.suspicious, .cache):
            return "This image URL appears suspicious:\n\n\(url)\n\nDo you want to download it anyway? The image will be cached locally."
        case (.safe, _):
            return ""
        }
    }
    
    // MARK: - Contact Type Specific Handling
    
    enum ContactType {
        case phone, email, website
        
        var isTrusted: Bool {
            switch self {
            case .phone, .email:
                return true
            case .website:
                return false
            }
        }
    }
    
    /// Handle contact URLs with type-specific security rules
    static func handleContactURL(
        _ urlString: String,
        type: ContactType,
        onSafe: @escaping () -> Void,
        onSuspicious: @escaping (@escaping () -> Void) -> Void,
        onBlocked: @escaping () -> Void
    ) {
        // Phone and email are generally trusted, only check websites
        if type.isTrusted {
            onSafe()
        } else {
            handleURL(
                urlString,
                action: .open,
                onSafe: onSafe,
                onSuspicious: onSuspicious,
                onBlocked: onBlocked
            )
        }
    }
}

// MARK: - SwiftUI Integration

extension SecureURLHandler {
    /// Create a secure URL handling closure for SwiftUI views
    static func createURLHandler(
        for urlString: String,
        action: URLAction = .open,
        showAlert: @escaping (String, String, Bool, @escaping () -> Void) -> Void
    ) -> () -> Void {
        return {
            handleURL(
                urlString,
                action: action,
                onSafe: {
                    if action == .open {
                        openURLDirectly(urlString)
                    }
                },
                onSuspicious: { continueAction in
                    let title = alertTitle(for: .suspicious, action: action)
                    let message = alertMessage(for: .suspicious, action: action, url: urlString)
                    showAlert(title, message, true, continueAction)
                },
                onBlocked: {
                    let title = alertTitle(for: .blocked, action: action)
                    let message = alertMessage(for: .blocked, action: action, url: urlString)
                    showAlert(title, message, false) { }
                }
            )
        }
    }
}
