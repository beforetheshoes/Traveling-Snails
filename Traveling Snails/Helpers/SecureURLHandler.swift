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
    
    static func openURLDirectly(_ urlString: String) {
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        
        UIApplication.shared.open(url)
    }
}
